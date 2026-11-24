import Foundation

/// Pure-math phase solver shared across Text and Sticker continuous `Intro -> Loop -> Outro` animations.
/// Enforces an exact integer number of complete loop cycles (`N × T_unit`) and divides remaining clip duration evenly (`In = Out = R / 2`).
public enum AnimationPhaseTimingCalculator: Sendable {
    public static func calculate(
        clipDuration: Double,
        baseCycleSeconds: Double,
        speed: Double,
        preferredMinEdge: Double,
        isBeatSyncEnabled: Bool,
        beatBPM: Double,
        beatBarMode: AnimationBeatBarMode
    ) -> ResolvedAnimationPhases {
        let total = max(0.1, clipDuration)
        let safeSpeed = max(0.25, min(4.0, speed))
        let rawMinEdge = max(0.12, preferredMinEdge / safeSpeed)
        let minEdge = min(rawMinEdge, total * 0.25)
        let loopBudget = max(0.0, total - 2.0 * minEdge)

        let (unitDuration, beatsPerCycle) = resolveUnitDuration(
            total: total,
            loopBudget: loopBudget,
            baseCycleSeconds: baseCycleSeconds,
            speed: safeSpeed,
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: beatBPM,
            beatBarMode: beatBarMode
        )

        let cycles: Int
        let loopDuration: Double
        if loopBudget + 1e-6 >= unitDuration {
            cycles = max(1, Int(floor((loopBudget + 1e-6) / unitDuration)))
            loopDuration = min(total, Double(cycles) * unitDuration)
        } else {
            cycles = 0
            loopDuration = 0.0
        }

        let remainder = max(0.0, total - loopDuration)
        let half = remainder * 0.5
        return ResolvedAnimationPhases(
            inDuration: half,
            loopDuration: loopDuration,
            outDuration: half,
            totalDuration: total,
            cycleCount: cycles,
            cycleDuration: unitDuration,
            beatsPerCycle: beatsPerCycle
        )
    }

    private static func resolveUnitDuration(
        total: Double,
        loopBudget: Double,
        baseCycleSeconds: Double,
        speed: Double,
        isBeatSyncEnabled: Bool,
        beatBPM: Double,
        beatBarMode: AnimationBeatBarMode
    ) -> (unitDuration: Double, beatsPerCycle: Int?) {
        guard isBeatSyncEnabled else {
            return (max(0.15, baseCycleSeconds / speed), nil)
        }
        let beatSec = 60.0 / max(40.0, min(240.0, beatBPM))
        let targetBeats = selectBeatMultiplier(
            total: total,
            loopBudget: loopBudget,
            beatSec: beatSec,
            mode: beatBarMode
        )
        return (Double(targetBeats) * beatSec, targetBeats)
    }

    private static func selectBeatMultiplier(
        total: Double,
        loopBudget: Double,
        beatSec: Double,
        mode: AnimationBeatBarMode
    ) -> Int {
        switch mode {
        case .oneBeat:
            return 1
        case .twoBeats:
            return loopBudget + 1e-6 >= 2.0 * beatSec ? 2 : 1
        case .oneBar:
            if loopBudget + 1e-6 >= 4.0 * beatSec { return 4 }
            return loopBudget + 1e-6 >= 2.0 * beatSec ? 2 : 1
        case .twoBars:
            for candidate in [8, 4, 2, 1] where loopBudget + 1e-6 >= Double(candidate) * beatSec {
                return candidate
            }
            return 1
        case .auto:
            let eightDur = 8.0 * beatSec
            if loopBudget + 1e-6 >= eightDur, total >= 6.0 {
                let n8 = floor((loopBudget + 1e-6) / eightDur)
                let halfRemainder8 = (total - n8 * eightDur) * 0.5
                if halfRemainder8 <= max(1.15, beatSec * 2.2) { return 8 }
            }
            for candidate in [4, 2, 1] where loopBudget + 1e-6 >= Double(candidate) * beatSec {
                return candidate
            }
            return 1
        }
    }
}
