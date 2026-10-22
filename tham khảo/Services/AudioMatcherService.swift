import Foundation
import Accelerate

public final class AudioMatcherService: @unchecked Sendable {
    
    public static let shared = AudioMatcherService()
    public let minMatchScoreThreshold: Double = 3.0
    public let minCorrelationThreshold: Double = 0.05
    
    private let decoder: AudioDecoderServiceProtocol
    private let beatDetector: BeatDetectorServiceProtocol

    public init(
        decoder: AudioDecoderServiceProtocol = AudioDecoderService.shared,
        beatDetector: BeatDetectorServiceProtocol = BeatDetectorService.shared
    ) {
        self.decoder = decoder
        self.beatDetector = beatDetector
    }

    func normalizedCorrelation(
        videoFlux: [[Float]],
        audioFlux: [[Float]],
        offsetSeconds: Double
    ) -> Double {
        let bands = min(videoFlux.count, audioFlux.count)
        guard bands > 0,
              let videoFrames = videoFlux.first?.count,
              let audioFrames = audioFlux.first?.count,
              videoFrames > 0, audioFrames > 0 else { return 0 }

        let frameDuration = Double(MelSpectrogramService.shared.hopLength) / Double(MelSpectrogramService.shared.sampleRate)
        let lag = Int(round(offsetSeconds / frameDuration))
        let audioLower = max(0, -lag)
        let audioUpper = min(audioFrames, videoFrames - lag)
        let overlap = audioUpper - audioLower
        let maximumOverlap = min(videoFrames, audioFrames)
        guard overlap > 0, overlap >= max(16, Int(Double(maximumOverlap) * 0.30)) else { return 0 }

        var total = 0.0
        var usedBands = 0
        for band in 0..<bands {
            let video = videoFlux[band]
            let audio = audioFlux[band]
            guard video.count >= videoFrames, audio.count >= audioFrames else { continue }
            var dot = 0.0
            var videoEnergy = 0.0
            var audioEnergy = 0.0
            for audioIndex in audioLower..<audioUpper {
                let videoValue = Double(video[audioIndex + lag])
                let audioValue = Double(audio[audioIndex])
                dot += videoValue * audioValue
                videoEnergy += videoValue * videoValue
                audioEnergy += audioValue * audioValue
            }
            let denominator = sqrt(videoEnergy * audioEnergy)
            if denominator > 1e-12 {
                total += dot / denominator
                usedBands += 1
            }
        }
        return usedBands > 0 ? total / Double(usedBands) : 0
    }

    /// Spectral flux can choose an adjacent beat in strongly repetitive dance music.
    /// Downbeat phase is only allowed to move the result by whole beats when the
    /// neighboring correlation peak is almost as strong as the original peak.
    func beatCycleCorrection(
        offsetSeconds: Double,
        videoFlux: [[Float]],
        audioFlux: [[Float]],
        videoBeat: BeatDetectorService.BeatAnalysisResult?,
        audioBeat: BeatDetectorService.BeatAnalysisResult?
    ) -> (offset: Double, correlation: Double)? {
        guard let videoBeat = videoBeat, let audioBeat = audioBeat else { return nil }
        let bpmDifference = abs(videoBeat.bpm - audioBeat.bpm) / max(1.0, max(videoBeat.bpm, audioBeat.bpm))
        guard bpmDifference <= 0.04 else { return nil }

        let beatInterval = (videoBeat.beatInterval + audioBeat.beatInterval) / 2.0
        let barDuration = beatInterval * 4.0
        guard beatInterval > 0.20, beatInterval < 1.20 else { return nil }

        var phaseError = (videoBeat.firstDownbeatTime - audioBeat.firstDownbeatTime) - offsetSeconds
        phaseError -= round(phaseError / barDuration) * barDuration
        let beatShift = Int(round(phaseError / beatInterval))
        guard abs(beatShift) == 1 else { return nil }
        let snappedShift = Double(beatShift) * beatInterval
        guard abs(phaseError - snappedShift) <= max(0.08, beatInterval * 0.20) else { return nil }

        let candidateOffset = offsetSeconds + snappedShift
        let originalCorrelation = normalizedCorrelation(videoFlux: videoFlux, audioFlux: audioFlux, offsetSeconds: offsetSeconds)
        let candidateCorrelation = normalizedCorrelation(videoFlux: videoFlux, audioFlux: audioFlux, offsetSeconds: candidateOffset)
        guard originalCorrelation > 0.02,
              candidateCorrelation >= originalCorrelation * 0.90 else { return nil }
        return (candidateOffset, candidateCorrelation)
    }

