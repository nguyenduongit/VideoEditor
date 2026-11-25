import Foundation

// MARK: - Fade 1: Soft Glow Fade (Hiện mờ ảo kết hợp lấy nét nhẹ nhàng thuần chuyển động)
public struct SoftGlowFadeScript: TextAnimationScript {
    public let id = "fade_soft_glow"
    public let displayName = "Soft Glow"
    public let description = "Fades in softly with optical defocus, breathes in a 1.0s cycle, then dissolves"
    public let category = TextAnimationCategory.fade
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        case .loop(_, let cycleProgress):
            return TextUnitDelta(opacity: 1.0, blurRadius: loopBlur(cycleProgress: cycleProgress, em: em))
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func loopBlur(cycleProgress: Double, em: Double) -> Double {
        let s = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
        return s * (0.015 * em)
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.25
        guard progress > startP else { return TextUnitDelta(opacity: 0.0) }
        let localP = max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let ease = 1.0 - pow(1.0 - localP, 3.0)
        let rem = 1.0 - ease
        let blurBreathe = loopBlur(cycleProgress: progress, em: em)
        return TextUnitDelta(
            opacity: min(1.0, localP * 1.5),
            blurRadius: rem * (0.14 * em) + ease * blurBreathe
        )
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.25
        let localP = progress <= startP ? 0.0 : max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let outEase = pow(localP, 2.5)
        let stay = 1.0 - outEase
        let blurBreathe = loopBlur(cycleProgress: progress, em: em)
        return TextUnitDelta(
            opacity: max(0.0, 1.0 - outEase),
            blurRadius: stay * blurBreathe + outEase * (0.14 * em)
        )
    }
}

// MARK: - Fade 2: Cinematic Dissolve (Chuyển cảnh mờ tan điện ảnh với Tracking dãn nhẹ)
public struct CinematicDissolveScript: TextAnimationScript {
    public let id = "fade_cinematic"
    public let displayName = "Cinematic"
    public let description = "Documentary-style slow dissolve with subtle expanded letter tracking"
    public let category = TextAnimationCategory.fade
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        switch phase {
        case .intro(let progress):
            let ease = 1.0 - pow(1.0 - progress, 2.5)
            let rem = 1.0 - ease
            let b = breatheState(cycleProgress: progress)
            return TextUnitDelta(opacity: ease * b.op, trackingEmDelta: rem * 0.06 + ease * b.tracking)
        case .loop(_, let cycleProgress):
            let b = breatheState(cycleProgress: cycleProgress)
            return TextUnitDelta(opacity: b.op, trackingEmDelta: b.tracking)
        case .outro(let progress):
            let outEase = pow(progress, 2.5)
            let stay = 1.0 - outEase
            let b = breatheState(cycleProgress: progress)
            return TextUnitDelta(opacity: stay * b.op, trackingEmDelta: stay * b.tracking + outEase * 0.06)
        }
    }

    private func breatheState(cycleProgress: Double) -> (op: Double, tracking: Double) {
        let wave = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
        return (op: 1.0 - wave * 0.07, tracking: wave * 0.015)
    }
}

// MARK: - Pop 1: Elastic Bounce Pop (Phóng to đàn hồi giật lò xo dứt khoát kiểu mạng xã hội)
public struct ElasticBouncePopScript: TextAnimationScript {
    public let id = "pop_elastic_bounce"
    public let displayName = "Elastic Pop"
    public let description = "Crisp elastic spring pop with 1.0s heartbeat pulse loop"
    public let category = TextAnimationCategory.pop
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        case .loop(_, let cycleProgress):
            let p = pulseState(cycleProgress: cycleProgress, em: em)
            return TextUnitDelta(offsetY: p.y, scaleX: p.s, scaleY: p.s, opacity: 1.0)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func pulseState(cycleProgress: Double, em: Double) -> (s: Double, y: Double) {
        let s = sin(cycleProgress * .pi * 2.0)
        return (s: 1.0 + s * 0.045, y: -s * (0.02 * em))
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.28
        guard progress > startP else { return TextUnitDelta(scaleX: 0.0, scaleY: 0.0, opacity: 0.0) }
        let localP = max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let spring = 1.0 - exp(-localP * 5.2) * cos(localP * .pi * 3.2)
        let clampedS = max(0.0, min(1.28, spring))
        let p = pulseState(cycleProgress: progress, em: em)
        let easeIn = localP
        let scale = (1.0 - easeIn) * clampedS + easeIn * p.s
        return TextUnitDelta(
            offsetY: (1.0 - localP) * (-0.15 * em) + localP * p.y,
            scaleX: scale,
            scaleY: scale,
            opacity: min(1.0, localP * 3.0)
        )
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.28
        let localP = progress <= startP ? 0.0 : max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let outEase = pow(localP, 2.0)
        let stay = 1.0 - outEase
        let p = pulseState(cycleProgress: progress, em: em)
        let popAnticipate = localP < 0.25 ? (localP * 4.0 * 0.12) : 0.12 - (localP - 0.25) * 1.5
        let scale = max(0.0, stay * p.s + popAnticipate)
        return TextUnitDelta(
            offsetY: stay * p.y + outEase * (-0.25 * em),
            scaleX: scale,
            scaleY: scale,
            opacity: max(0.0, 1.0 - outEase)
        )
    }
}

