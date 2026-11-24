import Foundation

/// Resolved continuous `Intro -> Loop -> Outro` phase durations where `Loop` always spans an integer number
/// of complete cycles (or musical bars in Beat Sync) and any fractional clip remainder is split evenly between `In` and `Out`.
public struct ResolvedAnimationPhases: Sendable, Equatable {
    public let inDuration: Double
    public let loopDuration: Double
    public let outDuration: Double
    public let totalDuration: Double
    public let cycleCount: Int
    public let cycleDuration: Double
    public let beatsPerCycle: Int?

    public init(
        inDuration: Double,
        loopDuration: Double,
        outDuration: Double,
        totalDuration: Double,
        cycleCount: Int,
        cycleDuration: Double,
        beatsPerCycle: Int? = nil
    ) {
        self.inDuration = inDuration
        self.loopDuration = loopDuration
        self.outDuration = outDuration
        self.totalDuration = totalDuration
        self.cycleCount = cycleCount
        self.cycleDuration = cycleDuration
        self.beatsPerCycle = beatsPerCycle
    }

    /// Compact descriptor shown next to Loop duration in Inspector footer (e.g. `2×1 Bar`, `4×`).
    public var cycleLabel: String? {
        guard cycleCount > 0 else { return nil }
        guard let beats = beatsPerCycle else {
            return "\(cycleCount)×"
        }
        switch beats {
        case 8: return "\(cycleCount)×2 Bars"
        case 4: return "\(cycleCount)×1 Bar"
        case 2: return "\(cycleCount)×1/2 Bar"
        default: return "\(cycleCount)×1 Beat"
        }
    }
}
