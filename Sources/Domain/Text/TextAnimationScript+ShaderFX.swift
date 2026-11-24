import Foundation

// MARK: - 3D & Light FX Scripts Powered by TextShaderFilterEngine

public struct ThreeDTumbleDropScript: TextAnimationScript {
    public let id = "three_d_tumble_drop"
    public let displayName = "3D Tumble Drop"
    public let description = "Text tumbles forward from a 3D perspective pitch into sharp upright alignment"
    public let category = TextAnimationCategory.threeD
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.2)
            let rem = 1.0 - ease
            return TextUnitDelta(
                offsetY: -rem * (0.65 * em),
                scaleX: 0.72 + 0.28 * ease,
                scaleY: 0.55 + 0.45 * ease,
                opacity: min(1.0, p * 3.0),
                blurRadius: rem * (0.14 * em),
                perspectiveX: rem * 0.78,
                perspectiveY: -rem * 0.28
            )
        case .loop(_, let cycleProgress):
            let sway = sin(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                scaleX: 1.0 + sway * 0.02,
                scaleY: 1.0 + sway * 0.02,
                opacity: 1.0,
                perspectiveX: sway * 0.14
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.3)
            return TextUnitDelta(
                offsetY: ease * (0.60 * em),
                scaleX: 1.0 - ease * 0.24,
                scaleY: 1.0 - ease * 0.40,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.14 * em),
                perspectiveX: -ease * 0.78,
                perspectiveY: ease * 0.28
            )
        }
    }
}

public struct SwingingDoor3DScript: TextAnimationScript {
    public let id = "three_d_swinging_door"
    public let displayName = "Swinging Door 3D"
    public let description = "Swings open horizontally in 3D perspective with smooth dimensional breathing"
    public let category = TextAnimationCategory.threeD
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let decay = exp(-p * 4.2) * (1.0 - p)
            let spring = 1.0 - decay * cos(p * .pi * 2.4)
            let rem = 1.0 - spring
            return TextUnitDelta(
                offsetX: -rem * (0.50 * em),
                scaleX: max(0.18, 0.25 + 0.75 * spring),
                skewY: rem * 12.0,
                opacity: min(1.0, p * 3.4),
                perspectiveY: rem * 0.82
            )
        case .loop(_, let cycleProgress):
            let tilt = sin(cycleProgress * .pi * 2.0)
            return TextUnitDelta(opacity: 1.0, perspectiveY: tilt * 0.16)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            return TextUnitDelta(
                offsetX: ease * (0.50 * em),
                scaleX: max(0.18, 1.0 - ease * 0.75),
                skewY: -ease * 12.0,
                opacity: 1.0 - ease,
                perspectiveY: -ease * 0.82
            )
        }
    }
}

public struct DepthPerspectiveZoomScript: TextAnimationScript {
    public let id = "three_d_depth_rush"
    public let displayName = "Depth Perspective"
    public let description = "Rushes out from deep background space into tilted 3D focal lock"
    public let category = TextAnimationCategory.threeD
    public let tags: [TextAnimationTag] = [.threeD, .pop]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.6)
            let rem = 1.0 - ease
            return TextUnitDelta(
                scaleX: 0.28 + 0.72 * ease,
                scaleY: 0.28 + 0.72 * ease,
                opacity: min(1.0, p * 3.0),
                trackingEmDelta: -rem * 0.12,
                blurRadius: rem * (0.20 * em),
                perspectiveX: -rem * 0.65,
                perspectiveY: rem * 0.45
            )
        case .loop(_, let cycleProgress):
            let wave = sin(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                scaleX: 1.0 + wave * 0.04,
                scaleY: 1.0 + wave * 0.04,
                opacity: 1.0,
                perspectiveX: wave * 0.12,
                perspectiveY: cos(cycleProgress * .pi * 2.0) * 0.10 - 0.10
            )
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.95,
                scaleY: 1.0 + ease * 0.95,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.24 * em),
                perspectiveX: ease * 0.65,
                perspectiveY: -ease * 0.45
            )
        }
    }
}

public struct MetallicLightSweepScript: TextAnimationScript {
    public let id = "fx_metallic_sweep"
    public let displayName = "Metallic Sweep"
    public let description = "Luxury reveal with a gleaming diagonal light shimmer sweeping across every cycle"
    public let category = TextAnimationCategory.lightFX
    public let tags: [TextAnimationTag] = [.lightFX, .fade]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 3.0)
            return TextUnitDelta(
                scaleX: 0.94 + 0.06 * ease,
                scaleY: 0.94 + 0.06 * ease,
                opacity: ease,
                trackingEmDelta: (1.0 - ease) * 0.14,
                glowIntensityDelta: (1.0 - ease) * 18.0,
                blurRadius: (1.0 - ease) * (0.10 * em),
                lightSweepPhase: ease
            )
        case .loop(_, let cycleProgress):
            let glow = sin(cycleProgress * .pi) * 18.0
            return TextUnitDelta(opacity: 1.0, glowIntensityDelta: glow, lightSweepPhase: cycleProgress)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.3)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.06,
                scaleY: 1.0 + ease * 0.06,
                opacity: 1.0 - ease,
                trackingEmDelta: ease * 0.14,
                blurRadius: ease * (0.12 * em),
                lightSweepPhase: 1.0 - ease
            )
        }
    }
}

