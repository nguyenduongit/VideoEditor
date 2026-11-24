import Foundation

/// Single-frame multi-band audio energy & beat transient snapshot consumed by Audiogram Stickers at 60fps.
public struct AudioReactiveFrame: Sendable, Equatable {
    public var bands: [Double]
    public var overallLevel: Double
    public var bassLevel: Double
    public var midLevel: Double
    public var trebleLevel: Double
    public var beatImpulse: Double
    public var isSyncedToAudio: Bool

    public init(
        bands: [Double] = Array(repeating: 0.2, count: 16),
        overallLevel: Double = 0.2,
        bassLevel: Double = 0.25,
        midLevel: Double = 0.2,
        trebleLevel: Double = 0.15,
        beatImpulse: Double = 0.0,
        isSyncedToAudio: Bool = false
    ) {
        self.bands = bands
        self.overallLevel = overallLevel
        self.bassLevel = bassLevel
        self.midLevel = midLevel
        self.trebleLevel = trebleLevel
        self.beatImpulse = beatImpulse
        self.isSyncedToAudio = isSyncedToAudio
    }
}
