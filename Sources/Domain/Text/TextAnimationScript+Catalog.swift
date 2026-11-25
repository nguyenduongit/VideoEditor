import Foundation

// MARK: - Script 1: Laser Typewriter Cursor (Gõ nhịp đàn hồi kèm con trỏ | bám đuôi)
public struct TypewriterCursorScript: TextAnimationScript {
    public let id = "typewriter_cursor"
    public let displayName = "Typewriter"
    public let description = "Smooth elastic per-character typing accompanied by a tracking | cursor"
    public let category = TextAnimationCategory.typewriter
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        case .loop(_, let cycleProgress):
            let isLastChar = unitIndex == max(0, unitTotal - 1)
            let cursorAlpha = (isLastChar && sin(cycleProgress * .pi * 4.0) >= -0.1) ? 1.0 : 0.0
            return TextUnitDelta(opacity: 1.0, trailingCursorOpacity: cursorAlpha)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let typingSpan = 0.86
        let charFraction = typingSpan / Double(total)
        let charStart = Double(unitIndex) * charFraction
        let charEnd = charStart + charFraction

        if progress < charStart {
            let showLeadCursor = (unitIndex == 0 && progress > 0.01)
            return TextUnitDelta(opacity: 0.0, trailingCursorOpacity: showLeadCursor ? 1.0 : 0.0)
        } else if progress < charEnd {
            let localP = (progress - charStart) / max(0.001, charFraction)
            let ease = 1.0 - pow(1.0 - localP, 3.0)
            let springScale = 1.0 + sin(localP * .pi) * 0.16
            let slideY = (1.0 - ease) * (0.20 * em)
            return TextUnitDelta(
                offsetY: slideY,
                scaleX: springScale,
                scaleY: springScale,
                opacity: min(1.0, localP * 4.0),
                trailingCursorOpacity: 1.0,
                blurRadius: (1.0 - ease) * (0.06 * em)
            )
        } else {
            let isLastChar = unitIndex == total - 1
            let postBlink = isLastChar && cos((1.0 - progress) * .pi * 6.0) >= -0.1
            return TextUnitDelta(opacity: 1.0, trailingCursorOpacity: postBlink ? 1.0 : 0.0)
        }
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let charFraction = 1.0 / Double(total)
        let disappearStart = Double(total - 1 - unitIndex) * charFraction
        let disappearEnd = disappearStart + charFraction

        if progress >= disappearEnd {
            return TextUnitDelta(opacity: 0.0)
        } else if progress >= disappearStart {
            let localP = (progress - disappearStart) / max(0.001, charFraction)
            return TextUnitDelta(
                offsetY: localP * (0.14 * em),
                scaleX: 1.0 - localP * 0.22,
                scaleY: 1.0 - localP * 0.22,
                opacity: 1.0 - localP,
                trailingCursorOpacity: 1.0
            )
        }
        return TextUnitDelta(opacity: 1.0)
    }
}

