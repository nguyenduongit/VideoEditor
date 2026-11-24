import Foundation

/// Whole-block directional Slide text animation (`Intro -> stationary Loop -> Outro`)
/// with smooth quartic deceleration/acceleration and subtle velocity-matched directional Motion Blur.
public struct DirectionalSlideScript: TextAnimationScript {
    public let id: String
    public let displayName: String
    public let description: String
    public let category: TextAnimationCategory = .slide
    public let tags: [TextAnimationTag] = [.slide]
    public let loopCycleDuration: Double = 1.0
    public let scope: TextAnimationScope = .wholeBlock

    public let inDirection: TextSlideDirection
    public let outDirection: TextSlideDirection

    public init(inDirection: TextSlideDirection, outDirection: TextSlideDirection) {
        self.inDirection = inDirection
        self.outDirection = outDirection
        self.id = "slide_\(inDirection.rawValue)_\(outDirection.rawValue)"
        self.displayName = "Slide \(inDirection.title) → \(outDirection.title)"
        self.description = "Slides smoothly \(inDirection.entryDescriptionPhrase) into sharp focus, holds still, then exits \(outDirection.exitDescriptionPhrase)"
    }

    /// Curated 8-direction Slide matrix replacing legacy Slide variants in the Animation browser.
    public static let allEightVariants: [DirectionalSlideScript] = [
        DirectionalSlideScript(inDirection: .up, outDirection: .up),
        DirectionalSlideScript(inDirection: .down, outDirection: .down),
        DirectionalSlideScript(inDirection: .up, outDirection: .down),
        DirectionalSlideScript(inDirection: .down, outDirection: .up),
        DirectionalSlideScript(inDirection: .left, outDirection: .left),
        DirectionalSlideScript(inDirection: .left, outDirection: .right),
        DirectionalSlideScript(inDirection: .right, outDirection: .left),
        DirectionalSlideScript(inDirection: .right, outDirection: .right)
    ]

    public func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let peakBlur = min(18.0, 0.20 * em)
        let total = max(1, unitTotal)
        let staggerSpan = total > 1 ? 0.34 : 0.0
        let startP = total > 1 ? (Double(unitIndex) / Double(total)) * staggerSpan : 0.0

        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, startP: startP, peakBlur: peakBlur)
        case .loop:
            return TextUnitDelta(opacity: 1.0)
        case .outro(let progress):
            return evaluateOutro(progress: progress, startP: startP, peakBlur: peakBlur)
        }
    }

    private func evaluateIntro(progress: Double, startP: Double, peakBlur: Double) -> TextUnitDelta {
        let entry = inDirection.entryCanvasOffsetRatio
        guard progress > startP else {
            return TextUnitDelta(
                canvasOffsetXRatio: entry.x,
                canvasOffsetYRatio: entry.y,
                opacity: 0.0,
                motionBlurRadius: peakBlur,
                motionBlurAngle: inDirection.motionBlurAngle
            )
        }
        let localP = min(1.0, max(0.0, (progress - startP) / max(0.001, 1.0 - startP)))
        let rem = 1.0 - localP
        let remainingOffset = pow(rem, 4.0)
        let velocityBlur = pow(rem, 2.4) * peakBlur
        let opacity = localP >= 0.28 ? 1.0 : smoothstep01(localP / 0.28)
        return TextUnitDelta(
            canvasOffsetXRatio: entry.x * remainingOffset,
            canvasOffsetYRatio: entry.y * remainingOffset,
            opacity: opacity,
            motionBlurRadius: velocityBlur,
            motionBlurAngle: inDirection.motionBlurAngle
        )
    }

    private func evaluateOutro(progress: Double, startP: Double, peakBlur: Double) -> TextUnitDelta {
        let exit = outDirection.exitCanvasOffsetRatio
        guard progress > startP else {
            return TextUnitDelta(opacity: 1.0)
        }
        let localP = min(1.0, max(0.0, (progress - startP) / max(0.001, 1.0 - startP)))
        let ease = pow(localP, 2.8)
        let velocityBlur = pow(localP, 2.2) * peakBlur
        let fadeStart = 0.68
        let opacity: Double
        if localP <= fadeStart {
            opacity = 1.0
        } else {
            opacity = 1.0 - smoothstep01((localP - fadeStart) / (1.0 - fadeStart))
        }
        return TextUnitDelta(
            canvasOffsetXRatio: exit.x * ease,
            canvasOffsetYRatio: exit.y * ease,
            opacity: opacity,
            motionBlurRadius: velocityBlur,
            motionBlurAngle: outDirection.motionBlurAngle
        )
    }

    private func smoothstep01(_ value: Double) -> Double {
        let t = min(1.0, max(0.0, value))
        return t * t * (3.0 - 2.0 * t)
    }
}
