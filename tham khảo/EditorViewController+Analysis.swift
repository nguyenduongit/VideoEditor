import AppKit
import AVFoundation
import CoreImage

extension EditorViewController {
    func openVideo() { importMedia() }

    func importMedia() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp4", "mov", "m4v", "avi", "mp3", "wav", "m4a", "aac", "aiff", "flac"]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.message = "Chọn một video, một audio hoặc cả hai."
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        guard (1...2).contains(urls.count) else {
            report("Mỗi lần chỉ nhập tối đa một video và một audio.")
            return
        }
        busy = true; player.pause(); report("Đang chuẩn bị nguồn…"); refresh()
        worker.async { [weak self] in
            let result = Result { try MediaImportService.load(urls) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }; self.busy = false
                switch result {
                case .success(let imported):
                    let video = imported.first { $0.isVideo }
                    let audio = imported.first { !$0.isVideo }
                    if video != nil {
                        self.cancelPoseAnalysis()
                        self.cancelColorAnalysis()
                    }
                    self.change("Nhập nguồn") { s in
                        if let video = video {
                            s.video = video.identity; s.sourceDuration = video.duration; s.pose = nil
                            s.legScale = 1.0; s.legHipY = 0.55; s.legAnkleY = 0.25; s.showLegGuides = false
                            // Reset trim cũ địo theo timeline nguồn video cũ; giữ lại sẽ cắt sai.
                            s.videoTrimEnd = nil; s.audioTrimEnd = nil
                        }
                        if let audio = audio {
                            s.audio = audio.identity; s.audioDuration = audio.duration
                            // Reset audioTrimEnd: mốc trim được đo theo timeline nguồn audio cũ.
                            s.audioTrimEnd = nil
                        }
                        s.match = nil; s.blocks = []; s.fades = []; s.videoEffects = []; s.fadeIn = false; s.fadeOut = false
                        s.baseBPM = 120; s.targetBPM = 120; s.phase = 0
                    }
                    self.timeline.peaks = []
                    self.report(imported.count == 2 ? "Đã nhập video và audio. Nhấn Đồng bộ để khớp nhạc." : "Đã nhập \(video == nil ? "audio" : "video").")
                    if video != nil {
                        self.analyzePose(background: true)
                        self.analyzeWaveform(updateBeat: true)
                    }
                case .failure(let error): self.report(error.localizedDescription)
                }
                self.refresh()
            }
        }
    }

    func synchronize() {
        guard !busy, let v = session.video, let a = session.audio else { return }
        busy = true; player.pause(); report("Đang phân tích và khớp nhạc…"); refresh()
        worker.async { [weak self] in
            let video = MediaItem(name: URL(fileURLWithPath: v.path).lastPathComponent, mediaType: .video, sourceURL: URL(fileURLWithPath: v.path), localURL: URL(fileURLWithPath: v.path), fileSize: v.size, status: .synced)
            let audio = MediaItem(name: URL(fileURLWithPath: a.path).lastPathComponent, mediaType: .audio, sourceURL: URL(fileURLWithPath: a.path), localURL: URL(fileURLWithPath: a.path), fileSize: a.size, status: .synced)
            let result = AudioMatcherService.shared.findBestMatchingAudio(videoItem: video, candidateAudioItems: [audio])
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }; self.busy = false
                if let result = result, result.isMatch {
                    self.change("Đồng bộ nhạc") { s in
                        let changedClock = s.match?.offset != result.offsetSeconds
                        s.match = EditorMatch(video: v, audio: a, offset: result.offsetSeconds, score: result.score, correlation: result.correlation)
                        if changedClock { s.blocks = []; s.fades = []; s.normalizeVideoEffects() }
                        if s.title.isEmpty { s.title = MediaScannerService.shared.extractRealFilename(from: URL(fileURLWithPath: a.path).deletingPathExtension().lastPathComponent) }
                    }
                    self.report("Đã khớp nhạc. Audio ngoài đang thay hoàn toàn audio gốc."); self.analyzeWaveform(updateBeat: true)
                } else { self.report("Không tìm được kết quả khớp đạt chuẩn. Chưa áp dụng audio mới.") }
                self.refresh()
            }
        }
    }

    func analyzeWaveform(updateBeat: Bool) {
        waveformGeneration += 1; let token = waveformGeneration
        let snapshot = session
        guard let identity = snapshot.match == nil ? snapshot.video : snapshot.audio else { return }
        worker.async { [weak self] in
            guard let samples = AudioDecoderService.shared.decodeToMonoFloat32(url: URL(fileURLWithPath: identity.path)) else { return }
            let rate = AudioDecoderService.targetSampleRate
            let start = snapshot.match == nil ? 0 : snapshot.audioStart
            let lo = min(samples.count, max(0, Int(start * rate)))
            let hi = min(samples.count, lo + max(0, Int(snapshot.duration * rate)))
            let clip = Array(samples[lo..<hi])
            let beat = updateBeat ? BeatDetectorService.shared.analyzeSamples(clip, sampleRate: rate) : nil
            let strideSize = max(1, Int(rate / 100))
            var peaks: [Float] = []
            for i in stride(from: 0, to: clip.count, by: strideSize) { peaks.append(clip[i..<min(i + strideSize, clip.count)].map { abs($0) }.max() ?? 0) }
            let capturedPeaks = peaks
            DispatchQueue.main.async { [weak self] in
                guard let self = self, token == self.waveformGeneration, self.session.video == snapshot.video, self.session.match == snapshot.match else { return }
                self.timeline.peaks = snapshot.match == nil ? [] : capturedPeaks; self.timeline.peakStep = Double(strideSize) / rate
                if let beat = beat, beat.confidence > 0.05, self.session.blocks.isEmpty {
                    self.change("Phân tích nhịp") { s in
                        s.baseBPM = max(31, min(300, beat.bpm)); s.targetBPM = s.baseBPM; s.phase = beat.firstDownbeatTime
                    }
                }
            }
        }
    }

    func cancelPoseAnalysis() {
        poseAnalysisGeneration += 1
        poseAnalysisPending = false
        poseAnalysisUserInitiated = false
        poseAnalysisError = nil
    }

    func cancelColorAnalysis() {
        colorAnalysisGeneration += 1
        colorAnalysisPending = false
    }

    func analyzePose(background: Bool = false) {
        guard !busy, let source = session.video else { return }
        poseAnalysisGeneration += 1
        let generation = poseAnalysisGeneration
        poseAnalysisPending = true
        poseAnalysisUserInitiated = !background
        poseAnalysisError = nil
        let target = session.targetRatio
        refresh()
        poseWorker.async { [weak self] in
            let result = BodyPoseService.shared.analyzeBodyProportion(
                videoURL: URL(fileURLWithPath: source.path),
                targetRatio: target,
                shouldCancel: { [weak self] in
                    guard let self = self else { return true }
                    return DispatchQueue.main.sync { generation != self.poseAnalysisGeneration }
                },
                logHandler: { [weak self] message in
                    guard !background else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, generation == self.poseAnalysisGeneration, self.session.video == source else { return }
                        self.logMessages.append(message)
                    }
                }
            )
            DispatchQueue.main.async { [weak self] in
                guard let self = self, generation == self.poseAnalysisGeneration, self.session.video == source else { return }
                self.poseAnalysisPending = false
                self.poseAnalysisUserInitiated = false
                if let result = result {
                    if background {
                        self.applyBackgroundPoseResult(result)
                    } else {
                        self.changeFromBackground("Phân tích dáng") {
                            $0.pose = PoseSnapshot(result)
                            $0.legHipY = result.hipYNorm
                            $0.legAnkleY = result.ankleYNorm
                            $0.targetRatio = result.targetRatio
                        }
                    }
                    self.logMessages.append("AI đã xác định hai đường trên \(result.legGuideFrames.count) frame.")
                } else {
                    if !background {
                        self.poseAnalysisError = "Không nhận diện được dáng người. Hãy thử phân tích lại."
                    }
                    self.logMessages.append("Không nhận diện được dáng người.")
                }
                self.refresh()
            }
        }
    }

    func applyBackgroundPoseResult(_ result: BodyProportionResult) {
        cachedPoseResult = result
        var next = session
        next.pose = PoseSnapshot(result)
        next.legHipY = result.hipYNorm
        next.legAnkleY = result.ankleYNorm
        next.targetRatio = result.targetRatio
        guard next != session else {
            refresh()
            return
        }
        apply(next, name: "Phân tích dáng", live: false)
    }

    func analyzeColor() {
        guard !busy, !colorAnalysisPending, let source = session.video else { return }
        colorAnalysisGeneration += 1
        let generation = colorAnalysisGeneration
        colorAnalysisPending = true
        report("Đang phân tích màu…")
        refresh()
        colorWorker.async { [weak self] in
            let asset = AVURLAsset(url: URL(fileURLWithPath: source.path)); let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
            var images: [CIImage] = []
            for i in 0..<20 { if let image = try? generator.copyCGImage(at: EditorCompositionService.time(asset.duration.seconds * Double(i) / 20), actualTime: nil) { images.append(CIImage(cgImage: image)) } }
            let result = images.isEmpty ? nil : ColorGradingService.shared.analyzeColors(from: images)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, generation == self.colorAnalysisGeneration, self.session.video == source else { return }
                self.colorAnalysisPending = false
                if let result = result { self.changeFromBackground("Phân tích màu") { $0.adjustments.apply(result); $0.adjustments.enabled = true }; self.report("Đã áp dụng thông số màu phân tích.") }
                else { self.report("Không đọc được khung hình để phân tích màu.") }; self.refresh()
            }
        }
    }
}
