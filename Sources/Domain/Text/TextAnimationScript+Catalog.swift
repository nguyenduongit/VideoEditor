import Foundation

// MARK: - Script 1: Laser Typewriter Cursor (Gõ nhịp đàn hồi kèm con trỏ | bám đuôi)
public struct TypewriterCursorScript: TextAnimationScript {
    public let id = "typewriter_cursor"
    public let displayName = "Typewriter"
    public let description = "Gõ từng ký tự đàn hồi mượt mà kèm thanh con trỏ | di chuyển bám sát đuôi chữ"
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
            let postBlink = isLastChar && sin((progress - typingSpan) * .pi * 14.0) >= 0.0
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
    public let description = "Chữ tung vọt lên vòm cung xoay nghiêng trên không rồi rơi nảy đàn hồi tuần tự"
    public let category = TextAnimationCategory.pop
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        case .loop(_, let cycleProgress):
            let phaseAngle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.55
            let wave = sin(phaseAngle)
            let hop = max(0.0, wave)
            return TextUnitDelta(
                offsetY: -hop * (0.18 * em),
                scaleX: 1.0 - hop * 0.06 + max(0.0, -wave) * 0.05,
                scaleY: 1.0 + hop * 0.08 - max(0.0, -wave) * 0.04,
                rotation: cos(phaseAngle) * 3.5,
                opacity: 1.0,
                glowIntensityDelta: hop * 20.0
            )
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        if unitIndex == 0 { return evaluateAnchorCharIntro(progress: progress, em: em) }
        let tailCount = max(1, unitTotal - 1)
        let tailIdx = Double(unitIndex - 1)
        let normTail = tailIdx / Double(max(1, tailCount - 1))
        let spawnTime = 0.05 + tailIdx * (0.20 / Double(tailCount))
        guard progress >= spawnTime else { return TextUnitDelta(opacity: 0.0) }

        let apexY = -(1.18 + sin(normTail * .pi) * 0.42 - normTail * 0.18) * em
        let apexX = (-0.24 + normTail * 0.36) * em
        let apexRot = -18.0 + normTail * 48.0
        let dropStart = 0.42 + tailIdx * (0.26 / Double(tailCount))

        if progress < dropStart {
            let tossP = min(1.0, (progress - spawnTime) / max(0.05, dropStart - spawnTime))
            let easeOut = 1.0 - pow(1.0 - tossP, 3.0)
            let curX = (-0.65 * em) + (apexX + 0.65 * em) * easeOut
            let curY = (0.75 * em) + (apexY - 0.75 * em) * sin(tossP * .pi * 0.5)
            let curRot = (1.0 - easeOut) * 58.0 + apexRot * easeOut
            let popScale = 0.50 + 0.55 * sin(min(1.0, tossP * 1.35) * .pi * 0.5)
            return TextUnitDelta(
                offsetX: curX, offsetY: curY, scaleX: popScale, scaleY: popScale,
                rotation: curRot, opacity: min(1.0, tossP * 4.5), glowIntensityDelta: 24.0
            )
        }
        let dropP = min(1.0, (progress - dropStart) / max(0.18, 0.98 - dropStart))
        return evaluateDropToBaseline(dropP: dropP, em: em, apexX: apexX, apexY: apexY, apexRot: apexRot)
    }

    private func evaluateAnchorCharIntro(progress: Double, em: Double) -> TextUnitDelta {
        let p = min(1.0, progress / 0.42)
        let decay = exp(-p * 4.5)
        let bounce = decay * cos(p * .pi * 3.0)
        let offsetY = (1.0 - min(1.0, p * 2.2)) * (0.85 * em) - sin(p * .pi) * (1.0 - p) * (0.65 * em) - bounce * (0.20 * em)
        let squash = decay * sin(p * .pi * 3.0) * 0.24
        return TextUnitDelta(
            offsetY: offsetY, scaleX: 1.0 + squash, scaleY: 1.0 - squash,
            opacity: min(1.0, p * 5.0), glowIntensityDelta: decay * 22.0
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
                rotation: apexRot * (1.0 - t), opacity: 1.0, glowIntensityDelta: 26.0
            )
        }
        let t = (dropP - 0.52) / 0.48
        let decay = exp(-t * 4.0)
        let squash = cos(t * .pi * 2.5) * decay * 0.26
        return TextUnitDelta(
            offsetY: -abs(sin(t * .pi * 2.0)) * decay * (0.36 * em),
            scaleX: 1.0 + squash, scaleY: 1.0 - squash, opacity: 1.0,
            glowIntensityDelta: decay * 20.0
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

// MARK: - Script 3: Silk Ribbon Wave (Dải lụa lượn sóng S-Curve liên tục chuẩn tỷ lệ Font)
public struct CurvedArcRollerScript: TextAnimationScript {
    public let id = "curved_arc_roller"
    public let displayName = "Silk Ribbon Wave"
    public let description = "Chữ uốn lượn mềm mại như dải lụa dọc theo đường sóng S-Curve với góc tiếp tuyến chuẩn xác"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let centerIdx = Double(max(1, unitTotal - 1)) * 0.5
        let charEmX = (Double(unitIndex) - centerIdx) * 0.62

        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.0)
            let travelEm = -(1.0 - ease) * 4.2
            return evaluateRibbonWave(charEmX: charEmX, travelEm: travelEm, wavePhase: 0.0, em: em, edgeFadeProgress: p, isIntro: true)

        case .loop(_, let cycleProgress):
            let wavePhase = cycleProgress * .pi * 2.0
            let gentleSwayEm = sin(wavePhase) * 0.22
            return evaluateRibbonWave(charEmX: charEmX, travelEm: gentleSwayEm, wavePhase: wavePhase, em: em, edgeFadeProgress: 1.0, isIntro: false)

        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.2)
            let travelEm = ease * 4.2
            return evaluateRibbonWave(charEmX: charEmX, travelEm: travelEm, wavePhase: 0.0, em: em, edgeFadeProgress: 1.0 - ease, isIntro: false)
        }
    }

    private func evaluateRibbonWave(
        charEmX: Double, travelEm: Double, wavePhase: Double, em: Double, edgeFadeProgress: Double, isIntro: Bool
    ) -> TextUnitDelta {
        let s = charEmX + travelEm
        let k = 0.82
        let theta = s * k - wavePhase
        let ampRatio = 0.48
        let offsetX = travelEm * em
        let offsetY = -ampRatio * em * sin(theta)
        let derivative = -ampRatio * k * cos(theta)
        let tangentDegrees = atan(derivative) * 180.0 / .pi

        let fadeAlpha = min(1.0, max(0.0, edgeFadeProgress * 1.6))
        let scale = 0.72 + 0.28 * min(1.0, edgeFadeProgress * 1.4)
        let blur = isIntro ? (1.0 - min(1.0, edgeFadeProgress * 1.5)) * (0.12 * em) : 0.0
        return TextUnitDelta(
            offsetX: offsetX, offsetY: offsetY, scaleX: scale, scaleY: scale,
            rotation: tangentDegrees, opacity: fadeAlpha,
            waveAmplitudeEm: ampRatio, waveFrequencyEm: k, wavePhaseRadians: -wavePhase,
            blurRadius: blur
        )
    }
}

