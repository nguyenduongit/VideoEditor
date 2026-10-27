import Foundation
import Accelerate
import Domain
import os

/// Implementation of AudioAlignmentServiceProtocol using Normalized Mel Spectral Flux Cross-Correlation.
public final class AudioAlignmentService: AudioAlignmentServiceProtocol, @unchecked Sendable {
    public let minMatchScoreThreshold: Double = 3.0
    public let minCorrelationThreshold: Double = 0.05

    private let decoder: AudioDecoderService
    private let melService: MelSpectrogramService
    private let logger = Logger(subsystem: "com.videoeditor", category: "AudioAlignmentService")

    public init(
        decoder: AudioDecoderService = AudioDecoderService(),
        melService: MelSpectrogramService = MelSpectrogramService()
    ) {
        self.decoder = decoder
        self.melService = melService
    }

    public func calculateAlignmentOffset(sourceURL1: URL, sourceURL2: URL) async -> AudioAlignmentResult? {
        async let tracks1Task = decoder.decodeAudioTracksToMonoFloat32(url: sourceURL1)
        async let samples2Task = decoder.decodeToMonoFloat32(url: sourceURL2)

        let (tracks1, samples2) = await (tracks1Task, samples2Task)

        guard !tracks1.isEmpty else {
            logger.notice("No audio tracks found in source 1: \(sourceURL1.lastPathComponent)")
            return nil
        }

        guard let samples2 else {
            logger.notice("Failed to decode audio in source 2: \(sourceURL2.lastPathComponent)")
            return nil
        }

        let flux2 = melService.computeNormalizedSpectralFlux(samples: samples2)
        guard !flux2.isEmpty else { return nil }

        var bestResult: AudioAlignmentResult?
        for samples1 in tracks1 {
            let flux1 = melService.computeNormalizedSpectralFlux(samples: samples1)
            guard !flux1.isEmpty else { continue }

            let raw = matchSpectralFlux(flux1: flux1, flux2: flux2)
            let refinedOffset = raw.isMatch ? refineOnsetEnvelope(
                samples1: samples1,
                samples2: samples2,
                coarseOffset: raw.offsetSeconds
            ) : raw.offsetSeconds

            let candidate = AudioAlignmentResult(
                offsetSeconds: refinedOffset,
                correlation: raw.correlation,
                score: raw.score,
                isMatch: raw.isMatch
            )

            if bestResult == nil || candidate.correlation > (bestResult?.correlation ?? 0.0) {
                bestResult = candidate
            }
        }
        return bestResult
    }

    // MARK: - Normalized Cross-Correlation

    func matchSpectralFlux(flux1: [[Float]], flux2: [[Float]]) -> AudioAlignmentResult {
        guard !flux1.isEmpty && !flux2.isEmpty else {
            return AudioAlignmentResult(offsetSeconds: 0, correlation: 0, score: 0, isMatch: false)
        }

        let nMels = min(flux1.count, flux2.count)
        let nFrames1 = flux1[0].count
        let nFrames2 = flux2[0].count
        let corrLen = nFrames1 + nFrames2 - 1
        var totalNormCorr = [Float](repeating: 0, count: corrLen)

        var padded1 = [Float](repeating: 0, count: nFrames1 + 2 * nFrames2)
        var bandCorr = [Float](repeating: 0, count: corrLen)
        let padOffset = nFrames2 - 1

        for m in 0..<nMels {
            let v1 = flux1[m]
            let v2 = flux2[m]

            var energy1: Float = 0
            vDSP_svesq(v1, 1, &energy1, vDSP_Length(nFrames1))
            let norm1 = sqrt(energy1) + 1e-6

            var energy2: Float = 0
            vDSP_svesq(v2, 1, &energy2, vDSP_Length(nFrames2))
            let norm2 = sqrt(energy2) + 1e-6

            v1.withUnsafeBufferPointer { pV1 in
                guard let bV1 = pV1.baseAddress else { return }
                padded1.withUnsafeMutableBufferPointer { pPad in
                    guard let bPad = pPad.baseAddress else { return }
                    bPad.advanced(by: padOffset).update(from: bV1, count: nFrames1)
                }
            }

            padded1.withUnsafeBufferPointer { p1 in
                v2.withUnsafeBufferPointer { p2 in
                    bandCorr.withUnsafeMutableBufferPointer { pC in
                        guard let b1 = p1.baseAddress, let b2 = p2.baseAddress, let bC = pC.baseAddress else { return }
                        vDSP_conv(b1, 1, b2, 1, bC, 1, vDSP_Length(corrLen), vDSP_Length(nFrames2))
                    }
                }
            }

            let normFactor = 1.0 / (norm1 * norm2)
            var scale = normFactor / Float(nMels)
            vDSP_vsma(bandCorr, 1, &scale, totalNormCorr, 1, &totalNormCorr, 1, vDSP_Length(corrLen))
        }

        return analyzeCorrelationPeak(totalNormCorr: totalNormCorr, corrLen: corrLen, nFrames2: nFrames2)
    }

