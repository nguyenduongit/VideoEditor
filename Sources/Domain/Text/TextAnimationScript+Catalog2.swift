import Foundation

// MARK: - Script 8: 3D Domino Cascade Flip (Lật chữ hiệu ứng Domino 3D liên hoàn)
public struct ElasticFlip3DScript: TextAnimationScript {
    public let id = "elastic_flip_3d"
    public let displayName = "3D Domino Flip"
    public let description = "Characters cascade in true 3D Y-axis domino flips with elastic bounce settling"
    public let category = TextAnimationCategory.threeD
    public let tags: [TextAnimationTag] = [.threeD, .pop]
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.45 / Double(total))) / 0.55))
            let raw = evaluateIntroRaw(p: p, em: em)
            let blendT = min(1.0, max(0.0, (p - 0.45) / 0.55))
            let s = blendT * blendT * (3.0 - 2.0 * blendT)
            return TextUnitDelta.lerp(raw, loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), t: s)
        case .loop(_, let cycleProgress):
            return loopDelta(cycleProgress: cycleProgress, em: em, unitIndex: unitIndex)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            let raw = evaluateOutroRaw(p: p, em: em)
            let s = p * p * (3.0 - 2.0 * p)
            return TextUnitDelta.lerp(loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), raw, t: s)
        }
    }

    private func loopDelta(cycleProgress: Double, em: Double, unitIndex: Int) -> TextUnitDelta {
        let waveArg = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.48
        let wave = sin(waveArg), pulse = max(0.0, wave), settle = max(0.0, -wave)
        return TextUnitDelta(
            offsetY: -pulse * (0.18 * em) + settle * (0.04 * em),
            scaleX: 1.0 - pulse * 0.10 + settle * 0.03,
            scaleY: 1.0 + pulse * 0.08 - settle * 0.025,
            rotationY: cos(waveArg) * (6.0 + pulse * 20.0),
            opacity: 1.0
        )
    }

    private func evaluateIntroRaw(p: Double, em: Double) -> TextUnitDelta {
        if p <= 0.0 { return TextUnitDelta(scaleX: 0.75, rotationY: 96.0, opacity: 0.0) }
        let decay = exp(-p * 3.8)
        let angle = decay * cos(p * .pi * 2.5) * 96.0
        return TextUnitDelta(
            offsetY: -decay * sin(p * .pi * 2.0) * (0.36 * em),
            scaleX: 0.85 + 0.15 * min(1.0, p * 2.0),
            scaleY: 0.85 + 0.15 * min(1.0, p * 2.0),
            rotationY: angle,
            opacity: min(1.0, p * 4.5)
        )
    }

    private func evaluateOutroRaw(p: Double, em: Double) -> TextUnitDelta {
        let ease = p * p
        return TextUnitDelta(
            offsetY: ease * (0.40 * em),
            scaleX: max(0.25, 1.0 - ease * 0.45),
            scaleY: 1.0 - ease * 0.22,
            rotationY: -ease * 96.0,
            opacity: 1.0 - ease
        )
    }
}