    /// Refines a coarse Mel-spectrogram match with a 5 ms transient envelope.
    /// The narrow search window preserves the musical section selected by the
    /// spectral matcher while locating the actual waveform onset more precisely.
    func refineOffsetWithOnsetEnvelope(
        videoSamples: [Float],
        audioSamples: [Float],
        coarseOffset: Double,
        searchRadius: Double = 0.12
    ) -> Double {
        let sampleRate = AudioDecoderService.targetSampleRate
        let hop = max(1, Int(round(sampleRate * 0.005)))
        let window = max(hop, Int(round(sampleRate * 0.020)))
        let videoEnvelope = onsetEnvelope(samples: videoSamples, hop: hop, window: window)
        let audioEnvelope = onsetEnvelope(samples: audioSamples, hop: hop, window: window)
        guard videoEnvelope.count >= 16, audioEnvelope.count >= 16 else { return coarseOffset }

        let frameDuration = Double(hop) / sampleRate
        let coarseLag = Int(round(coarseOffset / frameDuration))
        let radius = max(1, Int(ceil(searchRadius / frameDuration)))
        var bestLag = coarseLag
        var bestCorrelation = -Double.infinity
        var correlations: [Int: Double] = [:]
        for lag in (coarseLag - radius)...(coarseLag + radius) {
            let correlation = envelopeCorrelation(video: videoEnvelope, audio: audioEnvelope, lag: lag)
            correlations[lag] = correlation
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }
        guard bestCorrelation.isFinite, bestCorrelation > 0.02 else { return coarseOffset }

        var refinedLag = Double(bestLag)
        if let left = correlations[bestLag - 1],
           let right = correlations[bestLag + 1] {
            let denominator = 2.0 * (left - 2.0 * bestCorrelation + right)
            if abs(denominator) > 1e-9 {
                let delta = (left - right) / denominator
                if abs(delta) <= 1.0 { refinedLag += delta }
            }
        }
        return refinedLag * frameDuration
    }

    private func onsetEnvelope(samples: [Float], hop: Int, window: Int) -> [Double] {
        guard samples.count >= window, hop > 0 else { return [] }
        var energies: [Double] = []
        energies.reserveCapacity((samples.count - window) / hop + 1)
        var start = 0
        while start + window <= samples.count {
            var sum = 0.0
            for index in start..<(start + window) {
                let value = Double(samples[index])
                sum += value * value
            }
            energies.append(sqrt(sum / Double(window)))
            start += hop
        }

        guard energies.count > 1 else { return [] }
        var envelope = [Double](repeating: 0, count: energies.count)
        for index in 1..<energies.count {
            envelope[index] = max(0, energies[index] - energies[index - 1])
        }
        return envelope
    }

    private func envelopeCorrelation(video: [Double], audio: [Double], lag: Int) -> Double {
        let audioLower = max(0, -lag)
        let audioUpper = min(audio.count, video.count - lag)
        let overlap = audioUpper - audioLower
        let maximumOverlap = min(video.count, audio.count)
        guard overlap >= max(16, Int(Double(maximumOverlap) * 0.30)) else { return 0 }

        var dot = 0.0
        var videoEnergy = 0.0
        var audioEnergy = 0.0
        for audioIndex in audioLower..<audioUpper {
            let videoValue = video[audioIndex + lag]
            let audioValue = audio[audioIndex]
            dot += videoValue * audioValue
            videoEnergy += videoValue * videoValue
            audioEnergy += audioValue * audioValue
        }
        let denominator = sqrt(videoEnergy * audioEnergy)
        return denominator > 1e-12 ? dot / denominator : 0
    }
    