public struct PixelizeDissolveScript: TextAnimationScript {
    public let id = "fx_pixel_dissolve"
    public let displayName = "8-Bit Pixelize"
    public let description = "Crystallizes from crisp retro mosaic pixel blocks into sharp lettering"
    public let category = TextAnimationCategory.lightFX
    public let tags: [TextAnimationTag] = [.lightFX, .fade]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let maxPixel = max(8.0, 0.28 * em)
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 2.6)
            let pxScale = 1.0 + (1.0 - ease) * maxPixel
            return TextUnitDelta(opacity: min(1.0, progress * 2.4), glowIntensityDelta: (1.0 - ease) * 16.0, pixelateScale: pxScale)
        case .loop(_, let cycleProgress):
            let pulse = (0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)) * 12.0
            return TextUnitDelta(opacity: 1.0, glowIntensityDelta: pulse, pixelateScale: 0.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.0)
            let pxScale = 1.0 + ease * maxPixel
            return TextUnitDelta(opacity: 1.0 - ease, glowIntensityDelta: ease * 16.0, pixelateScale: pxScale)
        }
    }
}

public struct NeonTubeIgnitionScript: TextAnimationScript {
    public let id = "fx_neon_ignition"
    public let displayName = "Neon Ignition"
    public let description = "Flickers twice like an igniting fluorescent sign before glowing continuously"
    public let category = TextAnimationCategory.lightFX
    public let tags: [TextAnimationTag] = [.lightFX, .pop]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let flicker: Double = if p < 0.18 { 0.15 }
                else if p < 0.30 { 0.85 }
                else if p < 0.44 { 0.22 }
                else if p < 0.58 { 0.95 }
                else { 1.0 }
            let surge = max(0.0, 1.0 - abs(p - 0.60) * 4.0) * 48.0
            return TextUnitDelta(
                scaleX: p > 0.5 ? 1.0 : 0.98,
                scaleY: p > 0.5 ? 1.0 : 0.98,
                opacity: flicker,
                glowIntensityDelta: flicker * 26.0 + surge,
                lightSweepPhase: p > 0.45 ? (p - 0.45) / 0.55 : -1.0
            )
        case .loop(_, let cycleProgress):
            let pulse = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
            return TextUnitDelta(opacity: 1.0, glowIntensityDelta: 26.0 + pulse * 30.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            let stutter = (progress > 0.08 && progress < 0.38 && Int(progress * 24.0).isMultiple(of: 2)) ? 0.35 : 1.0
            return TextUnitDelta(opacity: (1.0 - ease) * stutter, glowIntensityDelta: (1.0 - ease) * 26.0)
        }
    }
}

public struct ChromaticVaporScript: TextAnimationScript {
    public let id = "fx_chromatic_vapor"
    public let displayName = "Chromatic Vapor"
    public let description = "Per-word iridescent hue cycling with soft optical mist bloom"
    public let category = TextAnimationCategory.lightFX
    public let tags: [TextAnimationTag] = [.lightFX, .fade]
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let stagger = 0.35 / Double(total)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.65))
            let ease = 1.0 - pow(1.0 - p, 2.8)
            return TextUnitDelta(
                offsetY: (1.0 - ease) * (0.28 * em),
                opacity: min(1.0, p * 2.5),
                glowIntensityDelta: (1.0 - ease) * 20.0,
                blurRadius: (1.0 - ease) * (0.22 * em),
                hueAngle: (1.0 - ease) * 1.4
            )
        case .loop(_, let cycleProgress):
            let wave = sin(cycleProgress * .pi * 2.0)
            let phaseFactor = cos(Double(unitIndex) * 0.7)
            return TextUnitDelta(
                offsetY: -wave * phaseFactor * (0.06 * em),
                opacity: 1.0,
                glowIntensityDelta: 12.0 + abs(wave) * 14.0,
                hueAngle: wave * 0.95
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * stagger) / 0.65))
            let ease = pow(p, 2.2)
            return TextUnitDelta(
                offsetY: -ease * (0.28 * em),
                opacity: 1.0 - ease,
                glowIntensityDelta: (1.0 - ease) * 12.0,
                blurRadius: ease * (0.22 * em),
                hueAngle: -ease * 1.4
            )
        }
    }
}
