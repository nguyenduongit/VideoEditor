import Foundation

// MARK: - Script 5: Ocean Breeze Wave (Sóng biển dập dềnh & Nghiêng tiếp tuyến liền mạch)
public struct LiquidWavePulseScript: TextAnimationScript {
    public let id = "liquid_wave_pulse"
    public let displayName = "Ocean Breeze Wave"
    public let description = "Sóng biển truyền qua từng chữ cái với góc nghiêng tiếp tuyến và độ đàn hồi mượt mà"
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
            let jelly = sin(targetTheta) * ease * 0.08
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
            let total = max(1, unitTotal)
            let stagger = 0.36 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.64))
            let ease = p * p
            let env = 1.0 - ease
            let theta = -charEmX * k + ease * .pi
            let waveY = -ampRatio * em * sin(theta) * env
            let exitDropY = ease * (0.85 * em)
            let derivative = ampRatio * k * cos(theta) * env
            return TextUnitDelta(
                offsetY: waveY + exitDropY,
                scaleX: 1.0 - ease * 0.22,
                scaleY: 1.0 + ease * 0.16,
                rotation: atan(derivative) * 180.0 / .pi,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.20 * em)
            )
        }
    }
}

// MARK: - Script 6: Cyber Matrix Glitch (Xô lệch lát cắt kỹ thuật số & Tách kênh RGB)
public struct GlitchRGBPopScript: TextAnimationScript {
    public let id = "glitch_rgb_pop"
    public let displayName = "Cyber Glitch"
    public let description = "Chữ giật bậc thang điện tử, xô lệch lát cắt ngang dọc và tách kênh màu RGB mạnh"
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
            let isGlitching = trigger > 0.72 || (cycleProgress > 0.82 && cycleProgress < 0.94)
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

// MARK: - Script 7: Cinematic Focus Rise (Từng từ vút cung tròn & Lấy nét quang học)
public struct SmoothWordGlideScript: TextAnimationScript {
    public let id = "smooth_word_glide"
    public let displayName = "Word Glide"
    public let description = "Từng từ trượt mượt lên vị trí trung tâm, bồng bềnh lơ lửng và trượt vút lên trên"
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
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.44 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.56))
            if p <= 0.0 {
                return TextUnitDelta(offsetX: -0.55 * em, offsetY: 0.85 * em, rotation: -18.0, opacity: 0.0, blurRadius: 0.28 * em)
            }
            let decay = exp(-p * 4.2)
            let spring = 1.0 - decay * cos(p * .pi * 2.4)
            return TextUnitDelta(
                offsetX: (1.0 - spring) * (-0.55 * em),
                offsetY: (1.0 - spring) * (0.85 * em),
                scaleX: 0.82 + 0.18 * spring,
                scaleY: 0.82 + 0.18 * spring,
                rotation: (1.0 - spring) * -18.0,
                skewX: (1.0 - spring) * -10.0,
                opacity: min(1.0, p * 3.2),
                blurRadius: max(0.0, (1.0 - p) * (0.26 * em))
            )

        case .loop(_, let cycleProgress):
            let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.75
            let floatY = -sin(angle) * (0.16 * em)
            let rot = cos(angle) * 3.2
            return TextUnitDelta(
                offsetY: floatY,
                rotation: rot,
                opacity: 1.0
            )

        case .outro(let progress):
            let total = max(1, unitTotal)
            let stagger = 0.35 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.65))
            let ease = p * p
            return TextUnitDelta(
                offsetX: ease * (0.50 * em),
                offsetY: -ease * (0.80 * em),
                scaleX: 1.0 - ease * 0.18,
                scaleY: 1.0 - ease * 0.18,
                rotation: ease * 15.0,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.26 * em)
            )
        }
    }
}

// MARK: - Script 8: 3D Domino Cascade Flip (Lật chữ hiệu ứng Domino 3D liên hoàn)
public struct ElasticFlip3DScript: TextAnimationScript {
    public let id = "elastic_flip_3d"
    public let displayName = "3D Domino Flip"
    public let description = "Từng chữ cái lật cánh 3D nối đuôi nhau như hiệu ứng Domino kèm độ nảy đàn hồi"
    public let category = TextAnimationCategory.cinematic
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
            let total = max(1, unitTotal)
            let stagger = 0.50 / Double(total)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.50))
            if p <= 0.0 { return TextUnitDelta(scaleX: 0.04, opacity: 0.0) }
            let decay = exp(-p * 3.8)
            let flipCos = 1.0 - decay * cos(p * .pi * 3.0)
            let scaleX = max(0.06, flipCos)
            let scaleY = 0.76 + 0.24 * min(1.0, p * 1.5) + decay * sin(p * .pi * 3.0) * 0.18
            let skewY = decay * cos(p * .pi * 3.0) * 24.0
            let offsetY = -decay * sin(p * .pi * 2.0) * (0.42 * em)
            return TextUnitDelta(
                offsetY: offsetY,
                scaleX: scaleX,
                scaleY: scaleY,
                skewY: skewY,
                opacity: min(1.0, p * 4.5),
                glowIntensityDelta: decay * 22.0
            )

        case .loop(_, let cycleProgress):
            let waveArg = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.48
            let pulse = max(0.0, sin(waveArg))
            let flipScaleX = 1.0 - pulse * 0.34
            let liftY = -pulse * (0.20 * em)
            let skewY = cos(waveArg) * pulse * 14.0
            return TextUnitDelta(
                offsetY: liftY,
                scaleX: flipScaleX,
                scaleY: 1.0 + pulse * 0.10,
                skewY: skewY,
                opacity: 1.0
            )

        case .outro(let progress):
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
}