    // MARK: - Single Video vs Single Audio Matcher
    /// Tính toán độ tương quan chéo chuẩn hóa (Normalized Cross-Correlation) giữa Video và Audio
    public func matchVideoWithAudio(
        videoFlux: [[Float]],
        audioFlux: [[Float]],
        videoName: String,
        audioName: String,
        audioURL: URL
    ) -> AudioMatchResult {
        guard !videoFlux.isEmpty && !audioFlux.isEmpty else {
            return AudioMatchResult(
                videoName: videoName,
                audioName: audioName,
                audioURL: audioURL,
                offsetSeconds: 0.0,
                score: 0.0,
                correlation: 0.0,
                isMatch: false
            )
        }
        
        let nMels = min(videoFlux.count, audioFlux.count)
        let nVidFrames = videoFlux[0].count
        let nAudFrames = audioFlux[0].count
        
        let corrLen = nVidFrames + nAudFrames - 1
        var totalNormCorr = [Float](repeating: 0, count: corrLen)
        
        // 1. Tính toán tương quan chuẩn hóa cho từng dải trong 40 dải Mel và cộng dồn
        for m in 0..<nMels {
            let v = videoFlux[m]
            let a = audioFlux[m] // Giữ nguyên thứ tự thời gian chuẩn của Audio
            
            var vEnergy: Float = 0
            vDSP_svesq(v, 1, &vEnergy, vDSP_Length(nVidFrames))
            let vNorm = sqrt(vEnergy) + 1e-6
            
            var aEnergy: Float = 0
            vDSP_svesq(a, 1, &aEnergy, vDSP_Length(nAudFrames))
            let aNorm = sqrt(aEnergy) + 1e-6
            
            var paddedV = [Float](repeating: 0, count: nVidFrames + 2 * nAudFrames)
            for i in 0..<nVidFrames {
                paddedV[nAudFrames - 1 + i] = v[i]
            }
            
            var bandCorr = [Float](repeating: 0, count: corrLen)
            paddedV.withUnsafeBufferPointer { pV in
                a.withUnsafeBufferPointer { pA in
                    bandCorr.withUnsafeMutableBufferPointer { pC in
                        vDSP_conv(
                            pV.baseAddress!,
                            1,
                            pA.baseAddress!,
                            1,
                            pC.baseAddress!,
                            1,
                            vDSP_Length(corrLen),
                            vDSP_Length(nAudFrames)
                        )
                    }
                }
            }
            
            // Chuẩn hóa Cosine Similarity: bandCorr / (vNorm * aNorm) / nMels
            let normFactor = 1.0 / (vNorm * aNorm)
            var scale = normFactor / Float(nMels)
            vDSP_vsma(bandCorr, 1, &scale, totalNormCorr, 1, &totalNormCorr, 1, vDSP_Length(corrLen))
        }
        
        // 2. Tìm đỉnh tương quan cực đại (Global Maximum Peak)
        var maxVal: Float = -Float.infinity
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(totalNormCorr, 1, &maxVal, &maxIndex, vDSP_Length(corrLen))
        
        let peakIndex = Int(maxIndex)
        
        // 3. Tinh chỉnh vị trí đỉnh bằng nội suy Parabolic
        var refinedIndex = Double(peakIndex)
        if peakIndex > 0 && peakIndex < corrLen - 1 {
            let alpha = Double(totalNormCorr[peakIndex - 1])
            let beta = Double(totalNormCorr[peakIndex])
            let gamma = Double(totalNormCorr[peakIndex + 1])
            
            let denom = 2.0 * (alpha - 2.0 * beta + gamma)
            if abs(denom) > 1e-9 {
                let delta = (alpha - gamma) / denom
                refinedIndex = Double(peakIndex) + delta
            }
        }
        
        // 4. Tính điểm tin cậy SNR so với nền nhiễu (loại trừ vùng lân cận +/- 50 frames của đỉnh)
        var backgroundSamples: [Float] = []
        backgroundSamples.reserveCapacity(corrLen)
        for i in 0..<corrLen {
            if abs(i - peakIndex) > 50 {
                backgroundSamples.append(abs(totalNormCorr[i]))
            }
        }
        
        let sortedBg = backgroundSamples.sorted()
        let bgMedian = sortedBg.isEmpty ? 0.001 : sortedBg[sortedBg.count / 2]
        let score = Double(maxVal) / (Double(bgMedian) + 1e-6)
        
        // 5. Tính toán Offset thời gian (giây) chuẩn xác:
        // offset = (refined_idx - (nAudFrames - 1)) * hop / sample_rate
        let hopLength = Double(MelSpectrogramService.shared.hopLength) // 512
        let sampleRate = Double(MelSpectrogramService.shared.sampleRate) // 22050
        let offsetSeconds = (refinedIndex - Double(nAudFrames - 1)) * hopLength / sampleRate
        
        let isMatch = (Double(maxVal) >= minCorrelationThreshold) && (score >= minMatchScoreThreshold)
        
        return AudioMatchResult(
            videoName: videoName,
            audioName: audioName,
            audioURL: audioURL,
            offsetSeconds: offsetSeconds,
            score: score,
            correlation: Double(maxVal),
            isMatch: isMatch
        )
    }
    