// MARK: - Script 2: Slingshot Arc Bounce (Tung vòm cung & Rơi đàn hồi Squash-Stretch)
public struct KineticDropGlowScript: TextAnimationScript {
    public let id = "kinetic_drop_glow"
    public let displayName = "Kinetic Drop"
    public let description = "Characters arc skyward with air spin before bouncing down sequentially"
    public let category = TextAnimationCategory.pop
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let raw = evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
            let s = introLoopBlendFactor(progress: progress, unitIndex: unitIndex, unitTotal: unitTotal)
            guard s > 0.0 else { return raw }
            return blendKinetic(from: raw, to: loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), t: s)
        case .loop(_, let cycleProgress):
            return loopDelta(cycleProgress: cycleProgress, em: em, unitIndex: unitIndex)
        case .outro(let progress):
            let raw = evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
            let localP = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.35 / Double(max(1, unitTotal)))) / 0.65))
            let s = localP * localP * (3.0 - 2.0 * localP)
            return blendKinetic(from: loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), to: raw, t: s)
        }
    }

    private func introLoopBlendFactor(progress: Double, unitIndex: Int, unitTotal: Int) -> Double {
        let unitP: Double
        if unitIndex == 0 {
            unitP = min(1.0, max(0.0, progress / 0.58))
        } else {
            let tailCount = max(1, unitTotal - 1), tailIdx = Double(unitIndex - 1)
            let normTail = tailIdx / Double(max(1, tailCount - 1))
            let dropStart = 0.42 + tailIdx * (0.26 / Double(tailCount))
            let dropEnd = 0.72 + normTail * 0.28
            unitP = progress <= dropStart ? 0.0 : min(1.0, (progress - dropStart) / max(0.18, dropEnd - dropStart))
        }
        let t = min(1.0, max(0.0, (unitP - 0.52) / 0.48))
        return t * t * (3.0 - 2.0 * t)
    }

    private func loopDelta(cycleProgress: Double, em: Double, unitIndex: Int) -> TextUnitDelta {
        let phaseAngle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.55
        let wave = sin(phaseAngle), hop = max(0.0, wave)
        return TextUnitDelta(
            offsetY: -hop * (0.18 * em), scaleX: 1.0 - hop * 0.06 + max(0.0, -wave) * 0.05,
            scaleY: 1.0 + hop * 0.08 - max(0.0, -wave) * 0.04, rotation: cos(phaseAngle) * 3.5,
            opacity: 1.0
        )
    }

    private func blendKinetic(from a: TextUnitDelta, to b: TextUnitDelta, t: Double) -> TextUnitDelta {
        let k = max(0.0, min(1.0, t)), inv = 1.0 - k
        return TextUnitDelta(
            offsetX: inv * a.offsetX + k * b.offsetX, offsetY: inv * a.offsetY + k * b.offsetY,
            scaleX: inv * a.scaleX + k * b.scaleX, scaleY: inv * a.scaleY + k * b.scaleY,
            rotation: inv * a.rotation + k * b.rotation, opacity: inv * a.opacity + k * b.opacity
        )
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        if unitIndex == 0 { return evaluateAnchorCharIntro(progress: progress, em: em) }
        let tailCount = max(1, unitTotal - 1), tailIdx = Double(unitIndex - 1)
        let normTail = tailIdx / Double(max(1, tailCount - 1)), spawnTime = 0.05 + tailIdx * (0.20 / Double(tailCount))
        guard progress >= spawnTime else { return TextUnitDelta(opacity: 0.0) }
        let apexY = -(1.18 + sin(normTail * .pi) * 0.42 - normTail * 0.18) * em
        let apexX = (-0.24 + normTail * 0.36) * em, apexRot = -18.0 + normTail * 48.0
        let dropStart = 0.42 + tailIdx * (0.26 / Double(tailCount))
        if progress < dropStart {
            let tossP = min(1.0, (progress - spawnTime) / max(0.05, dropStart - spawnTime))
            let easeOut = 1.0 - pow(1.0 - tossP, 3.0), popScale = 0.50 + 0.55 * sin(min(1.0, tossP * 1.35) * .pi * 0.5)
            return TextUnitDelta(
                offsetX: (-0.65 * em) + (apexX + 0.65 * em) * easeOut, offsetY: (0.75 * em) + (apexY - 0.75 * em) * sin(tossP * .pi * 0.5),
                scaleX: popScale, scaleY: popScale, rotation: (1.0 - easeOut) * 58.0 + apexRot * easeOut,
                opacity: min(1.0, tossP * 4.5)
            )
        }
        return evaluateDropToBaseline(dropP: min(1.0, (progress - dropStart) / max(0.18, 0.98 - dropStart)), em: em, apexX: apexX, apexY: apexY, apexRot: apexRot)
    }

    private func evaluateAnchorCharIntro(progress: Double, em: Double) -> TextUnitDelta {
        let p = min(1.0, progress / 0.42)
        let decay = exp(-p * 4.5)
        let bounce = decay * cos(p * .pi * 3.0)
        let offsetY = (1.0 - min(1.0, p * 2.2)) * (0.85 * em) - sin(p * .pi) * (1.0 - p) * (0.65 * em) - bounce * (0.20 * em)
        let squash = decay * sin(p * .pi * 3.0) * 0.24
        return TextUnitDelta(
            offsetY: offsetY, scaleX: 1.0 + squash, scaleY: 1.0 - squash,
            opacity: min(1.0, p * 5.0)
        )
    }

    private func evaluateDropToBaseline(
        dropP: Double, em: Double, apexX: Double, apexY: Double, apexRot: Double
    ) -> TextUnitDelta {
        if dropP < 0.52 {
            let t = dropP / 0.52
            return TextUnitDelta(
                offsetX: apexX * (1.0 - t), offsetY: apexY * (1.0 - t * t),
                scaleX: 1.0 - 0.14 * sin(t * .pi), scaleY: 1.0 + 0.18 * sin(t * .pi),
                rotation: apexRot * (1.0 - t), opacity: 1.0
            )
        }
        let t = (dropP - 0.52) / 0.48
        let decay = exp(-t * 4.0)
        let squash = cos(t * .pi * 2.5) * decay * 0.26
        return TextUnitDelta(
            offsetY: -abs(sin(t * .pi * 2.0)) * decay * (0.36 * em),
            scaleX: 1.0 + squash, scaleY: 1.0 - squash, opacity: 1.0
        )
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let localP = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.35 / Double(total))) / 0.65))
        let offsetY = localP < 0.25
            ? -sin((localP / 0.25) * .pi * 0.5) * (0.42 * em)
            : (-0.42 * em) + pow((localP - 0.25) / 0.75, 2.2) * (2.2 * em)
        return TextUnitDelta(
            offsetY: offsetY, rotation: localP * 20.0, opacity: 1.0 - pow(localP, 1.6)
        )
    }
}
