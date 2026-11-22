import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain

extension TimelinePlaybackEngine {
    public func updateAudioMix(layers: [TimelineLayer], forceResume: Bool = false) {
        guard let currentItem = player.currentItem else { return }
        let wasPlaying = forceResume || isPlaybackActive || (player.rate != 0)
        if wasPlaying {
            isPlaybackActive = true
        }
        if updateLiveAudioTapControllersIfPossible(layers: layers) {
            lastPropertiesSignature = computePropertiesSignature(layers: layers)
            lastVisualAndAudioEnvelopeSignature = computeVisualAndAudioEnvelopeSignature(layers: layers)
            if wasPlaying {
                resumeIfActive()
            }
            return
        }
        applyAudioMix(layers: layers, to: currentItem)
        lastPropertiesSignature = computePropertiesSignature(layers: layers)
        lastVisualAndAudioEnvelopeSignature = computeVisualAndAudioEnvelopeSignature(layers: layers)
        if wasPlaying {
            resumeIfActive()
        }
    }

    func applyAudioMix(layers: [TimelineLayer], to item: AVPlayerItem) {
        let built = TimelineCompositionBuilder.buildAudioMixWithTapControllers(
            for: layers,
            layerAudioTrackIDs: layerAudioTrackIDs
        )
        self.activeAudioTapControllers = built.tapControllers
        item.audioMix = built.audioMix
        self.lastVisualAndAudioEnvelopeSignature = computeVisualAndAudioEnvelopeSignature(layers: layers)

        let pitchPreserved = layers.flatMap(\.clips).allSatisfy { clip in
            clip.properties["pitchPreservation"]?.asBool ?? true
        }
        let targetAlgorithm: AVAudioTimePitchAlgorithm = pitchPreserved ? .timeDomain : .varispeed
        if item.audioTimePitchAlgorithm != targetAlgorithm {
            item.audioTimePitchAlgorithm = targetAlgorithm
        }
    }

    /// Cập nhật trực tiếp hệ số âm lượng (`volume` & `isMuted`) vào `TimelineAudioGainTap` đang chạy
    /// mà KHÔNG gán lại `item.audioMix` hay `item.videoComposition`, giúp nhạc tiếp tục phát mượt tuyệt đối 100% không khựng.
    func updateLiveAudioTapControllersIfPossible(layers: [TimelineLayer]) -> Bool {
        guard !activeAudioTapControllers.isEmpty else { return false }
        let curTime = player.currentTime()
        let playheadSec: Double? = (curTime.isValid && curTime.isNumeric) ? CMTimeGetSeconds(curTime) : nil
        var updatedCount = 0

        for layer in layers {
            guard let trackIDs = layerAudioTrackIDs[layer.id], !trackIDs.isEmpty else { continue }
            let windows = (layer.kind == .video && trackIDs.count == 2)
                ? TimelineCompositionBuilder.transitionWindows(for: layer)
                : []
            if trackIDs.count == 2 && !windows.isEmpty {
                for (parity, trackID) in trackIDs.enumerated() {
                    guard let controller = activeAudioTapControllers[trackID] else { return false }
                    let parityClips = layer.clips
                        .sorted { $0.timeRange.start < $1.timeRange.start }
                        .enumerated()
                        .filter { $0.offset % 2 == parity }
                        .map(\.element)
                    controller.update(clips: parityClips, isLayerMuted: layer.isMuted, playheadSec: playheadSec)
                    updatedCount += 1
                }
            } else {
                for trackID in trackIDs {
                    guard let controller = activeAudioTapControllers[trackID] else { return false }
                    controller.update(clips: layer.clips, isLayerMuted: layer.isMuted, playheadSec: playheadSec)
                    updatedCount += 1
                }
            }
        }
        guard updatedCount > 0 else { return false }
        if let currentItem = player.currentItem {
            let pitchPreserved = layers.flatMap(\.clips).allSatisfy { clip in
                clip.properties["pitchPreservation"]?.asBool ?? true
            }
            let targetAlgorithm: AVAudioTimePitchAlgorithm = pitchPreserved ? .timeDomain : .varispeed
            if currentItem.audioTimePitchAlgorithm != targetAlgorithm {
                currentItem.audioTimePitchAlgorithm = targetAlgorithm
            }
        }
        return true
    }
}
