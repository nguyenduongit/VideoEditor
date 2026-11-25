import Foundation

/// Per-unit evaluation snapshot passed to nodes in a `TextAnimationGraph`.
public struct TextAnimationGraphContext: Sendable, Equatable {
    public var phase: TextAnimationGraphPhase
    public var globalProgress: Double
    public var phaseProgress: Double
    public var loopProgress: Double
    public var elapsedSeconds: Double
    public var phaseDuration: Double
    public var unitIndex: Int
    public var unitCount: Int
    public var randomSeed: UInt64
    public var externalInputs: [String: Double]
    public var staggerDirectionOverride: TextStaggerDirection?
    public var isSeamlessLifecycle: Bool

    public init(
        phase: TextAnimationGraphPhase,
        globalProgress: Double,
        phaseProgress: Double,
        loopProgress: Double = 0.0,
        elapsedSeconds: Double = 0.0,
        phaseDuration: Double = 1.0,
        unitIndex: Int = 0,
        unitCount: Int = 1,
        randomSeed: UInt64 = 0,
        externalInputs: [String: Double] = [:],
        staggerDirectionOverride: TextStaggerDirection? = nil,
        isSeamlessLifecycle: Bool = false
    ) {
        self.phase = phase
        self.globalProgress = min(1.0, max(0.0, globalProgress))
        self.phaseProgress = min(1.0, max(0.0, phaseProgress))
        self.loopProgress = min(1.0, max(0.0, loopProgress))
        self.elapsedSeconds = max(0.0, elapsedSeconds)
        self.phaseDuration = max(0.0001, phaseDuration)
        let safeUnitCount = max(1, unitCount)
        self.unitCount = safeUnitCount
        self.unitIndex = min(safeUnitCount - 1, max(0, unitIndex))
        self.randomSeed = randomSeed
        self.externalInputs = externalInputs.filter { !$0.key.isEmpty && $0.value.isFinite }
        self.staggerDirectionOverride = staggerDirectionOverride
        self.isSeamlessLifecycle = isSeamlessLifecycle
    }

    func value(for source: TextAnimationTimeSource) -> Double {
        switch source {
        case .globalProgress: return globalProgress
        case .phaseProgress: return phaseProgress
        case .loopProgress: return loopProgress
        case .elapsedSeconds: return elapsedSeconds
        }
    }

    func applyingStagger(fraction: Double, direction: TextStaggerDirection) -> Self {
        guard fraction > 0.0, unitCount > 1 else { return self }
        let effectiveDirection = staggerDirectionOverride ?? direction
        let order = Self.staggerOrder(
            index: unitIndex,
            count: unitCount,
            direction: effectiveDirection,
            seed: randomSeed
        )
        let start = fraction * Double(order) / Double(unitCount - 1)
        let available = max(0.0001, 1.0 - fraction)

        var copy = self
        copy.globalProgress = min(1.0, max(0.0, (globalProgress - start) / available))
        copy.phaseProgress = min(1.0, max(0.0, (phaseProgress - start) / available))
        // Keep periodic waveforms continuous around [0, 1) across all phases without boundary stalls.
        let shifted = (loopProgress - start).truncatingRemainder(dividingBy: 1.0)
        copy.loopProgress = shifted < 0.0 ? shifted + 1.0 : shifted
        copy.elapsedSeconds = max(0.0, elapsedSeconds - phaseDuration * start)
        return copy
    }

    func unitStaggerProgress(fraction: Double, direction: TextStaggerDirection) -> Double {
        guard fraction > 0.0, unitCount > 1 else { return phaseProgress }
        let effectiveDirection = staggerDirectionOverride ?? direction
        let order = Self.staggerOrder(
            index: unitIndex,
            count: unitCount,
            direction: effectiveDirection,
            seed: randomSeed
        )
        let start = fraction * Double(order) / Double(unitCount - 1)
        let available = max(0.0001, 1.0 - fraction)
        return min(1.0, max(0.0, (phaseProgress - start) / available))
    }

    /// Zero-allocation O(1) deterministic rank computation for all stagger directions (O(N) scalar loop for random).
    static func staggerOrder(
        index: Int,
        count: Int,
        direction: TextStaggerDirection,
        seed: UInt64
    ) -> Int {
        guard count > 1 else { return 0 }
        let clampedIndex = min(count - 1, max(0, index))
        switch direction {
        case .forward:
            return clampedIndex
        case .backward:
            return count - clampedIndex - 1
        case .centerOut:
            let dist2 = abs(2 * clampedIndex - (count - 1))
            if dist2 == 0 { return 0 }
            let isRight = 2 * clampedIndex > (count - 1)
            return (dist2 - 1) + (isRight ? 1 : 0)
        case .edgesIn:
            let dist2 = abs(2 * clampedIndex - (count - 1))
            if dist2 == 0 { return count - 1 }
            let isRight = 2 * clampedIndex > (count - 1)
            return (count - 1 - dist2) + (isRight ? 1 : 0)
        case .random:
            let targetHash = stableRandom(clampedIndex, seed: seed)
            var rank = 0
            for other in 0..<count where other != clampedIndex {
                let candidate = stableRandom(other, seed: seed)
                if candidate < targetHash || (candidate == targetHash && other < clampedIndex) {
                    rank += 1
                }
            }
            return rank
        }
    }

    private static func stableRandom(_ index: Int, seed: UInt64) -> UInt64 {
        var value = seed ^ (UInt64(index) &* 0x9E3779B97F4A7C15)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