// MARK: - Script 4: Elastic Spring Pop (Bung nở lò xo lệch pha & Nhảy sóng đôi)
public struct NeonCyberShiftScript: TextAnimationScript {
    public let id = "neon_cyber_shift"
    public let displayName = "Elastic Spring Pop"
    public let description = "Từng ký tự bung nở lò xo vượt ngưỡng kèm vẫy góc nghiêng và nhảy sóng nhịp đôi"
    public let category = TextAnimationCategory.kinetic
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.46 / Double(total))) / 0.54))
            guard p > 0.0 else { return TextUnitDelta(scaleX: 0.05, scaleY: 0.05, opacity: 0.0) }
            let decay = exp(-p * 4.2)
            let spring = 1.0 - decay * cos(p * .pi * 3.2)
            let overshoot = decay * sin(p * .pi * 3.2)
            let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
            return TextUnitDelta(
                offsetY: (1.0 - spring) * (0.65 * em),
                scaleX: max(0.08, spring + overshoot * 0.22),
                scaleY: max(0.08, spring - overshoot * 0.14),
                rotation: decay * cos(p * .pi * 2.5) * 26.0 * dir,
                opacity: min(1.0, p * 4.5),
                glowIntensityDelta: max(0.0, overshoot) * 30.0
            )
        case .loop(_, let cycleProgress):
            let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.58
            let pulse = max(0.0, sin(angle))
            let liftY = -pulse * (0.28 * em)
            let scaleX = 1.0 - pulse * 0.08
            let scaleY = 1.0 + pulse * 0.14
            return TextUnitDelta(
                offsetY: liftY, scaleX: scaleX, scaleY: scaleY,
                rotation: cos(angle) * pulse * 8.0, opacity: 1.0
            )
        case .outro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let pop = p < 0.28 ? (1.0 + sin((p / 0.28) * .pi) * 0.22) : max(0.05, 1.0 - pow((p - 0.28) / 0.72, 2.0))
            return TextUnitDelta(
                offsetY: p < 0.28 ? -sin((p / 0.28) * .pi) * (0.25 * em) : pow((p - 0.28) / 0.72, 2.0) * (0.65 * em),
                scaleX: pop, scaleY: pop, opacity: 1.0 - pow(p, 1.8)
            )
        }
    }
}
