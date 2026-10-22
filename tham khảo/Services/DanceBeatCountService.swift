import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreImage

public enum CountIntervalMode: Int, Sendable {
    case twoBars = 1  // 2 nhịp có 8 tiếng đếm (1 phách / tiếng đếm)
    case fourBars = 2 // 4 nhịp có 8 tiếng đếm (2 phách / tiếng đếm)
}

public struct BeatCountSettings: Sendable {
    public var baseBPM: Double = 90.0    // BPM nguyên bản (đặt theo video/nhạc gốc)
    public var targetBPM: Double = 90.0  // BPM điều chỉnh qua thanh trượt (mặc định trung điểm 90)
    public var intervalMode: CountIntervalMode = .twoBars // Mặc định 2 nhịp (8 tiếng đếm)
    public var voiceVolume: Float = 1.0  // Âm lượng tiếng đếm (0.0 -> 1.0)
    public var musicVolume: Float = 0.85 // Âm lượng nhạc gốc (0.0 -> 1.0)
    public var startOffset: Double? = nil // Điểm bắt đầu số 1 do người dùng chọn trên đường kẻ nhịp
    public var endOffset: Double? = nil   // Điểm kết thúc đếm do người dùng chọn
    public var showNumbersOverlay: Bool = true // Bật/tắt chức năng số hiển thị trên màn hình
    
    /// Hệ số co giãn tốc độ: targetBPM / baseBPM
    public var speedRatio: Double {
        guard baseBPM > 20.0 else { return 1.0 }
        return targetBPM / baseBPM
    }
    
    public init() {}
}

public struct BeatEvent: Sendable {
    public let time: Double
    public let audioURL: URL
    public let label: String
    public let phraseNumber: Int
    public let beatIndex: Int
}

public struct DanceBeatSegment: Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var index: Int               // 1, 2, 3...
    public var name: String             // "Đoạn 1", "Đoạn 2"...
    public var startTime: Double        // Mốc bắt đầu trong video gốc (giây)
    public var endTime: Double          // Mốc kết thúc trong video gốc (giây)
    public var baseStartOffset: Double? // Mốc bắt đầu đếm phách 1 gốc (relative to segment start, giây)
    public var startOffset: Double?     // Mốc bắt đầu đếm phách 1 co giãn (relative to segment start, giây)
    public var baseEndOffset: Double?   // Mốc kết thúc đếm gốc (relative to segment start, giây)
    public var endOffset: Double?       // Mốc kết thúc đếm co giãn (relative to segment start, giây)
    public var intervalMode: CountIntervalMode = .twoBars
    public var showNumbersOverlay: Bool? = nil
    
    public var duration: Double {
        return max(0.0, endTime - startTime)
    }
    
    public init(
        id: UUID = UUID(),
        index: Int = 1,
        name: String = "Đoạn 1",
        startTime: Double = 0.0,
        endTime: Double = 0.0,
        baseStartOffset: Double? = nil,
        startOffset: Double? = nil,
        baseEndOffset: Double? = nil,
        endOffset: Double? = nil,
        intervalMode: CountIntervalMode = .twoBars,
        showNumbersOverlay: Bool? = nil
    ) {
        self.id = id
        self.index = index
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.baseStartOffset = baseStartOffset
        self.startOffset = startOffset
        self.baseEndOffset = baseEndOffset
        self.endOffset = endOffset
        self.intervalMode = intervalMode
        self.showNumbersOverlay = showNumbersOverlay
    }
}

public final class DanceBeatCountService: @unchecked Sendable {
    public static let shared = DanceBeatCountService()
    
    private var voiceBankURL: URL {
        if let bundleURL = Bundle.main.url(forResource: "VoiceBank", withExtension: nil),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
        let fallback = URL(fileURLWithPath: "Resources/VoiceBank")
        return fallback
    }
    
    private init() {}
    
    // MARK: - Voice Asset Resolvers
    
    /// Lấy tệp âm thanh cho số đầu câu (Hỗ trợ đầy đủ từ 1 đến 99)
    public func urlForPhraseNumber(_ phrase: Int) -> URL? {
        let directName = "phrase_\(phrase).wav"
        let directURL = voiceBankURL.appendingPathComponent(directName)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return directURL
        }
        
