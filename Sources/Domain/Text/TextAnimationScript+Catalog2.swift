import Foundation

// MARK: - Script 5: Ocean Breeze Wave (Sóng biển dập dềnh & Nghiêng tiếp tuyến liền mạch)
public struct LiquidWavePulseScript: TextAnimationScript {
    public let id = "liquid_wave_pulse"
    public let displayName = "Ocean Breeze Wave"
    public let description = "Ocean wave ripples smoothly across letters with elastic tangent tilt"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let centerIdx = Double(max(1, unitTotal - 1)) * 0.5
        let charEmX = (Double(unitIndex) - centerIdx) * 0.62
        let k = 0.92
        let ampRatio = 0.40

        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.42 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.58))
            if p <= 0.0 { return TextUnitDelta(offsetY: 0.85 * em, opacity: 0.0, blurRadius: 0.22 * em) }
            let ease = 1.0 - pow(1.0 - p, 3.0)
            let phaseRad = (1.0 - ease) * .pi * 0.5
            let targetTheta = -charEmX * k + phaseRad
            let waveY = -ampRatio * em * sin(targetTheta) * ease
            let entryDropY = (1.0 - ease) * (0.85 * em)
            let derivative = ampRatio * k * cos(targetTheta) * ease
            let tangentRot = atan(derivative) * 180.0 / .pi
            let jelly = sin(targetTheta) * ease * 0.09
            return TextUnitDelta(
                offsetY: waveY + entryDropY,
                scaleX: 1.0 - jelly * 0.5,
                scaleY: 1.0 + jelly,
                rotation: tangentRot,
                opacity: min(1.0, p * 3.2),
                waveAmplitudeEm: ampRatio * ease,
                waveFrequencyEm: -k,
                wavePhaseRadians: phaseRad,
                blurRadius: (1.0 - ease) * (0.18 * em)
            )

        case .loop(_, let cycleProgress):
            let theta = cycleProgress * .pi * 2.0 - charEmX * k
            let wave = sin(theta)
            let offsetY = -ampRatio * em * wave
            let derivative = ampRatio * k * cos(theta)
            let tangentRot = atan(derivative) * 180.0 / .pi
            let jelly = wave * 0.09
            return TextUnitDelta(
                offsetY: offsetY,
                scaleX: 1.0 - jelly * 0.5,
                scaleY: 1.0 + jelly,
                rotation: tangentRot,
                opacity: 1.0,
                waveAmplitudeEm: ampRatio,
                waveFrequencyEm: -k,
                wavePhaseRadians: cycleProgress * .pi * 2.0
            )

        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(max(1, unitTotal)))) / 0.64))
            let ease = p * p, env = 1.0 - ease
            let theta = progress * .pi * 2.0 - charEmX * k, derivative = ampRatio * k * cos(theta) * env, jelly = sin(theta) * 0.09 * env
            return TextUnitDelta(
                offsetY: -ampRatio * em * sin(theta) * env + ease * (0.85 * em),
                scaleX: 1.0 - jelly * 0.5 - ease * 0.22, scaleY: 1.0 + jelly + ease * 0.16,
                rotation: atan(derivative) * 180.0 / .pi, opacity: env,
                waveAmplitudeEm: ampRatio * env, waveFrequencyEm: -k, wavePhaseRadians: progress * .pi * 2.0,
                blurRadius: ease * (0.20 * em)
            )
        }
    }
}

