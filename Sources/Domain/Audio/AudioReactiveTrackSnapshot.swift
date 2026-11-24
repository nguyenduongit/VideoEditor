import Foundation

/// Immutable snapshot of an active audio/video clip passed into video compositor instructions for 60fps reactivity.
public struct AudioReactiveTrackSnapshot: Sendable, Equatable {
    public let clipName: String
    public let timelineStart: Double
    public let timelineDuration: Double
    public let sourceStart: Double
    public let speed: Double
    public let volume: Double
    public let beatTimesSeconds: [Double]
    public let detectedBPM: Double?
    public let profile: AudioReactiveProfile?

    public var timelineEnd: Double { timelineStart + timelineDuration }

    public init(
        clipName: String,
        timelineStart: Double,
        timelineDuration: Double,
        sourceStart: Double,
        speed: Double = 1.0,
        volume: Double = 1.0,
        beatTimesSeconds: [Double] = [],
        detectedBPM: Double? = nil,
        profile: AudioReactiveProfile? = nil
    ) {
        self.clipName = clipName
        self.timelineStart = timelineStart
        self.timelineDuration = max(0.0, timelineDuration)
        self.sourceStart = max(0.0, sourceStart)
        self.speed = max(0.1, speed)
        self.volume = max(0.0, min(2.0, volume))
        self.beatTimesSeconds = beatTimesSeconds
        self.detectedBPM = detectedBPM
        self.profile = profile
    }
}