        let numName = "number_\(phrase).wav"
        let numURL = voiceBankURL.appendingPathComponent(numName)
        if FileManager.default.fileExists(atPath: numURL.path) {
            return numURL
        }
        
        // Nếu vượt quá 99 (rất hiếm trong bài nhảy), lặp lại theo chu kỳ 99
        let mod = ((phrase - 1) % 99) + 1
        return voiceBankURL.appendingPathComponent("phrase_\(mod).wav")
    }
    
    /// Lấy tệp âm thanh cho các nhịp đếm từ 2 đến 8 (hoặc các số 9, 10, 11, 12... khi vòng cuối dồn số)
    public func urlForCountBeat(_ beat: Int) -> URL? {
        let name = "count_\(beat).wav"
        let url = voiceBankURL.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        
        let numName = "number_\(beat).wav"
        let numURL = voiceBankURL.appendingPathComponent(numName)
        if FileManager.default.fileExists(atPath: numURL.path) {
            return numURL
        }
        
        return nil
    }
    
    // MARK: - Waveform Extraction
    
    /// Trích xuất danh sách đỉnh sóng âm chuẩn hóa 0.0 -> 1.0 để hiển thị trên WaveformBeatGridView
    public func generateWaveformPeaks(samples: [Float], targetCount: Int = 1600) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let chunkSize = max(1, samples.count / targetCount)
        var peaks: [Float] = []
        peaks.reserveCapacity(targetCount)
        
        for i in 0..<targetCount {
            let start = i * chunkSize
            let end = min(samples.count, start + chunkSize)
            guard start < end else { break }
            var maxVal: Float = 0.0
            for j in start..<end {
                let v = abs(samples[j])
                if v > maxVal { maxVal = v }
            }
            peaks.append(min(1.0, maxVal))
        }
        return peaks
    }
    
    // MARK: - Timeline Generator
    
    /// Sinh danh sách sự kiện đếm nhịp từ điểm bắt đầu do người dùng chọn trên đường kẻ nhịp.
    /// Nếu vòng cuối cùng không đủ 8 số thì dồn chung với vòng trước đó (vd: 12 số: 1..12).
    public func generateTimeline(duration: Double, settings: BeatCountSettings) -> [BeatEvent] {
        var events: [BeatEvent] = []
        guard settings.targetBPM > 30.0 && duration > 0.3 else { return events }
        guard let startOffset = settings.startOffset else {
            // Chưa chọn điểm bắt đầu thì chưa sinh tiếng đếm
            return events
        }
        
        let secondsPerBeat = 60.0 / settings.targetBPM
        let secondsPerCount = secondsPerBeat * Double(settings.intervalMode.rawValue)
        let maxLimit = settings.endOffset != nil ? min(duration - 0.3, settings.endOffset! + 0.02) : (duration - 0.3)
        guard maxLimit >= startOffset else { return events }
        
        let availableDuration = max(0.0, maxLimit - startOffset)
        let totalCounts = Int(floor(availableDuration / secondsPerCount + 0.001)) + 1
        guard totalCounts > 0 else { return events }
        
        // Phân bổ số phách cho từng câu: Nếu vòng cuối không đủ 8 số thì dồn chung vào vòng trước
        let phraseLengths = DanceBeatOverlayRenderer.computePhraseLengths(totalCounts: totalCounts)
        
        var currentTime = startOffset
        for (phraseIdx0, length) in phraseLengths.enumerated() {
            let phraseNumber = phraseIdx0 + 1
            for beatIndex in 1...length {
                if currentTime > maxLimit { break }
                
                if beatIndex == 1 {
                    // Số đầu câu: Phrase number (1..99)
                    if let url = urlForPhraseNumber(phraseNumber) {
                        events.append(BeatEvent(
                            time: currentTime,
                            audioURL: url,
                            label: "\(phraseNumber)",
                            phraseNumber: phraseNumber,
                            beatIndex: 1
                        ))
                    }
                } else {
                    // Các số tiếp theo: 2..8 và 9, 10, 11, 12... nếu vòng cuối dồn
                    if let url = urlForCountBeat(beatIndex) {
                        events.append(BeatEvent(
                            time: currentTime,
                            audioURL: url,
                            label: "\(beatIndex)",
                            phraseNumber: phraseNumber,
                            beatIndex: beatIndex
                        ))
                    }
                }
                
                currentTime += secondsPerCount
            }
        }
        
        return events
    }
    
    // MARK: - Composition Builder
    
    /// Cấu trúc kết quả đóng gói AVMutableComposition và AVAudioMix cho tiếng đếm nhịp
    public struct DanceBeatComposition: @unchecked Sendable {
        public let composition: AVMutableComposition
        public let audioMix: AVAudioMix
        public let duration: CMTime

        public init(composition: AVMutableComposition, audioMix: AVAudioMix, duration: CMTime) {
            self.composition = composition
            self.audioMix = audioMix
            self.duration = duration
        }
    }

    /// Xây dựng AVMutableComposition đồng bộ tốc độ Video/Nhạc theo BPM và hòa trộn tiếng đếm
    public func buildComposition(
        sourceURL: URL,
        settings: BeatCountSettings,
        completion: @escaping @Sendable (Result<DanceBeatComposition, AppError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: sourceURL)
            let origDurationSec = CMTimeGetSeconds(asset.duration)
            guard origDurationSec > 1.0 else {
                DispatchQueue.main.async { completion(.failure(AppError.media(.invalidDuration))) }
                return
            }
            
            // Tính toán tỷ lệ co giãn thời gian theo tỷ số targetBPM / baseBPM
            let speedRatio = max(0.4, min(2.5, settings.speedRatio))
            let scaledDurationSec = origDurationSec / speedRatio
            let scaledDuration = CMTime(seconds: scaledDurationSec, preferredTimescale: 44100)
            
            let composition = AVMutableComposition()
            
            // 1. Thêm Video Track nếu nguồn là Video và co giãn theo BPM
            let videoTracks = asset.tracks(withMediaType: .video)
            if let sourceVideo = videoTracks.first {
                if let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    compVideoTrack.preferredTransform = sourceVideo.preferredTransform
                    let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                    do {
                        try compVideoTrack.insertTimeRange(timeRange, of: sourceVideo, at: .zero)
                    } catch {
                        print("❌ [DanceBeatCountService] Lỗi chèn video track preview: \(error.localizedDescription)")
                    }
                    compVideoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: asset.duration), toDuration: scaledDuration)
                }
            }
            
            // 2. Thêm Âm thanh gốc (Music Track) và co giãn theo BPM
            guard let compMusicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async { completion(.failure(AppError.media(.trackAllocationFailed(.audio)))) }
                return
            }
            
            let audioTracks = asset.tracks(withMediaType: .audio)
            if let sourceAudio = audioTracks.first {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                do {
                    try compMusicTrack.insertTimeRange(timeRange, of: sourceAudio, at: .zero)
                } catch {
                    print("❌ [DanceBeatCountService] Lỗi chèn music track preview: \(error.localizedDescription)")
                }
                compMusicTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: asset.duration), toDuration: scaledDuration)
            }
            
            // 3. Thêm Track Giọng Đếm (Voice Track)
            guard let compVoiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async { completion(.failure(AppError.media(.trackAllocationFailed(.audio)))) }
                return
            }
            
            let timeline = self.generateTimeline(duration: scaledDurationSec, settings: settings)
            for event in timeline {
                let voiceAsset = AVURLAsset(url: event.audioURL)
                if let voiceAudio = voiceAsset.tracks(withMediaType: .audio).first {
                    let insertTime = CMTime(seconds: event.time, preferredTimescale: 44100)
                    let voiceDuration = voiceAsset.duration
                    let range = CMTimeRange(start: .zero, duration: voiceDuration)
                    do {
                        try compVoiceTrack.insertTimeRange(range, of: voiceAudio, at: insertTime)
                    } catch {
                        print("❌ [DanceBeatCountService] Lỗi chèn voice track preview (\(event.label)): \(error.localizedDescription)")
                    }
                }
            }
            
            // 4. Cấu hình AVAudioMix với điều chỉnh âm lượng riêng biệt & Auto-Ducking
            let audioMix = AVMutableAudioMix()
            var inputParameters: [AVMutableAudioMixInputParameters] = []
            
            // Cài đặt âm lượng nhạc gốc & thuật toán Spectral Time-Pitch co giãn không vỡ tiếng
            let musicParam = AVMutableAudioMixInputParameters(track: compMusicTrack)
            musicParam.setVolume(settings.musicVolume, at: .zero)
            musicParam.audioTimePitchAlgorithm = .spectral
            inputParameters.append(musicParam)
            
            // Cài đặt âm lượng giọng đếm
            let voiceParam = AVMutableAudioMixInputParameters(track: compVoiceTrack)
            voiceParam.setVolume(settings.voiceVolume, at: .zero)
            inputParameters.append(voiceParam)
            
            audioMix.inputParameters = inputParameters
            
            DispatchQueue.main.async {
                let result = DanceBeatComposition(composition: composition, audioMix: audioMix, duration: scaledDuration)
                completion(.success(result))
            }
        }
    }

    /// Overload tương thích ngược cho buildComposition
    public func buildComposition(
        sourceURL: URL,
        settings: BeatCountSettings,
        completion: @escaping (AVMutableComposition?, AVAudioMix?, CMTime?) -> Void
    ) {
        buildComposition(sourceURL: sourceURL, settings: settings) { (result: Result<DanceBeatComposition, AppError>) in
            switch result {
            case .success(let built):
                completion(built.composition, built.audioMix, built.duration)
            case .failure:
                completion(nil, nil, nil)
            }
        }
    }
    
    // MARK: - Export Methods
    
    /// Xuất tệp Âm thanh lồng tiếng đếm (.m4a) sử dụng Result type
    public func exportCountedAudio(
        sourceURL: URL,
        outputURL: URL,
        settings: BeatCountSettings,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
        completion: @escaping @Sendable (Result<URL, AppError>) -> Void
    ) {
        buildComposition(sourceURL: sourceURL, settings: settings) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let built):
                try? FileManager.default.removeItem(at: outputURL)
                guard let exportSession = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetAppleM4A) else {
                    completion(.failure(AppError.export(.exportSessionCreationFailed)))
                    return
                }
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .m4a
                exportSession.audioMix = built.audioMix
                let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    progressHandler?(Double(exportSession.progress))
                }
                exportSession.exportAsynchronously {
                    timer.invalidate()
                    DispatchQueue.main.async {
                        if exportSession.status == .completed {
                            progressHandler?(1.0)
                            completion(.success(outputURL))
                        } else {
                            let msg = exportSession.error?.localizedDescription ?? "Lỗi xuất âm thanh."
                            completion(.failure(AppError.export(.failed(reason: msg))))
                        }
                    }
                }
            }
        }
    }

    /// Overload tương thích ngược cho exportCountedAudio
    public func exportCountedAudio(
        sourceURL: URL,
        outputURL: URL,
        settings: BeatCountSettings,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        exportCountedAudio(sourceURL: sourceURL, outputURL: outputURL, settings: settings, progressHandler: progressHandler) { (result: Result<URL, AppError>) in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
    
    /// Xuất tệp Video chuẩn 1080p 30fps và lồng tiếng đếm nhịp sử dụng Result type
    public func exportCountedVideo(
        sourceURL: URL,
        outputURL: URL,
        settings: BeatCountSettings,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
        completion: @escaping @Sendable (Result<URL, AppError>) -> Void
    ) {
        buildComposition(sourceURL: sourceURL, settings: settings) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let built):
                let composition = built.composition
                let audioMix = built.audioMix
                
                try? FileManager.default.removeItem(at: outputURL)
                
                // Dùng Highest Quality preset kết hợp Video Composition để kiểm soát chính xác 1080p @ 30fps
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                    completion(.failure(AppError.export(.exportSessionCreationFailed)))
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.audioMix = audioMix
                exportSession.shouldOptimizeForNetworkUse = true
                
                // ── CẤU HÌNH XUẤT VIDEO CHUẨN 1080P @ 30FPS ─────────────────────────
                let asset = AVURLAsset(url: sourceURL)
                if let srcVideo = asset.tracks(withMediaType: .video).first,
                   !composition.tracks(withMediaType: .video).isEmpty {
                    
                    // Tính kích thước sau khi xoay đúng chiều
                    let orientedSize = srcVideo.naturalSize.applying(srcVideo.preferredTransform)
                    let orientedWidth = max(1.0, abs(orientedSize.width))
                    let orientedHeight = max(1.0, abs(orientedSize.height))
                    
                    let targetRenderSize: CGSize
                    if orientedHeight >= orientedWidth {
                        // Video dọc (TikTok/Reels/Shorts 9:16) -> Cố định chiều rộng 1080, chiều cao theo tỷ lệ gốc (1080x1920)
                        let renderWidth: CGFloat = 1080
                        let rawHeight = round((1080.0 * orientedHeight / orientedWidth) / 2.0) * 2.0
                        let renderHeight = max(1080, rawHeight)
                        targetRenderSize = CGSize(width: renderWidth, height: renderHeight)
                    } else {
                        // Video ngang (YouTube/Standard 16:9) -> Cố định chiều cao 1080, chiều rộng theo tỷ lệ gốc (1920x1080)
                        let renderHeight: CGFloat = 1080
                        let rawWidth = round((1080.0 * orientedWidth / orientedHeight) / 2.0) * 2.0
                        let renderWidth = max(1080, rawWidth)
                        targetRenderSize = CGSize(width: renderWidth, height: renderHeight)
                    }
                    
                    let videoComposition = AVMutableVideoComposition(asset: composition) { request in
                        let sourceImage = request.sourceImage
                        let srcExtent = sourceImage.extent
                        
                        guard srcExtent.width > 0 && srcExtent.height > 0 else {
                            request.finish(with: sourceImage, context: nil)
                            return
                        }
                        
                        // Chuẩn hóa gốc tọa độ về (0, 0)
                        let normalized = sourceImage.transformed(by: CGAffineTransform(translationX: -srcExtent.origin.x, y: -srcExtent.origin.y))
                        
                        let scaleX = targetRenderSize.width / srcExtent.width
                        let scaleY = targetRenderSize.height / srcExtent.height
                        let scale = min(scaleX, scaleY)
                        
                        let scaledImage = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        let tx = (targetRenderSize.width - srcExtent.width * scale) / 2.0
                        let ty = (targetRenderSize.height - srcExtent.height * scale) / 2.0
                        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: tx, y: ty))
                        
                        let currentTime = request.compositionTime.seconds
                        let durSec = CMTimeGetSeconds(built.duration)
                        if let overlay = DanceBeatOverlayRenderer.shared.overlayImage(
                            at: currentTime,
                            renderSize: targetRenderSize,
                            bpm: settings.targetBPM,
                            intervalMode: settings.intervalMode,
                            startOffset: settings.startOffset,
                            endOffset: settings.endOffset,
                            duration: durSec,
                            segmentTitle: nil,
                            showNumbers: settings.showNumbersOverlay
                        ) {
                            let composited = overlay.composited(over: centeredImage)
                            request.finish(with: composited, context: nil)
                        } else {
                            request.finish(with: centeredImage, context: nil)
                        }
                    }
                    
                    videoComposition.renderSize = targetRenderSize
                    videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // Chuẩn cố định 30 fps
                    exportSession.videoComposition = videoComposition
                }
                
                let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    progressHandler?(Double(exportSession.progress))
                }
                
                exportSession.exportAsynchronously {
                    timer.invalidate()
                    DispatchQueue.main.async {
                        if exportSession.status == .completed {
                            progressHandler?(1.0)
                            completion(.success(outputURL))
                        } else {
                            let msg = exportSession.error?.localizedDescription ?? "Lỗi xuất video."
                            completion(.failure(AppError.export(.failed(reason: msg))))
                        }
                    }
                }
            }
        }
    }

    /// Overload tương thích ngược cho exportCountedVideo
    public func exportCountedVideo(
        sourceURL: URL,
        outputURL: URL,
        settings: BeatCountSettings,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        exportCountedVideo(sourceURL: sourceURL, outputURL: outputURL, settings: settings, progressHandler: progressHandler) { (result: Result<URL, AppError>) in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Multi-Segment Exporting
    
    /// Xây dựng AVMutableComposition cho 1 phân đoạn cụ thể, có bước đệm 4 nhịp trước & sau vị trí cắt, co giãn theo BPM và lồng tiếng đếm kèm lớp phủ số đếm & nhịp chuẩn bị
    public func buildSegmentComposition(
        sourceURL: URL,
        segment: DanceBeatSegment,
        settings: BeatCountSettings,
        completion: @escaping @Sendable (AVMutableComposition?, AVAudioMix?, AVMutableVideoComposition?, CMTime?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: sourceURL)
            let totalAssetDuration = CMTimeGetSeconds(asset.duration)
            
            let speedRatio = max(0.4, min(2.5, settings.speedRatio))
            let secondsPerBeat = 60.0 / settings.targetBPM
            let bufferDurationScaled = 4.0 * secondsPerBeat // 1 nhịp (1 bar) = 4 phách
            let bufferDurationOriginal = bufferDurationScaled * speedRatio
            
            // Biên thời gian có bước đệm 1 nhịp trước và sau vị trí cắt
            let maxDuration = totalAssetDuration > 0 ? totalAssetDuration : (segment.endTime + bufferDurationOriginal)
            let paddedStartTime = max(0.0, segment.startTime - bufferDurationOriginal)
            let paddedEndTime = min(maxDuration, segment.endTime + bufferDurationOriginal)
            let paddedDuration = max(0.3, paddedEndTime - paddedStartTime)
            
            let scaledDurSec = paddedDuration / speedRatio
            let scaledDuration = CMTime(seconds: scaledDurSec, preferredTimescale: 44100)
            
            let composition = AVMutableComposition()
            let sourceStartCM = CMTime(seconds: paddedStartTime, preferredTimescale: 44100)
            let sourceDurCM = CMTime(seconds: paddedDuration, preferredTimescale: 44100)
            let sourceRange = CMTimeRange(start: sourceStartCM, duration: sourceDurCM)
            
            // 1. Video Track
            let videoTracks = asset.tracks(withMediaType: .video)
            if let sourceVideo = videoTracks.first {
                if let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    compVideoTrack.preferredTransform = sourceVideo.preferredTransform
                    try? compVideoTrack.insertTimeRange(sourceRange, of: sourceVideo, at: .zero)
                    compVideoTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: sourceDurCM), toDuration: scaledDuration)
                }
            }
            
            // 2. Audio Track (Music)
            guard let compMusicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async { completion(nil, nil, nil, nil) }
                return
            }
            
            let audioTracks = asset.tracks(withMediaType: .audio)
            if let sourceAudio = audioTracks.first {
                try? compMusicTrack.insertTimeRange(sourceRange, of: sourceAudio, at: .zero)
                compMusicTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: sourceDurCM), toDuration: scaledDuration)
            }
            
            // 3. Voice Track
            guard let compVoiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                DispatchQueue.main.async { completion(nil, nil, nil, nil) }
                return
            }
            
            var segSettings = settings
            segSettings.startOffset = segment.startOffset
            segSettings.endOffset = segment.endOffset
            segSettings.intervalMode = segment.intervalMode
            let timeline = self.generateTimeline(duration: scaledDurSec, settings: segSettings)
            for event in timeline {
                let voiceAsset = AVURLAsset(url: event.audioURL)
                if let voiceAudio = voiceAsset.tracks(withMediaType: .audio).first {
                    let insertTime = CMTime(seconds: event.time, preferredTimescale: 44100)
                    let voiceDuration = voiceAsset.duration
                    let range = CMTimeRange(start: .zero, duration: voiceDuration)
                    try? compVoiceTrack.insertTimeRange(range, of: voiceAudio, at: insertTime)
                }
            }
            
            // 4. Audio Mix (Có Fade In ở 1 nhịp đầu và Fade Out ở 1 nhịp cuối)
            let audioMix = AVMutableAudioMix()
            var inputParameters: [AVMutableAudioMixInputParameters] = []
            
            let musicParam = AVMutableAudioMixInputParameters(track: compMusicTrack)
            musicParam.audioTimePitchAlgorithm = .spectral
            
            let fadeInDuration = min(bufferDurationScaled, scaledDurSec / 3.0)
            let fadeOutDuration = min(bufferDurationScaled, scaledDurSec / 3.0)
            
            if fadeInDuration > 0.05 {
                let fadeInRange = CMTimeRange(start: .zero, duration: CMTime(seconds: fadeInDuration, preferredTimescale: 44100))
                musicParam.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: settings.musicVolume, timeRange: fadeInRange)
            } else {
                musicParam.setVolume(settings.musicVolume, at: .zero)
            }
            
            if fadeOutDuration > 0.05 && scaledDurSec > fadeInDuration {
                let fadeOutStartSec = max(fadeInDuration, scaledDurSec - fadeOutDuration)
                let actualFadeOutDur = scaledDurSec - fadeOutStartSec
                let fadeOutRange = CMTimeRange(start: CMTime(seconds: fadeOutStartSec, preferredTimescale: 44100), duration: CMTime(seconds: actualFadeOutDur, preferredTimescale: 44100))
                musicParam.setVolumeRamp(fromStartVolume: settings.musicVolume, toEndVolume: 0.0, timeRange: fadeOutRange)
            }
            
            inputParameters.append(musicParam)
            
            let voiceParam = AVMutableAudioMixInputParameters(track: compVoiceTrack)
            voiceParam.setVolume(settings.voiceVolume, at: .zero)
            inputParameters.append(voiceParam)
            
            audioMix.inputParameters = inputParameters
            
            // 5. Video Composition (1080p @ 30fps + Lớp phủ số đếm & 4 sao karaoke)
            var videoComposition: AVMutableVideoComposition? = nil
            if let srcVideo = asset.tracks(withMediaType: .video).first,
               !composition.tracks(withMediaType: .video).isEmpty {
                
                let orientedSize = srcVideo.naturalSize.applying(srcVideo.preferredTransform)
                let orientedWidth = max(1.0, abs(orientedSize.width))
                let orientedHeight = max(1.0, abs(orientedSize.height))
                
                let targetRenderSize: CGSize
                if orientedHeight >= orientedWidth {
                    let renderWidth: CGFloat = 1080
                    let rawHeight = round((1080.0 * orientedHeight / orientedWidth) / 2.0) * 2.0
                    let renderHeight = max(1080, rawHeight)
                    targetRenderSize = CGSize(width: renderWidth, height: renderHeight)
                } else {
                    let renderHeight: CGFloat = 1080
                    let rawWidth = round((1080.0 * orientedWidth / orientedHeight) / 2.0) * 2.0
                    let renderWidth = max(1080, rawWidth)
                    targetRenderSize = CGSize(width: renderWidth, height: renderHeight)
                }
                
                let bpm = settings.targetBPM
                let intervalMode = segment.intervalMode
                let startOffset = segment.startOffset
                let endOffset = segment.endOffset
                let totalDur = scaledDurSec
                let segmentTitle = segment.name
                let showNumbers = segment.showNumbersOverlay ?? settings.showNumbersOverlay
                
                let vComp = AVMutableVideoComposition(asset: composition) { request in
                    let sourceImage = request.sourceImage
                    let srcExtent = sourceImage.extent
                    guard srcExtent.width > 0 && srcExtent.height > 0 else {
                        request.finish(with: sourceImage, context: nil)
                        return
                    }
                    let normalized = sourceImage.transformed(by: CGAffineTransform(translationX: -srcExtent.origin.x, y: -srcExtent.origin.y))
                    let scaleX = targetRenderSize.width / srcExtent.width
                    let scaleY = targetRenderSize.height / srcExtent.height
                    let scale = min(scaleX, scaleY)
                    let scaledImage = normalized.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                    let tx = (targetRenderSize.width - srcExtent.width * scale) / 2.0
                    let ty = (targetRenderSize.height - srcExtent.height * scale) / 2.0
                    let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: tx, y: ty))
                    
                    let currentTime = request.compositionTime.seconds
                    if let overlay = DanceBeatOverlayRenderer.shared.overlayImage(
                        at: currentTime,
                        renderSize: targetRenderSize,
                        bpm: bpm,
                        intervalMode: intervalMode,
                        startOffset: startOffset,
                        endOffset: endOffset,
                        duration: totalDur,
                        segmentTitle: segmentTitle,
                        showNumbers: showNumbers
                    ) {
                        let composited = overlay.composited(over: centeredImage)
                        request.finish(with: composited, context: nil)
                    } else {
                        request.finish(with: centeredImage, context: nil)
                    }
                }
                vComp.renderSize = targetRenderSize
                vComp.frameDuration = CMTime(value: 1, timescale: 30)
                videoComposition = vComp
            }
            
            DispatchQueue.main.async {
                completion(composition, audioMix, videoComposition, scaledDuration)
            }
        }
    }
    
    /// Xuất video của 1 phân đoạn cụ thể với độ phân giải Full HD 1080p @ 30fps và lồng tiếng đếm kèm lớp phủ số đếm
    public func exportSegmentVideo(
        sourceURL: URL,
        outputURL: URL,
        segment: DanceBeatSegment,
        settings: BeatCountSettings,
        progressHandler: (@Sendable (Double) -> Void)? = nil,
        completion: @escaping @Sendable (Bool, String?) -> Void
    ) {
        buildSegmentComposition(sourceURL: sourceURL, segment: segment, settings: settings) { composition, audioMix, videoComposition, duration in
            guard let composition = composition, let audioMix = audioMix else {
                completion(false, "Không thể tạo bản dựng video cho \(segment.name).")
                return
            }
            
            try? FileManager.default.removeItem(at: outputURL)
            
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                completion(false, "Không thể khởi tạo bộ xuất video.")
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.audioMix = audioMix
            exportSession.videoComposition = videoComposition
            exportSession.shouldOptimizeForNetworkUse = true
            
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                progressHandler?(Double(exportSession.progress))
            }
            
            exportSession.exportAsynchronously {
                timer.invalidate()
                DispatchQueue.main.async {
                    if exportSession.status == .completed {
                        progressHandler?(1.0)
                        completion(true, nil)
                    } else {
                        completion(false, exportSession.error?.localizedDescription ?? "Lỗi xuất video.")
                    }
                }
            }
        }
    }
    
    /// Xuất tất cả các phân đoạn thành từng file video độc lập vào thư mục được chọn
    public func exportAllSegments(
        sourceURL: URL,
        outputFolderURL: URL,
        segments: [DanceBeatSegment],
        settings: BeatCountSettings,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard !segments.isEmpty else {
            completion(false, "Không có phân đoạn nào để xuất.")
            return
        }
        
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let totalCount = segments.count
        
        func exportNext(index: Int) {
            if index >= totalCount {
                progressHandler?(1.0)
                completion(true, nil)
                return
            }
            
            let seg = segments[index]
            let sanitizedSegName = seg.name.replacingOccurrences(of: " ", with: "_")
            let outName = "\(baseName)_\(sanitizedSegName)_\(Int(settings.targetBPM))BPM_1080p.mp4"
            let outURL = outputFolderURL.appendingPathComponent(outName)
            
            self.exportSegmentVideo(
                sourceURL: sourceURL,
                outputURL: outURL,
                segment: seg,
                settings: settings,
                progressHandler: { segProgress in
                    let overall = (Double(index) + segProgress) / Double(totalCount)
                    progressHandler?(overall)
                },
                completion: { success, err in
                    if success {
                        exportNext(index: index + 1)
                    } else {
                        completion(false, "Lỗi khi xuất \(seg.name): \(err ?? "Không rõ")")
                    }
                }
            )
        }
        
        exportNext(index: 0)
    }
}
