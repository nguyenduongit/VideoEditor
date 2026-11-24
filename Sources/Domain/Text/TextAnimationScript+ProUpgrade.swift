import Foundation

// MARK: - Pro Script 2: Karaoke Pulse (Nhấn nảy từng từ theo nhịp, bảo toàn màu Appearance)
public struct KaraokeGlowFlowScript: TextAnimationScript {
    public let id = "karaoke_glow_flow"
    public let displayName = "Karaoke Pulse"
    public let description = "Rhythmic word-by-word motion pulse preserving your Appearance text color"
    public let category = TextAnimationCategory.typewriter
    public let tags: [TextAnimationTag] = [.typewriter, .pop]
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - min(1.0, max(0.0, progress)), 2.8)
            return TextUnitDelta(
                scaleX: 0.92 + 0.08 * ease,
                scaleY: 0.92 + 0.08 * ease,
                opacity: min(1.0, progress * 2.4),
                blurRadius: (1.0 - ease) * (0.10 * em)
            )
        case .loop:
            return TextUnitDelta(opacity: 1.0)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.08,
                scaleY: 1.0 + ease * 0.08,
                opacity: 1.0 - ease,
                blurRadius: ease * (0.14 * em)
            )
        }
    }
}

// MARK: - Pro Script 3: Line Cascade Slide (Từng dòng trượt từ mép dưới màn hình vào)
public struct LineCascadeRiseScript: TextAnimationScript {
    public let id = "line_cascade_rise"
    public let displayName = "Line Cascade"
    public let description = "Staggered line-by-line vertical slide from bottom screen edge to top"
    public let category = TextAnimationCategory.slide
    public let tags: [TextAnimationTag] = [.slide]
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perLine

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let floatAt: (Double) -> Double = { prog in
            -sin(prog * .pi * 2.0 - Double(unitIndex) * 0.55) * (0.04 * em)
        }
        switch phase {
        case .intro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.36
            guard progress > startP else { return TextUnitDelta(canvasOffsetYRatio: 0.85, opacity: 0.0) }
            let localP = min(1.0, (progress - startP) / (1.0 - startP))
            let ease = 1.0 - pow(1.0 - localP, 3.4)
            let blendLoop = max(0.0, (progress - 0.72) / 0.28)
            let sLoop = blendLoop * blendLoop * (3.0 - 2.0 * blendLoop)
            return TextUnitDelta(
                offsetY: sLoop * floatAt(progress),
                canvasOffsetYRatio: 0.85 * (1.0 - ease),
                opacity: min(1.0, localP * 4.0),
                blurRadius: (1.0 - ease) * (0.14 * em)
            )
        case .loop(_, let cycleProgress):
            return TextUnitDelta(offsetY: floatAt(cycleProgress), opacity: 1.0)
        case .outro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.36
            let localP = progress <= startP ? 0.0 : min(1.0, (progress - startP) / (1.0 - startP))
            let ease = pow(localP, 2.3)
            let stay = 1.0 - ease
            return TextUnitDelta(
                offsetY: stay * floatAt(progress),
                canvasOffsetYRatio: -0.85 * ease,
                opacity: stay,
                blurRadius: ease * (0.14 * em)
            )
        }
    }
}

// MARK: - Pro Script 4: Blur Focus Dissolve (Lấy nét quang học từng ký tự)
public struct BlurFocusDissolveScript: TextAnimationScript {
    public let id = "blur_focus_dissolve"
    public let displayName = "Optical Focus"
    public let description = "Per-character optical lens defocus pull-in with silky tracking expand and bokeh exit"
    public let category = TextAnimationCategory.fade
    public let tags: [TextAnimationTag] = [.fade]
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let normIdx = total > 1 ? Double(unitIndex) / Double(total - 1) : 0.0
        switch phase {
        case .intro(let progress):
            let startP = normIdx * 0.38
            guard progress > startP else { return TextUnitDelta(scaleX: 1.18, scaleY: 1.18, opacity: 0.0, trackingEmDelta: 0.22, blurRadius: 0.34 * em) }
            let localP = min(1.0, (progress - startP) / (1.0 - startP))
            let ease = 1.0 - pow(1.0 - localP, 3.2)
            let rem = 1.0 - ease
            return TextUnitDelta(
                scaleX: 1.0 + rem * 0.18,
                scaleY: 1.0 + rem * 0.18,
                opacity: min(1.0, localP * 2.2),
                trackingEmDelta: rem * 0.22,
                blurRadius: rem * (0.34 * em)
            )
        case .loop(_, let cycleProgress):
            let wave = (1.0 - cos(cycleProgress * .pi * 2.0)) * 0.5
            return TextUnitDelta(
                scaleX: 1.0 + wave * 0.025,
                scaleY: 1.0 + wave * 0.025,
                opacity: 1.0,
                trackingEmDelta: wave * 0.03
            )
        case .outro(let progress):
            let startP = normIdx * 0.38
            let localP = progress <= startP ? 0.0 : min(1.0, (progress - startP) / (1.0 - startP))
            let ease = pow(localP, 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.18,
                scaleY: 1.0 + ease * 0.18,
                opacity: 1.0 - ease,
                trackingEmDelta: ease * 0.24,
                blurRadius: ease * (0.34 * em)
            )
        }
    }
}

// MARK: - Pro Script 5: Beat Pulse Slam (Nhấn nhịp nhạc & Rung nhẹ đồng bộ Beat-Sync)
public struct BeatPulseSlamScript: TextAnimationScript {
    public let id = "beat_pulse_slam"
    public let displayName = "Beat Pulse"
    public let description = "Punchy whole-block beat drop with rhythmic music pulse and snap zoom outro"
    public let category = TextAnimationCategory.pop
    public let tags: [TextAnimationTag] = [.pop]
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let decay = exp(-p * 5.0)
            let spring = 1.0 - decay * cos(p * .pi * 3.0)
            return TextUnitDelta(
                scaleX: max(0.2, 0.35 + 0.65 * spring),
                scaleY: max(0.2, 0.35 + 0.65 * spring),
                opacity: min(1.0, p * 4.5),
                glowIntensityDelta: decay * 28.0,
                blurRadius: (1.0 - min(1.0, p * 2.5)) * (0.14 * em),
                bloomIntensity: decay * 0.85
            )
        case .loop(_, let cycleProgress):
            let beat = pow(sin(cycleProgress * .pi), 3.0)
            return TextUnitDelta(
                scaleX: 1.0 + beat * 0.12,
                scaleY: 1.0 + beat * 0.12,
                opacity: 1.0,
                glowIntensityDelta: beat * 24.0,
                bloomIntensity: beat * 0.85
            )
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.4)
            return TextUnitDelta(
                scaleX: max(0.1, 1.0 - ease * 0.65),
                scaleY: max(0.1, 1.0 - ease * 0.65),
                opacity: 1.0 - ease,
                blurRadius: ease * (0.16 * em)
            )
        }
    }
}
