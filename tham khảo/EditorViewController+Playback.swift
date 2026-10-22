import AppKit
import AVFoundation

extension EditorViewController {

    func setupPlaybackObserver() {
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.033, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handlePlaybackTimeUpdate(time.seconds)
            }
        }
    }

    func handlePlaybackTimeUpdate(_ currentTime: Double) {
        timeline.playhead = currentTime
        timeLabel.stringValue = "\(format(currentTime)) / \(format(render?.map.duration ?? 0))"
        playButton.setSymbolName(player.rate == 0 ? "play.fill" : "pause.fill")
        if group == 0 { updateLegGuideOverlay(at: currentTime) }
        if player.rate > 0 {
            let x = CGFloat(currentTime / max(1, render?.map.duration ?? 1)) * timeline.bounds.width
            if !timeline.visibleRect.contains(NSPoint(x: x, y: 10)) {
                timeline.scroll(NSPoint(x: max(0, x - scroll.contentSize.width / 3), y: 0))
            }
        }
    }

    func setTemporaryBypassColor(_ bypass: Bool) {
        guard session.video != nil, let item = player.currentItem else { return }
        if bypass {
            if let bypassVC = bypassVideoComposition {
                item.videoComposition = bypassVC
            } else {
                var bypassSession = session
                bypassSession.adjustments.enabled = false
                if let b = try? EditorCompositionService.build(bypassSession) {
                    bypassVideoComposition = b.videoComposition
                    item.videoComposition = b.videoComposition
                }
            }
        } else {
            item.videoComposition = render?.videoComposition
        }
    }

    func updateLegGuideOverlay(at outputTime: Double) {
        guard group == 0, session.video != nil, session.showLegGuides ?? false, let pose = session.pose else {
            playerView.updateLegGuides(
                hipYNorm: session.legHipY,
                ankleYNorm: session.legAnkleY,
                scaleFactor: session.legScale,
                visible: false
            )
            return
        }

        let result = cachedPoseResult ?? pose.result()
        let relativeSourceTime = render?.map.sourceTime(at: outputTime) ?? 0.0
        let absoluteSourceTime = session.videoStart + relativeSourceTime
        var guides = result.legGuides(at: EditorCompositionService.time(absoluteSourceTime))

        let originalSize = result.videoSize
        let outputSize = render?.videoComposition.renderSize ?? originalSize
        if originalSize.width > 0, originalSize.height > 0,
           outputSize.width > 0, outputSize.height > 0 {
            var sourceRect = CGRect(origin: .zero, size: originalSize)
            if session.cropEnabled {
                let cropRect = VideoCropService.shared.calculateDynamicCropRect(
                    for: EditorCompositionService.time(absoluteSourceTime),
                    proportion: result,
                    cropMode: session.cropMode,
                    zoom: session.cropZoom,
                    offsetY: session.cropOffsetY,
                    autoPan: session.cropAutoPan,
                    panX: session.cropPanX
                )
                if cropRect.width > 0, cropRect.height > 0 { sourceRect = cropRect }
            }
            let scale = max(outputSize.width / sourceRect.width, outputSize.height / sourceRect.height)
            let translationY = (outputSize.height - sourceRect.height * scale) / 2.0
            func outputNorm(_ sourceNorm: Double) -> Double {
                let sourceY = CGFloat(sourceNorm) * max(1.0, originalSize.height - 1.0)
                let outputY = (sourceY - sourceRect.minY) * scale + translationY
                return Double(max(0.0, min(outputSize.height - 1.0, outputY)) / max(1.0, outputSize.height - 1.0))
            }
            guides = (outputNorm(guides.hipYNorm), outputNorm(guides.ankleYNorm))
        }

        playerView.updateLegGuides(
            hipYNorm: guides.hipYNorm,
            ankleYNorm: guides.ankleYNorm,
            scaleFactor: session.legScale,
            visible: true
        )
    }

    @objc func playPause() {
        guard !busy && !renderPending && render != nil else { return }
        if player.rate > 0 {
            player.pause()
        } else {
            if player.currentTime().seconds >= (render?.map.duration ?? 0) - 0.05 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] done in
                    if done {
                        DispatchQueue.main.async { [weak self] in
                            self?.timeline.playhead = 0
                            self?.player.play()
                        }
                    }
                }
            } else {
                player.play()
            }
        }
    }

    func seek(_ time: Double) {
        guard !renderPending && !busy else { return }
        player.seek(to: EditorCompositionService.time(time), toleranceBefore: .zero, toleranceAfter: .zero)
        timeline.playhead = time
    }

    func format(_ time: Double) -> String {
        let t = time.isFinite ? max(0, time) : 0
        return String(format: "%02d:%05.2f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }
}
