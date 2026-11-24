import Foundation
import Domain

/// Converts active timeline `AudioReactiveTrackSnapshot` streams into normalized graph `externalInputs`.
public enum TextAudioReactiveInputsBuilder: Sendable {
    public static func inputs(
        atTimelineTime compTime: Double,
        config: TextConfiguration,
        audioTracks: [AudioReactiveTrackSnapshot]
    ) -> [String: Double] {
        guard config.animation.graph != nil || config.animation.isBeatSyncEnabled || !audioTracks.isEmpty else {
            return [:]
        }
        let sampled = AudioReactiveSampler.sample(
            atTimelineTime: compTime,
            tracks: audioTracks,
            bandCount: 16,
            sensitivity: 1.15,
            reactsToBeat: true,
            fallbackBPM: config.animation.beatBPM
        )
        return [
            TextAnimationChannel.audioRMS: sampled.overallLevel,
            TextAnimationChannel.audioBass: sampled.bassLevel,
            TextAnimationChannel.audioMid: sampled.midLevel,
            TextAnimationChannel.audioTreble: sampled.trebleLevel,
            TextAnimationChannel.audioBeat: sampled.beatImpulse,
            TextAnimationChannel.audioIsSynced: sampled.isSyncedToAudio ? 1.0 : 0.0
        ]
    }
}
