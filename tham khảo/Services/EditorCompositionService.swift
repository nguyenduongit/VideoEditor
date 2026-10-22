import AppKit
import AVFoundation
import CoreImage

struct EditorRender: @unchecked Sendable {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let audioMix: AVMutableAudioMix
    let map: EditorTimeMap
    func playerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition; item.audioMix = audioMix
        item.audioTimePitchAlgorithm = .spectral
        return item
    }
}
final class EditorCompositionService {
    // Cache frame timestamps được bảo vệ bằng lock vì builder chạy trên worker thread.
    private static let cacheLock = NSLock()
    private static var cachedFrameTimes: [String: [CMTime]] = [:]
    // Key được xây dựng từ path + size + modified để invalidate khi file được thay thế cùng đượng dẫn.
    private static func cacheKey(for source: SourceIdentity) -> String {
        return "\(source.path):\(source.size):\(Int64(source.modified * 1000))"
    }
    static func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 60000) }

    /// Chọn nhịp render ổn định cho cả CFR và VFR. Một số track VFR/metadata lỗi
    /// báo nominalFrameRate = 0; dùng trực tiếp giá trị đó từng làm output rơi xuống 1 FPS.
    static func frameDuration(nominalFrameRate: Float, minFrameDuration: CMTime) -> CMTime {
        let fps = Double(nominalFrameRate)
        if fps.isFinite, fps > 0.0 {
            return time(1.0 / fps)
        }

        let minimum = minFrameDuration.seconds
        if minFrameDuration.isValid, minimum.isFinite, minimum > 0.0, minimum <= 1.0 {
            return time(minimum)
        }

        // Metadata không đủ: 30 FPS là fallback cân bằng cho preview và export.
        return time(1.0 / 30.0)
    }

    static func build(_ session: EditorSession) throws -> EditorRender {
        guard let source = session.video else { throw AppError.composition(.compositionBuildFailed(reason: "Chưa có video.")) }
        guard source.isCurrent, session.match == nil || session.audio?.isCurrent == true else { throw AppError.composition(.sourceChangedOrMissing) }
        let asset = AVURLAsset(url: URL(fileURLWithPath: source.path))
        guard let sourceVideo = asset.tracks(withMediaType: .video).first, session.duration > 0 else { throw AppError.media(.missingTrack(.video)) }
        let audioAsset: AVAsset
        if session.match != nil {
            guard let audio = session.audio else {
                throw AppError.composition(.missingLinkedAudio)
            }
            audioAsset = AVURLAsset(url: URL(fileURLWithPath: audio.path))
        } else {
            audioAsset = asset
        }
        let audioSource = audioAsset.tracks(withMediaType: .audio).first
        let audioStart = session.match == nil ? 0 : session.audioStart
        let composition = AVMutableComposition()
        guard let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw AppError.media(.trackAllocationFailed(.video)) }
        video.preferredTransform = sourceVideo.preferredTransform
        guard let music = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AppError.media(.trackAllocationFailed(.audio))
        }
        let map = EditorTimeMap(session)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        var frameTimes: [CMTime] = []
        if map.spans.contains(where: { $0.kind != .content }) {
            let key = cacheKey(for: source)
            let cached = cacheLock.withLock { cachedFrameTimes[key] }
            if let cached = cached {
                frameTimes = cached
            } else {
                let reader = try AVAssetReader(asset: asset)
                let output = AVAssetReaderTrackOutput(track: sourceVideo, outputSettings: nil)
                output.alwaysCopiesSampleData = false; reader.add(output)
                guard reader.startReading() else { throw reader.error ?? EditorError.message("Không đọc được thời gian frame.") }
                while let sample = output.copyNextSampleBuffer() {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sample)
                    if timestamp.seconds.isFinite && timestamp.seconds >= 0 { frameTimes.append(timestamp) }
                }
                guard reader.status == .completed, !frameTimes.isEmpty else { throw reader.error ?? EditorError.message("Video không có frame hợp lệ.") }
                frameTimes.sort { CMTimeCompare($0, $1) < 0 }
                cacheLock.withLock { cachedFrameTimes[key] = frameTimes }
            }
        }
        var frozen: [Double: CIImage] = [:]
        var frozenSource: [Double: Double] = [:]
        for span in map.spans {
            let destination = time(span.start)
            if span.kind == .content {
                let duration = time(span.sourceEnd - span.sourceStart)
                try video.insertTimeRange(CMTimeRange(start: time(session.videoStart + span.sourceStart), duration: duration), of: sourceVideo, at: destination)
                video.scaleTimeRange(CMTimeRange(start: destination, duration: duration), toDuration: time(span.duration))
                if let audioSource = audioSource {
                    let audioLimit = session.effectiveAudioDuration
                    let availableSource = max(0, min(span.sourceEnd, audioLimit) - span.sourceStart)
                    let begin = audioStart + span.sourceStart
                    let available = max(0, min(availableSource, audioAsset.duration.seconds - begin))
                    if available > 0 {
                        try music.insertTimeRange(CMTimeRange(start: time(begin), duration: time(available)), of: audioSource, at: destination)
                        music.scaleTimeRange(CMTimeRange(start: destination, duration: time(available)), toDuration: time(available / session.speed))
                    }
                }
            } else {
                // Exact adjacent source frame; the CI frame replaces the stretched sample during every hold.
                let boundary = session.videoStart + span.sourceStart
                var lo = 0, hi = frameTimes.count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    let t = frameTimes[mid].seconds
                    if span.kind == .fadeOut ? t < boundary - 0.0000001 : t <= boundary + 0.0000001 { lo = mid + 1 } else { hi = mid }
                }
                let index = max(0, lo - 1)
                let frameTime = frameTimes[index]
                var actual = CMTime.zero
                let cg = try generator.copyCGImage(at: frameTime, actualTime: &actual)
                frozen[span.start] = CIImage(cgImage: cg)
                frozenSource[span.start] = max(0, actual.seconds - session.videoStart)
                let nextTime = index + 1 < frameTimes.count ? frameTimes[index + 1].seconds : asset.duration.seconds
                let sampleDuration = max(1.0 / 60000, nextTime - frameTime.seconds)
                try video.insertTimeRange(CMTimeRange(start: frameTime, duration: time(sampleDuration)), of: sourceVideo, at: destination)
                video.scaleTimeRange(CMTimeRange(start: destination, duration: time(sampleDuration)), toDuration: time(span.duration))
            }
        }
        var parameters: [AVMutableAudioMixInputParameters] = []
        let musicParams = AVMutableAudioMixInputParameters(track: music)
        let baseVolume = Float(session.musicVolume)
        musicParams.setVolume(baseVolume, at: .zero)
        musicParams.audioTimePitchAlgorithm = .spectral
        let audioLimit = session.effectiveAudioDuration
        let audioOutputEnd = map.outputTime(for: audioLimit, afterHold: false)
        if session.audioFadeOutDuration > 0 && audioOutputEnd > 0 {
            let fadeDuration = min(session.audioFadeOutDuration, audioOutputEnd)
            let fadeStart = max(0, audioOutputEnd - fadeDuration)
            musicParams.setVolumeRamp(fromStartVolume: baseVolume, toEndVolume: 0.0, timeRange: CMTimeRange(start: time(fadeStart), duration: time(fadeDuration)))
            musicParams.setVolume(0.0, at: time(audioOutputEnd))
        } else if audioOutputEnd < map.duration {
            musicParams.setVolume(0.0, at: time(audioOutputEnd))
        }
        parameters.append(musicParams)
        var voicePool: [(track: AVMutableCompositionTrack, end: Double)] = []
        if !session.blocks.isEmpty {
            for block in session.blocks {
                let start = session.beatTime(block.startBeat)
                let end = session.beatTime(block.endBeat)
                var settings = BeatCountSettings()
                settings.baseBPM = session.baseBPM; settings.targetBPM = session.targetBPM
                settings.startOffset = 0; settings.endOffset = (end - start) / session.speed
                let events = DanceBeatCountService.shared.generateTimeline(duration: (end - start) / session.speed, settings: settings)
                for event in events {
                    let sourceTime = start + event.time * session.speed
                    let output = map.outputTime(for: sourceTime)
                    guard let span = map.span(at: output), span.kind == .content else { continue }
                    let voiceAsset = AVURLAsset(url: event.audioURL)
                    guard let track = voiceAsset.tracks(withMediaType: .audio).first else { throw AppError.media(.fileNotFound(event.audioURL)) }
                    let limit = min(span.end, map.outputTime(for: end, afterHold: false))
                    let duration = min(voiceAsset.duration.seconds, limit - output)
                    guard duration > 0 else { continue }
                    let slot: Int
                    if let free = voicePool.firstIndex(where: { $0.end <= output + 0.000001 }) { slot = free }
                    else {
                        guard let voice = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                            throw AppError.media(.trackAllocationFailed(.audio))
                        }
                        let p = AVMutableAudioMixInputParameters(track: voice)
                        p.setVolume(1.0, at: .zero); parameters.append(p)
                        voicePool.append((voice, 0)); slot = voicePool.count - 1
                    }
                    try voicePool[slot].track.insertTimeRange(CMTimeRange(start: .zero, duration: time(duration)), of: track, at: time(output))
                    voicePool[slot].end = output + duration
                }
            }
        }
        let mix = AVMutableAudioMix(); mix.inputParameters = parameters
        let oriented = sourceVideo.naturalSize.applying(sourceVideo.preferredTransform)
        let original = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        let renderSize: CGSize
        if session.cropEnabled {
            switch session.cropMode {
            case 1:
                renderSize = CGSize(width: floor(original.height * 9 / 16 / 2) * 2, height: floor(original.height / 2) * 2)
            case 2:
                renderSize = CGSize(width: floor(original.width / 2) * 2, height: floor(original.width * 9 / 16 / 2) * 2)
            case 3:
                let side = floor(min(original.width, original.height) / 2) * 2
                renderSize = CGSize(width: side, height: side)
            case 4:
                let h = floor(original.height / 2) * 2
                renderSize = CGSize(width: floor(h * 4 / 5 / 2) * 2, height: h)
            default:
                renderSize = CGSize(width: floor(original.width / 2) * 2, height: floor(original.height / 2) * 2)
            }
        } else {
            renderSize = CGSize(width: floor(original.width / 2) * 2, height: floor(original.height / 2) * 2)
        }
        let title = session.textEnabled ? EditorTitleRenderer().createTitleOverlayImage(settings: session.textSettings, renderSize: renderSize) : nil
        let poseResult = session.pose?.result()
        let frozenImages = frozen
        let frozenTimes = frozenSource
        let process: (CIImage, Double) -> CIImage = { input, outputTime in
            guard let span = map.span(at: outputTime) else { return input }
            let sourceTime = frozenTimes[span.start] ?? map.sourceTime(at: outputTime)
            let absoluteSourceTime = time(session.videoStart + sourceTime)
            let sourceGuides = poseResult?.legGuides(at: absoluteSourceTime)
                ?? (hipYNorm: session.legHipY, ankleYNorm: session.legAnkleY)
            var image = frozenImages[span.start] ?? input
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            if session.adjustments.enabled { image = ColorGradingService.shared.applyGrading(to: image, params: session.adjustments.params) }
            var cropOriginY: CGFloat = 0.0
            if session.cropEnabled {
                let cropPose = poseResult ?? BodyProportionResult(videoName: "", initialRatio: 1.48, targetRatio: 1.48, scaleFactor: 1.0, hipYNorm: 0.5, ankleYNorm: 0.1, videoSize: original, trackingData: [], personCount: 0, maxPersonHeightRatio: 0)
                let rect = VideoCropService.shared.calculateDynamicCropRect(
                    for: absoluteSourceTime,
                    proportion: cropPose,
                    cropMode: session.cropMode,
                    zoom: session.cropZoom,
                    offsetY: session.cropOffsetY,
                    autoPan: session.cropAutoPan,
                    panX: session.cropPanX
                )
                if rect.width > 0 && rect.height > 0 {
                    cropOriginY = rect.minY
                    if abs(session.cropRotation) > 0.001 {
                        let angle = CGFloat(session.cropRotation * .pi / 180.0)
                        var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
                        t = t.rotated(by: angle)
                        t = t.translatedBy(x: -rect.midX, y: -rect.midY)
                        image = image.transformed(by: t)
                    }
                    image = image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
                }
            }
            let extent = image.extent
            let scale = max(renderSize.width / max(1, extent.width), renderSize.height / max(1, extent.height))
            let translationY = (renderSize.height - extent.height * scale) / 2
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: (renderSize.width - extent.width * scale) / 2, y: translationY))

            // Hoàn tất mọi phép crop/resize trước khi chia ba khối. Nhờ vậy, thay đổi
            // hệ số kéo không thể khiến bước xử lý phía sau scale lại khối trên/dưới.
            let renderRect = CGRect(origin: .zero, size: renderSize)
            image = image
                .composited(over: CIImage(color: .black).cropped(to: renderRect))
                .cropped(to: renderRect)
            if session.legsEnabled {
                func outputNorm(_ sourceNorm: Double) -> Double {
                    let sourceY = CGFloat(sourceNorm) * max(1.0, original.height - 1.0)
                    let outputY = (sourceY - cropOriginY) * scale + translationY
                    return Double(max(0.0, min(renderSize.height - 1.0, outputY)) / max(1.0, renderSize.height - 1.0))
                }
                let prop = BodyProportionResult(
                    videoName: session.pose?.name ?? "",
                    initialRatio: session.pose?.initial ?? 1.2,
                    targetRatio: session.targetRatio,
                    scaleFactor: session.legScale,
                    hipYNorm: outputNorm(sourceGuides.hipYNorm),
                    ankleYNorm: outputNorm(sourceGuides.ankleYNorm),
                    isApplied: true,
                    videoSize: renderSize,
                    trackingData: session.pose?.result().trackingData ?? []
                )
                image = LegLengtheningService.shared.applyLegLengthening(to: image, proportion: prop)
            }
            if let title = title {
                let settings = session.textSettings
                let isVisible: Bool
                let localDuration: Double
                let elapsed: Double

                if settings.timingMode == 1 {
                    isVisible = sourceTime >= 0 && sourceTime <= session.duration
                    localDuration = max(0.1, session.duration)
                    elapsed = sourceTime
                } else {
                    let start = settings.startTime
                    let dur = max(0.1, settings.duration)
                    isVisible = sourceTime >= start && sourceTime <= (start + dur)
                    localDuration = dur
                    elapsed = sourceTime - start
                }

                if isVisible {
                    var alpha: Double = 1.0
                    var zoom: Double = 1.0
                    var offsetY: Double = 0.0
                    let remaining = localDuration - elapsed

                    switch settings.animationPreset {
                    case .none:
                        alpha = 1.0
                        zoom = 1.0
                        offsetY = 0.0
                    case .fadeZoom:
                        if elapsed < 0.5 {
                            let p = elapsed / 0.5
                            alpha = p
                            zoom = 0.85 + 0.15 * sin(p * .pi / 2)
                        } else if remaining < 0.5 {
                            let p = (0.5 - remaining) / 0.5
                            alpha = max(0, 1.0 - p)
                            zoom = 1.01 + 0.02 * p
                            offsetY = p * Double(renderSize.height) * 0.025
                        } else {
                            zoom = 1.0 + 0.01 * (elapsed - 0.5) / max(0.1, localDuration - 1.0)
                        }
                    case .popBounce:
                        if elapsed < 0.35 {
                            let t = elapsed / 0.35
                            alpha = min(1.0, t * 2.5)
                            let s = 1.70158
                            let postT = t - 1.0
                            zoom = 0.3 + 0.7 * (postT * postT * ((s + 1.0) * postT + s) + 1.0)
                        } else if remaining < 0.3 {
                            let p = (0.3 - remaining) / 0.3
                            alpha = max(0, 1.0 - p)
                            zoom = 1.0 - 0.15 * p
                        } else {
                            zoom = 1.0
                        }
                    case .slideIn:
                        if elapsed < 0.4 {
                            let t = elapsed / 0.4
                            let easeOut = 1.0 - pow(1.0 - t, 3)
                            alpha = easeOut
                            offsetY = (1.0 - easeOut) * Double(renderSize.height) * 0.10
                        } else if remaining < 0.3 {
                            let p = (0.3 - remaining) / 0.3
                            alpha = max(0, 1.0 - p)
                            offsetY = -p * Double(renderSize.height) * 0.05
                        } else {
                            offsetY = 0.0
                        }
                    case .beatPulse:
                        if elapsed < 0.3 {
                            alpha = elapsed / 0.3
                        } else if remaining < 0.3 {
                            alpha = max(0, remaining / 0.3)
                        }
                        let bpm = max(30.0, session.targetBPM)
                        let beatDuration = 60.0 / bpm
                        let beatPhase = elapsed.truncatingRemainder(dividingBy: beatDuration) / beatDuration
                        let pulse = beatPhase < 0.25 ? (1.0 - beatPhase / 0.25) : 0.0
                        zoom = 1.0 + 0.08 * pulse
                    }

                    let anchorX: CGFloat
                    switch settings.alignment {
                    case 0: anchorX = title.extent.minX
                    case 2: anchorX = title.extent.maxX
                    default: anchorX = title.extent.midX
                    }
                    let targetX = renderSize.width * CGFloat(settings.positionX)
                    let targetCenterY = renderSize.height * (1.0 - CGFloat(settings.positionY)) + CGFloat(offsetY)

                    let overlay = title.transformed(by: CGAffineTransform(translationX: -anchorX, y: -title.extent.midY))
                        .transformed(by: CGAffineTransform(scaleX: CGFloat(zoom), y: CGFloat(zoom)))
                        .transformed(by: CGAffineTransform(translationX: targetX, y: targetCenterY))
                        .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))])
                    image = overlay.composited(over: image)
                }
            }
            if span.kind != .content {
                let progress = min(1, max(0, (outputTime - span.start) / max(0.000_001, span.duration)))
                let brightness = span.kind == .fadeIn ? progress : 1 - progress
                image = image.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: brightness, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: brightness, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: brightness, w: 0)])
            }
            var videoOpacity = 1.0
            for effect in session.videoEffects where outputTime >= effect.startTime && outputTime <= effect.endTime {
                let progress = min(1, max(0, (outputTime - effect.startTime) / max(0.1, effect.duration)))
                videoOpacity *= effect.kind == .fadeIn ? progress : 1 - progress
            }
            if videoOpacity < 0.999_999 {
                image = image.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: videoOpacity, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: videoOpacity, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: videoOpacity, w: 0)
                ])
            }
            image = image.composited(over: CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: renderSize)))
            return image.cropped(to: CGRect(origin: .zero, size: renderSize))
        }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = EditorVideoCompositor.self
        let orientation = cgOrientation(from: sourceVideo.preferredTransform)
        videoComposition.instructions = [EditorVideoInstruction(duration: map.duration, trackID: video.trackID, orientation: orientation, process: process)]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = frameDuration(
            nominalFrameRate: sourceVideo.nominalFrameRate,
            minFrameDuration: sourceVideo.minFrameDuration
        )
        return EditorRender(composition: composition, videoComposition: videoComposition, audioMix: mix, map: map)
    }
    static func cgOrientation(from t: CGAffineTransform) -> CGImagePropertyOrientation {
        let det = t.a * t.d - t.b * t.c
        let angle = atan2(t.b, t.a)
        let degrees = (Int(round(angle * 180.0 / .pi)) % 360 + 360) % 360
        if det < 0 {
            switch degrees {
            case 90: return .leftMirrored
            case 180: return .downMirrored
            case 270: return .rightMirrored
            default: return .upMirrored
            }
        } else {
            switch degrees {
            case 90: return .right
            case 180: return .down
            case 270: return .left
            default: return .up
            }
        }
    }
}
