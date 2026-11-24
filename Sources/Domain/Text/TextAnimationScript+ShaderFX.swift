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
                rotationX: rem * 74.0,
                rotationY: -rem * 24.0,
                opacity: min(1.0, p * 3.0),
                blurRadius: rem * (0.14 * em),
                perspectiveX: rem * 0.35
            )
        case .loop(_, let cycleProgress):
            let sway = sin(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                scaleX: 1.0 + sway * 0.02,
                scaleY: 1.0 + sway * 0.02,
                rotationX: sway * 14.0,
                opacity: 1.0,
                perspectiveX: sway * 0.08
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.3)
            return TextUnitDelta(
                offsetY: ease * (0.60 * em),
                scaleX: 1.0 - ease * 0.24,
                scaleY: 1.0 - ease * 0.40,
                rotationX: -ease * 74.0,
                rotationY: ease * 24.0,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.14 * em),
                perspectiveX: -ease * 0.35
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

public struct PixelizeDissolveScript: TextAnimationScript {
    public let id = "fx_pixel_dissolve"
    public let displayName = "8-Bit Reveal"
    public let description = "Crystallizes cleanly from mosaic blocks into sharp lettering using your text color"
    public let category = TextAnimationCategory.fade
    public let tags: [TextAnimationTag] = [.fade]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let maxPixel = max(8.0, 0.28 * em)
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 2.6)
            let pxScale = 1.0 + (1.0 - ease) * maxPixel
            return TextUnitDelta(opacity: min(1.0, progress * 2.4), pixelateScale: pxScale)
        case .loop(_, _):
            return TextUnitDelta(opacity: 1.0, pixelateScale: 0.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.0)
            let pxScale = 1.0 + ease * maxPixel
            return TextUnitDelta(opacity: 1.0 - ease, pixelateScale: pxScale)
        }
    }
}