    // MARK: - Batch Matcher (Tìm bài nhạc khớp nhất cho 1 video)
    public func findBestMatchingAudio(
        videoItem: MediaItem,
        candidateAudioItems: [MediaItem],
        logHandler: ((String) -> Void)? = nil
    ) -> AudioMatchResult? {
        guard videoItem.mediaType == .video else { return nil }
        guard !candidateAudioItems.isEmpty else {
            logHandler?("⚠️ Không có tệp âm thanh/nhạc nào để đối chiếu.")
            return nil
        }
        
        let videoURL = (videoItem.status == .synced && FileManager.default.fileExists(atPath: videoItem.localURL.path)) ? videoItem.localURL : videoItem.sourceURL
        
        logHandler?("🎵 Bắt đầu trích xuất âm thanh từ Video: \(videoItem.name)...")
        let videoSampleTracks = decoder.decodeAudioTracksToMonoFloat32(url: videoURL)
        guard !videoSampleTracks.isEmpty else {
            logHandler?("⚠️ Không thể giải mã âm thanh từ video: \(videoItem.name) (Có thể video không có tiếng).")
            return nil
        }

        logHandler?("📊 Tính toán Mel Spectral Flux cho \(videoSampleTracks.count) track âm thanh trong video \(videoItem.name)...")
        let videoAnalyses = videoSampleTracks.enumerated().compactMap { trackIndex, samples -> (index: Int, samples: [Float], flux: [[Float]], beat: BeatDetectorService.BeatAnalysisResult?)? in
            let flux = MelSpectrogramService.shared.computeNormalizedSpectralFlux(samples: samples)
            guard !flux.isEmpty else { return nil }
            let beat = self.beatDetector.analyzeSamples(samples, sampleRate: AudioDecoderService.targetSampleRate)
            return (trackIndex, samples, flux, beat)
        }
        guard !videoAnalyses.isEmpty else {
            logHandler?("⚠️ Video quá ngắn để tạo đặc trưng âm thanh.")
            return nil
        }
        
        var allResults: [AudioMatchResult] = []
        var matchedResults: [AudioMatchResult] = []
        
        for audioItem in candidateAudioItems {
            let audioURL = (audioItem.status == .synced && FileManager.default.fileExists(atPath: audioItem.localURL.path)) ? audioItem.localURL : audioItem.sourceURL
            
            guard let audSamples = decoder.decodeToMonoFloat32(url: audioURL) else {
                logHandler?("⚠️ Không thể giải mã âm thanh: \(audioItem.name)")
                continue
            }
            
            let audFlux = MelSpectrogramService.shared.computeNormalizedSpectralFlux(samples: audSamples)
            guard !audFlux.isEmpty else { continue }
            
            let audioBeat = beatDetector.analyzeSamples(audSamples, sampleRate: AudioDecoderService.targetSampleRate)
            var trackResults: [(trackIndex: Int, result: AudioMatchResult)] = []
            for videoAnalysis in videoAnalyses {
                let raw = matchVideoWithAudio(
                    videoFlux: videoAnalysis.flux,
                    audioFlux: audFlux,
                    videoName: videoItem.name,
                    audioName: audioItem.name,
                    audioURL: audioURL
                )
                var correctedOffset = raw.offsetSeconds
                if raw.isMatch, let correction = beatCycleCorrection(
                    offsetSeconds: raw.offsetSeconds,
                    videoFlux: videoAnalysis.flux,
                    audioFlux: audFlux,
                    videoBeat: videoAnalysis.beat,
                    audioBeat: audioBeat
                ) {
                    correctedOffset = correction.offset
                    logHandler?("Đã loại sai lệch chu kỳ nhịp ở track \(videoAnalysis.index + 1): \(raw.formattedOffset) → \(String(format: "%+.2fs", correctedOffset))")
                }
                let refinedOffset = raw.isMatch ? refineOffsetWithOnsetEnvelope(
                    videoSamples: videoAnalysis.samples,
                    audioSamples: audSamples,
                    coarseOffset: correctedOffset
                ) : correctedOffset
                let result = AudioMatchResult(
                    videoName: raw.videoName,
                    audioName: raw.audioName,
                    audioURL: raw.audioURL,
                    offsetSeconds: refinedOffset,
                    score: raw.score,
                    correlation: raw.correlation,
                    isMatch: raw.isMatch
                )
                trackResults.append((videoAnalysis.index, result))
            }
            guard let selected = trackResults.max(by: { $0.result.correlation < $1.result.correlation }) else { continue }
            let matchResult = selected.result
            if videoAnalyses.count > 1 {
                logHandler?("Đã chọn audio track \(selected.trackIndex + 1)/\(videoAnalyses.count) của video (r=\(String(format: "%.1f%%", matchResult.correlation * 100))).")
            }
            
            allResults.append(matchResult)
            if matchResult.isMatch {
                matchedResults.append(matchResult)
            }
            
            let statusIcon = matchResult.isMatch ? "🎯 KHỚP" : "❌ Không khớp"
            logHandler?("\(statusIcon) [\(audioItem.name)]: \(matchResult.formattedScore) | Offset: \(matchResult.formattedOffset)")
        }
        
        // 1. Ưu tiên hàng đầu: Chọn bài trong danh sách các bài đạt chuẩn khớp (isMatch == true) có hệ số tương quan r_max cao nhất
        let bestResult: AudioMatchResult?
        if !matchedResults.isEmpty {
            bestResult = matchedResults.max(by: { $0.correlation < $1.correlation })
        } else {
            // Nếu không có bài nào đạt chuẩn khớp, lấy bài có độ tương quan r_max cao nhất để lưu kết quả tham khảo
            bestResult = allResults.max(by: { $0.correlation < $1.correlation })
        }
        
        if let best = bestResult, best.isMatch {
            logHandler?("🎉 ĐÃ TÌM THẤY NHẠC KHỚP NHẤT: \(best.audioName) (\(best.formattedScore), Offset: \(best.formattedOffset))")
        } else {
            let maxCorr = (bestResult?.correlation ?? 0.0) * 100.0
            logHandler?("ℹ️ Không tìm thấy bài nhạc nào đạt ngưỡng tin cậy (r >= 5% & Score >= 3.0). Tương quan cao nhất: \(String(format: "%.1f%%", maxCorr)).")
        }
        
        return bestResult
    }
}
