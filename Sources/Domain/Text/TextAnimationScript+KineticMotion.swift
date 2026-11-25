import Foundation

// MARK: - Phase 1 Pure-Motion Liquid Wave Extension

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
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 2.8)
            let rem = 1.0 - ease
            return TextUnitDelta(
                scaleX: 1.0 + rem * 0.14,
                scaleY: 1.0 - rem * 0.14,
                opacity: min(1.0, p * 2.6),
                blurRadius: rem * (0.14 * em),
                liquidWavePhase: p * .pi * 2.0,
                liquidMorphIntensity: 0.85 + rem * 0.45
            )
        case .loop(_, let cycleProgress):
            let drift = sin(cycleProgress * .pi * 2.0) * (0.05 * em)
            return TextUnitDelta(
                offsetY: drift,
                opacity: 1.0,
                liquidWavePhase: cycleProgress * .pi * 2.0,
                liquidMorphIntensity: 0.85
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.16,
                scaleY: 1.0 - ease * 0.16,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.16 * em),
                liquidWavePhase: p * .pi * 2.0,
                liquidMorphIntensity: 0.85 + ease * 0.55
            )
        }
    }
}
