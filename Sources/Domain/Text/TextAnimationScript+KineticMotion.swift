import Foundation

// MARK: - Phase 1 Kinetic Slide, Wave & Glitch Extensions

public struct WhipMotionSlideScript: TextAnimationScript {
    public let id = "slide_directional_whip"
    public let displayName = "Whip Motion Slide"
    public let description = "Full-canvas horizontal whip entry with directional CIMotionBlur and spring brake"
    public let category = TextAnimationCategory.slide
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.6)
            let rem = 1.0 - ease
            let brake = p > 0.4 ? exp(-(p - 0.4) * 6.5) * sin((p - 0.4) * .pi * 3.0) * (1.0 - p) * 12.0 : 0.0
            return TextUnitDelta(
                canvasOffsetXRatio: -0.95 * rem,
                skewX: rem * -22.0 + brake,
                opacity: min(1.0, p * 4.5),
                motionBlurRadius: rem * min(28.0, 0.34 * em),
                motionBlurAngle: 0.0
            )
        case .loop:
            return TextUnitDelta(opacity: 1.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.5)
            return TextUnitDelta(
                canvasOffsetXRatio: 0.95 * ease,
                skewX: ease * 22.0,
                opacity: 1.0 - ease,
                motionBlurRadius: ease * min(28.0, 0.34 * em),
                motionBlurAngle: 0.0
            )
        }
    }
}

public struct ZipperCrossSlideScript: TextAnimationScript {
    public let id = "slide_zipper_cross"
    public let displayName = "Zipper Cross Slide"
    public let description = "Alternating units zip in from opposite left and right edges to interlock at center"
    public let category = TextAnimationCategory.slide
    public let scope = TextAnimationScope.perLine

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let dir = unitIndex.isMultiple(of: 2) ? -1.0 : 1.0
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 3.2)
            let rem = 1.0 - ease
            return TextUnitDelta(
                canvasOffsetXRatio: dir * 0.95 * rem,
                skewX: dir * rem * -10.0,
                opacity: min(1.0, progress * 3.8),
                motionBlurRadius: rem * min(22.0, 0.24 * em),
                motionBlurAngle: 0.0
            )
        case .loop(_, let cycleProgress):
            let settle = sin(cycleProgress * .pi * 2.0) * (0.04 * em) * dir
            return TextUnitDelta(offsetX: settle, opacity: 1.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.4)
            return TextUnitDelta(
                canvasOffsetXRatio: -dir * 0.95 * ease,
                skewX: -dir * ease * 10.0,
                opacity: 1.0 - ease,
                motionBlurRadius: ease * min(22.0, 0.24 * em),
                motionBlurAngle: 0.0
            )
        }
    }
}

public struct FlagFlutterWaveScript: TextAnimationScript {
    public let id = "wave_flag_flutter"
    public let displayName = "Flag Flutter"
    public let description = "Anchor left glyphs steady while progressive wind ripples swell toward the right end"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let spanFrac = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.5
        let gain = 0.25 + spanFrac * 0.95
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let theta = prog * .pi * 2.0 - spanFrac * .pi * 2.2
            let s = sin(theta)
            let c = cos(theta)
            return TextUnitDelta(
                offsetY: -s * (0.24 * em) * gain,
                rotation: c * 8.0 * gain,
                skewX: c * 5.0 * gain,
                opacity: 1.0
            )
        }
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 2.8)
            let target = loopAt(progress)
            return TextUnitDelta(
                offsetY: target.offsetY * ease + (1.0 - ease) * (-0.15 * em) * gain,
                rotation: target.rotation * ease,
                skewX: target.skewX * ease,
                opacity: ease
            )
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            let baseLoop = loopAt(progress)
            let stay = 1.0 - ease
            return TextUnitDelta(
                offsetY: baseLoop.offsetY * stay - ease * (0.20 * em) * gain,
                rotation: baseLoop.rotation * stay,
                skewX: baseLoop.skewX * stay,
                opacity: stay
            )
        }
    }
}

public struct LiquidMeltRippleScript: TextAnimationScript {
    public let id = "wave_liquid_ripple"
    public let displayName = "Liquid Melt"
    public let description = "Smooth surface tension wave distortion preserving your Appearance colors"
    public let category = TextAnimationCategory.wave
    public let tags: [TextAnimationTag] = [.wave]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 2.8)
            let rem = 1.0 - ease
            return TextUnitDelta(
                scaleX: 1.0 + rem * 0.14,
                scaleY: 1.0 - rem * 0.14,
                opacity: min(1.0, progress * 2.6),
                blurRadius: rem * (0.14 * em),
                liquidWavePhase: progress * .pi,
                liquidMorphIntensity: 0.75 + rem * 0.55
            )
        case .loop(_, let cycleProgress):
            return TextUnitDelta(opacity: 1.0, liquidWavePhase: cycleProgress * .pi * 2.0, liquidMorphIntensity: 0.85)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.16,
                scaleY: 1.0 - ease * 0.16,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.16 * em),
                liquidWavePhase: progress * .pi,
                liquidMorphIntensity: 0.75 + ease * 0.65
            )
        }
    }
}
