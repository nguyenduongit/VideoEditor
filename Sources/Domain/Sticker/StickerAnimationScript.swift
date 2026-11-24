import Foundation

/// Protocol for Dev-Only continuous Script-Driven Sticker Animations (`Intro → Loop → Outro`).
/// Isolated strictly within `Domain/Sticker/`, completely decoupled from `TextAnimationScript`.
public protocol StickerAnimationScript: Sendable, Identifiable {
    var id: String { get }
    var name: String { get }
    var category: StickerAnimationCategory { get }
    var description: String { get }
    var previewSymbolName: String { get }
    var defaultInDuration: Double { get }
    var defaultLoopDuration: Double { get }
    var defaultOutDuration: Double { get }
    var baseCycleSeconds: Double { get }

    func evaluatePhase(
        _ phase: StickerScriptPhase,
        speed: Double,
        isBeatSyncEnabled: Bool,
        beatBPM: Double
    ) -> StickerAnimationDelta
}

extension StickerAnimationScript {
    public var defaultInDuration: Double { 0.6 }
    public var defaultLoopDuration: Double { 3.0 }
    public var defaultOutDuration: Double { 0.6 }
    public var defaultTotalDuration: Double { defaultInDuration + defaultLoopDuration + defaultOutDuration }
    public var baseCycleSeconds: Double { 1.0 }

    /// Evaluates continuous timeline state across Intro, seamless integer-cycle Loop, and Outro phases.
    public func evaluate(
        localTime: Double,
        clipDuration: Double,
        speed: Double,
        isBeatSyncEnabled: Bool,
        beatBPM: Double,
        beatBarMode: AnimationBeatBarMode = .auto
    ) -> StickerAnimationDelta {
        let phase = Self.resolvePhase(
            localTime: localTime,
            clipDuration: clipDuration,
            baseCycleSeconds: baseCycleSeconds,
            speed: speed,
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: beatBPM,
            beatBarMode: beatBarMode
        )
        return evaluatePhase(
            phase,
            speed: max(0.25, min(4.0, speed)),
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: max(40.0, min(240.0, beatBPM))
        )
    }

    /// Resolves timeline time using `AnimationPhaseTimingCalculator` (`N × T_unit` Loop, symmetric `In = Out = R / 2`).
    public static func resolvePhase(
        localTime: Double,
        clipDuration: Double,
        baseCycleSeconds: Double = 1.0,
        speed: Double = 1.0,
        isBeatSyncEnabled: Bool = false,
        beatBPM: Double = 120.0,
        beatBarMode: AnimationBeatBarMode = .auto
    ) -> StickerScriptPhase {
        let phases = AnimationPhaseTimingCalculator.calculate(
            clipDuration: clipDuration,
            baseCycleSeconds: baseCycleSeconds,
            speed: speed,
            preferredMinEdge: 0.4,
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: beatBPM,
            beatBarMode: beatBarMode
        )
        let t = max(0.0, min(phases.totalDuration, localTime))
        if phases.inDuration > 0.0001 && t < phases.inDuration {
            return .intro(progress: t / phases.inDuration)
        }
        let loopEnd = phases.inDuration + phases.loopDuration
        if phases.cycleCount > 0 && phases.loopDuration > 0.0001 && t < loopEnd {
            let elapsed = max(0.0, t - phases.inDuration)
            return .loop(elapsed: elapsed, loopDuration: phases.loopDuration, cycles: phases.cycleCount)
        }
        let denom = max(0.0001, phases.outDuration)
        return .outro(progress: StickerAnimationCurves.clamp01((t - loopEnd) / denom))
    }

    /// Computes exact integer cycle phase angle `[0, 2π * cycles]` so Loop joins Intro/Outro seamlessly without phase jumps.
    public static func loopGeometry(
        elapsed: Double,
        loopDuration: Double,
        baseCyclesPerSecond: Double,
        speed: Double,
        isBeatSyncEnabled: Bool,
        beatBPM: Double,
        resolvedCycles: Int = 0
    ) -> (unitProgress: Double, cycles: Double, angle: Double) {
        let span = max(0.0001, loopDuration)
        let u = StickerAnimationCurves.clamp01(elapsed / span)
        let cycles: Double
        if resolvedCycles > 0 {
            cycles = Double(resolvedCycles)
        } else {
            let rawCycles: Double = if isBeatSyncEnabled {
                span * (max(40.0, min(240.0, beatBPM)) / 60.0)
            } else {
                span * max(0.25, speed) * baseCyclesPerSecond
            }
            cycles = max(1.0, rawCycles.rounded())
        }
        let angle = 2.0 * .pi * cycles * u
        return (u, cycles, angle)
    }
}
