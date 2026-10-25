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
        applyAudioMix(layers: layers, to: currentItem)
        lastPropertiesSignature = computePropertiesSignature(layers: layers)
        if wasPlaying {
            resumeIfActive()
        }
    }

    func applyAudioMix(layers: [TimelineLayer], to item: AVPlayerItem) {
        let audioMix = TimelineCompositionBuilder.buildAudioMix(for: layers, layerAudioTrackIDs: layerAudioTrackIDs)
        item.audioMix = audioMix

        let pitchPreserved = layers.flatMap(\.clips).allSatisfy { clip in
            clip.properties["pitchPreservation"]?.asBool ?? true
        }
        let targetAlgorithm: AVAudioTimePitchAlgorithm = pitchPreserved ? .timeDomain : .varispeed
        if item.audioTimePitchAlgorithm != targetAlgorithm {
            item.audioTimePitchAlgorithm = targetAlgorithm
        }
    }
}