// MARK: - Script 7: Word Glide (Từng từ trượt mượt từ mép trái màn hình vào tâm, thoát ra mép phải)
public struct SmoothWordGlideScript: TextAnimationScript {
    public let id = "smooth_word_glide"
    public let displayName = "Word Glide"
    public let description = "Words slide cleanly from off-screen left, hover gently, and glide off-screen right"
    public let category = TextAnimationCategory.slide
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let loopAt: (Double) -> (y: Double, rot: Double) = { prog in
            let angle = prog * .pi * 2.0 - Double(unitIndex) * 0.75
            return (-sin(angle) * (0.10 * em), cos(angle) * 2.2)
        }
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.42 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.58))
            guard p > 0.0 else {
                return TextUnitDelta(offsetY: 0.28 * em, canvasOffsetXRatio: -0.95, rotation: -8.0, opacity: 0.0, blurRadius: 0.24 * em)
            }
            let ease = 1.0 - pow(1.0 - p, 3.4)
            let rem = 1.0 - ease
            let l = loopAt(progress)
            let blendLoop = max(0.0, (progress - 0.72) / 0.28)
            let sLoop = blendLoop * blendLoop * (3.0 - 2.0 * blendLoop)
            return TextUnitDelta(
                offsetY: rem * (0.28 * em) + sLoop * l.y,
                canvasOffsetXRatio: -0.95 * rem,
                scaleX: 0.90 + 0.10 * ease,
                scaleY: 0.90 + 0.10 * ease,
                rotation: rem * -8.0 + sLoop * l.rot,
                skewX: rem * -8.0,
                opacity: min(1.0, p * 3.5),
                blurRadius: max(0.0, rem * (0.22 * em))
            )

        case .loop(_, let cycleProgress):
            let l = loopAt(cycleProgress)
            return TextUnitDelta(offsetY: l.y, rotation: l.rot, opacity: 1.0)

        case .outro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.35 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.65))
            let ease = pow(p, 2.4)
            let stay = 1.0 - ease
            let l = loopAt(progress)
            return TextUnitDelta(
                offsetY: stay * l.y - ease * (0.24 * em),
                canvasOffsetXRatio: 0.95 * ease,
                scaleX: 1.0 - ease * 0.10,
                scaleY: 1.0 - ease * 0.10,
                rotation: stay * l.rot + ease * 8.0,
                skewX: ease * 8.0,
                opacity: stay,
                blurRadius: ease * (0.22 * em)
            )
        }
    }
}

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
        switch phase {
        case .intro(let progress):
            let raw = evaluateIntroRaw(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
            guard progress > 0.72 else { return raw }
            let t = (progress - 0.72) / 0.28
            let s = t * t * (3.0 - 2.0 * t)
            return TextUnitDelta.lerp(raw, loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), t: s)
        case .loop(_, let cycleProgress):
            return loopDelta(cycleProgress: cycleProgress, em: em, unitIndex: unitIndex)
        case .outro(let progress):
            let raw = evaluateOutroRaw(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
            return TextUnitDelta.lerp(loopDelta(cycleProgress: progress, em: em, unitIndex: unitIndex), raw, t: min(1.0, progress / 0.25))
        }
    }

    private func loopDelta(cycleProgress: Double, em: Double, unitIndex: Int) -> TextUnitDelta {
        let waveArg = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.48
        let pulse = max(0.0, sin(waveArg))
        return TextUnitDelta(
            offsetY: -pulse * (0.18 * em),
            scaleX: 1.0 - pulse * 0.10,
            scaleY: 1.0 + pulse * 0.08,
            rotationY: cos(waveArg) * pulse * 26.0,
            opacity: 1.0
        )
    }

    private func evaluateIntroRaw(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let stagger = 0.50 / Double(total)
        let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.50))
        if p <= 0.0 { return TextUnitDelta(scaleX: 0.75, rotationY: 96.0, opacity: 0.0) }
        let decay = exp(-p * 3.8)
        let angle = decay * cos(p * .pi * 2.5) * 96.0
        return TextUnitDelta(
            offsetY: -decay * sin(p * .pi * 2.0) * (0.36 * em),
            scaleX: 0.85 + 0.15 * min(1.0, p * 2.0),
            scaleY: 0.85 + 0.15 * min(1.0, p * 2.0),
            rotationY: angle,
            opacity: min(1.0, p * 4.5),
            glowIntensityDelta: decay * 22.0
        )
    }

    private func evaluateOutroRaw(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let stagger = 0.40 / Double(total)
        let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.60))
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