    private func analyzeCorrelationPeak(totalNormCorr: [Float], corrLen: Int, nFrames2: Int) -> AudioAlignmentResult {
        var maxVal: Float = -Float.infinity
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(totalNormCorr, 1, &maxVal, &maxIndex, vDSP_Length(corrLen))
        let peakIndex = Int(maxIndex)

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

        var bgSamples: [Float] = []
        bgSamples.reserveCapacity(corrLen)
        for i in 0..<corrLen where abs(i - peakIndex) > 50 {
            bgSamples.append(abs(totalNormCorr[i]))
        }
        let sortedBg = bgSamples.sorted()
        let bgMedian = sortedBg.isEmpty ? 0.001 : sortedBg[sortedBg.count / 2]
        let score = Double(maxVal) / (Double(bgMedian) + 1e-6)

        let hop = Double(melService.hopLength)
        let rate = Double(melService.sampleRate)
        let offset = (refinedIndex - Double(nFrames2 - 1)) * hop / rate
        let isMatch = (Double(maxVal) >= minCorrelationThreshold) && (score >= minMatchScoreThreshold)

        return AudioAlignmentResult(
            offsetSeconds: offset,
            correlation: Double(maxVal),
            score: score,
            isMatch: isMatch
        )
    }

    // MARK: - Onset Envelope Refinement

    func refineOnsetEnvelope(samples1: [Float], samples2: [Float], coarseOffset: Double) -> Double {
        let sampleRate = AudioDecoderService.targetSampleRate
        let hop = max(1, Int(round(sampleRate * 0.005)))
        let window = max(hop, Int(round(sampleRate * 0.020)))

        let maxRefineSec = 10.0
        let maxSamples = Int(maxRefineSec * sampleRate)

        let s1Start = coarseOffset >= 0 ? min(samples1.count, Int(coarseOffset * sampleRate)) : 0
        let s2Start = coarseOffset < 0 ? min(samples2.count, Int(-coarseOffset * sampleRate)) : 0

        let s1Len = min(maxSamples, max(0, samples1.count - s1Start))
        let s2Len = min(maxSamples, max(0, samples2.count - s2Start))
        let commonCount = min(s1Len, s2Len)
        guard commonCount >= window * 4 else { return coarseOffset }

        let sub1 = Array(samples1[s1Start..<(s1Start + commonCount)])
        let sub2 = Array(samples2[s2Start..<(s2Start + commonCount)])

        let env1 = computeOnsetEnvelope(samples: sub1, hop: hop, window: window)
        let env2 = computeOnsetEnvelope(samples: sub2, hop: hop, window: window)
        guard env1.count >= 16, env2.count >= 16 else { return coarseOffset }

        let frameDur = Double(hop) / sampleRate
        let radius = max(1, Int(ceil(0.12 / frameDur)))

        var bestLag = 0
        var bestCorrelation = -Double.infinity
        var correlations: [Int: Double] = [:]
        for lag in (-radius)...radius {
            let corr = correlateEnvelopes(env1: env1, env2: env2, lag: lag)
            correlations[lag] = corr
            if corr > bestCorrelation {
                bestCorrelation = corr
                bestLag = lag
            }
        }
        guard bestCorrelation.isFinite, bestCorrelation > 0.02 else { return coarseOffset }

        var refinedLag = Double(bestLag)
        if let left = correlations[bestLag - 1], let right = correlations[bestLag + 1] {
            let denom = 2.0 * (left - 2.0 * bestCorrelation + right)
            if abs(denom) > 1e-9 {
                let delta = (left - right) / denom
                if abs(delta) <= 1.0 { refinedLag += delta }
            }
        }
        return coarseOffset + (refinedLag * frameDur)
    }

    private func computeOnsetEnvelope(samples: [Float], hop: Int, window: Int) -> [Float] {
        guard samples.count >= window, hop > 0 else { return [] }
        let numFrames = (samples.count - window) / hop + 1
        var energies = [Float](repeating: 0, count: numFrames)
        let winLen = vDSP_Length(window)

        samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for frameIdx in 0..<numFrames {
                var meanSquare: Float = 0
                vDSP_measqv(base + (frameIdx * hop), 1, &meanSquare, winLen)
                energies[frameIdx] = sqrt(meanSquare)
            }
        }

        guard energies.count > 1 else { return [] }
        var envelope = [Float](repeating: 0, count: energies.count)
        for idx in 1..<energies.count {
            envelope[idx] = max(0, energies[idx] - energies[idx - 1])
        }
        return envelope
    }

    private func correlateEnvelopes(env1: [Float], env2: [Float], lag: Int) -> Double {
        let lower = max(0, -lag)
        let upper = min(env2.count, env1.count - lag)
        let overlap = upper - lower
        let maxOverlap = min(env1.count, env2.count)
        guard overlap >= max(16, Int(Double(maxOverlap) * 0.30)) else { return 0 }

        var dot: Float = 0
        var e1: Float = 0
        var e2: Float = 0

        env1.withUnsafeBufferPointer { p1 in
            env2.withUnsafeBufferPointer { p2 in
                guard let b1 = p1.baseAddress, let b2 = p2.baseAddress else { return }
                let s1 = b1.advanced(by: lower + lag)
                let s2 = b2.advanced(by: lower)
                let len = vDSP_Length(overlap)
                vDSP_dotpr(s1, 1, s2, 1, &dot, len)
                vDSP_svesq(s1, 1, &e1, len)
                vDSP_svesq(s2, 1, &e2, len)
            }
        }

        let denom = Double(sqrt(e1 * e2))
        return denom > 1e-12 ? Double(dot) / denom : 0
    }
}
