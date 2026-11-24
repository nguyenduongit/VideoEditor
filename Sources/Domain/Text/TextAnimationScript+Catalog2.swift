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

// MARK: - Script 6: Cyber Matrix Glitch (Xô lệch lát cắt kỹ thuật số & Tách kênh RGB)
public struct GlitchRGBPopScript: TextAnimationScript {
    public let id = "glitch_rgb_pop"
    public let displayName = "Cyber Glitch"
    public let description = "Stepped electronic stutter, sliced offsets, and bold RGB chromatic split"
    public let category = TextAnimationCategory.glitch
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let seed = Double((unitIndex * 37 + 13) % 19)
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.42 / Double(total)
            let rawP = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.58))
            if rawP <= 0.0 { return TextUnitDelta(opacity: 0.0) }
            let steppedP = floor(rawP * 10.0) / 10.0
            let jitterEnv = pow(1.0 - rawP, 1.5)
            let sliceSign = sin(steppedP * 28.0 + seed) >= 0.0 ? 1.0 : -1.0
            let offsetX = sliceSign * jitterEnv * (0.48 * em)
            let offsetY = cos(steppedP * 34.0 + seed) * jitterEnv * (0.24 * em)
            let skewX = sliceSign * jitterEnv * 24.0
            let blinkAlpha = (rawP < 0.55 && Int(rawP * 16.0 + seed).isMultiple(of: 3)) ? 0.25 : 1.0
            return TextUnitDelta(
                offsetX: offsetX,
                offsetY: offsetY,
                scaleX: 1.0 + jitterEnv * 0.24 * sliceSign,
                scaleY: 1.0 - jitterEnv * 0.16,
                skewX: skewX,
                opacity: blinkAlpha,
                glitchIntensity: jitterEnv * 85.0
            )

        case .loop(let time, let cycleProgress):
            let stepTime = floor(time * 14.0)
            let trigger = sin(stepTime * 1.7 + seed * 2.3)
            let isGlitching = (cycleProgress > 0.06 && cycleProgress < 0.94) && (trigger > 0.72 || cycleProgress > 0.82)
            guard isGlitching else { return TextUnitDelta(opacity: 1.0) }
            let dir = cos(stepTime * 3.1 + seed) >= 0.0 ? 1.0 : -1.0
            return TextUnitDelta(
                offsetX: dir * (0.18 * em),
                offsetY: -dir * (0.08 * em),
                skewX: dir * 18.0,
                opacity: 0.92,
                glitchIntensity: 58.0
            )

        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let stepP = floor(p * 8.0) / 8.0
            let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
            return TextUnitDelta(
                offsetX: stepP * (0.95 * em) * dir,
                scaleX: 1.0 + stepP * 0.45,
                scaleY: max(0.08, 1.0 - stepP * 0.85),
                skewX: dir * stepP * 28.0,
                opacity: 1.0 - p,
                glitchIntensity: p * 90.0
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
    public let description = "Characters cascade in 3D domino flips with elastic bounce settling"
    public let category = TextAnimationCategory.pop
    public let tags: [TextAnimationTag] = [.pop, .threeD]
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
            offsetY: -pulse * (0.20 * em),
            scaleX: 1.0 - pulse * 0.34,
            scaleY: 1.0 + pulse * 0.10,
            skewY: cos(waveArg) * pulse * 14.0,
            opacity: 1.0
        )
    }

    private func evaluateIntroRaw(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let stagger = 0.50 / Double(total)
        let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.50))
        if p <= 0.0 { return TextUnitDelta(scaleX: 0.04, opacity: 0.0) }
        let decay = exp(-p * 3.8)
        let flipCos = 1.0 - decay * cos(p * .pi * 3.0)
        return TextUnitDelta(
            offsetY: -decay * sin(p * .pi * 2.0) * (0.42 * em),
            scaleX: max(0.06, flipCos),
            scaleY: 0.76 + 0.24 * min(1.0, p * 1.5) + decay * sin(p * .pi * 3.0) * 0.18,
            skewY: decay * cos(p * .pi * 3.0) * 24.0,
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
            offsetY: ease * (0.45 * em),
            scaleX: max(0.04, 1.0 - ease * 0.96),
            scaleY: 1.0 - ease * 0.22,
            skewY: ease * -24.0,
            opacity: 1.0 - ease
        )
    }
}
