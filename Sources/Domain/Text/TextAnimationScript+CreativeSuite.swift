import Foundation

// MARK: - Fade 1: Soft Glow Fade (Hiện mờ ảo kết hợp ánh sáng dịu và nhịp thở quang năng)
public struct SoftGlowFadeScript: TextAnimationScript {
    public let id = "fade_soft_glow"
    public let displayName = "Soft Glow"
    public let description = "Chữ hiện dần từ độ mờ ảo kèm ánh hào quang dịu nhẹ, thở tuần hoàn 1.0s và tan biến vào nền"
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
            let g = glowState(cycleProgress: cycleProgress, em: em)
            return TextUnitDelta(opacity: 1.0, glowIntensityDelta: g.glow, blurRadius: g.blur)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func glowState(cycleProgress: Double, em: Double) -> (glow: Double, blur: Double) {
        let s = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
        return (glow: s * 28.0, blur: s * (0.015 * em))
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.25
        guard progress > startP else { return TextUnitDelta(opacity: 0.0) }
        let localP = max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let ease = 1.0 - pow(1.0 - localP, 3.0)
        let rem = 1.0 - ease
        let g = glowState(cycleProgress: progress, em: em)
        return TextUnitDelta(
            opacity: min(1.0, localP * 1.5),
            glowIntensityDelta: rem * 35.0 + ease * g.glow,
            blurRadius: rem * (0.14 * em) + ease * g.blur
        )
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.25
        let localP = progress <= startP ? 0.0 : max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let outEase = pow(localP, 2.5)
        let stay = 1.0 - outEase
        let g = glowState(cycleProgress: progress, em: em)
        return TextUnitDelta(
            opacity: max(0.0, 1.0 - outEase),
            glowIntensityDelta: stay * g.glow + outEase * 30.0,
            blurRadius: stay * g.blur + outEase * (0.14 * em)
        )
    }
}

// MARK: - Fade 2: Cinematic Dissolve (Chuyển cảnh mờ tan điện ảnh với Tracking dãn nhẹ)
public struct CinematicDissolveScript: TextAnimationScript {
    public let id = "fade_cinematic"
    public let displayName = "Cinematic"
    public let description = "Mờ tan chậm rãi kiểu phim tài liệu điện ảnh, khoảng cách chữ dãn nhẹ tinh tế"
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
    public let description = "Phóng to vượt ngưỡng đàn hồi giật lò xo dứt khoát, nhịp đập tim tuần hoàn 1.0s"
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

// MARK: - Typewriter 2: Word Staccato (Từng từ nảy dứt khoát theo nhịp đọc voice-over)
public struct WordStaccatoScript: TextAnimationScript {
    public let id = "typewriter_staccato"
    public let displayName = "Word Staccato"
    public let description = "Từng từ bật nảy dứt khoát theo nhịp đọc voice-over, giữ nhịp thở toàn câu mượt mà"
    public let category = TextAnimationCategory.typewriter
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let step = 0.85 / Double(total)
            let charStart = Double(unitIndex) * step
            let charEnd = charStart + step
            if progress < charStart {
                return TextUnitDelta(opacity: 0.0)
            } else if progress < charEnd {
                let p = (progress - charStart) / max(0.001, step)
                let pop = 1.0 + sin(p * .pi) * 0.25
                return TextUnitDelta(scaleX: pop, scaleY: pop, opacity: 1.0)
            } else {
                let breathe = sin(progress * .pi * 2.0) * 0.02
                return TextUnitDelta(scaleX: 1.0 + breathe, scaleY: 1.0 + breathe, opacity: 1.0)
            }
        case .loop(_, let cycleProgress):
            let breathe = sin(cycleProgress * .pi * 2.0) * 0.02
            return TextUnitDelta(scaleX: 1.0 + breathe, scaleY: 1.0 + breathe, opacity: 1.0)
        case .outro(let progress):
            let total = max(1, unitTotal)
            let step = 0.85 / Double(total)
            let charStart = Double(unitIndex) * step
            if progress > charStart {
                let p = min(1.0, (progress - charStart) / max(0.001, step))
                let ease = p * p
                return TextUnitDelta(scaleX: max(0.1, 1.0 - ease), scaleY: max(0.1, 1.0 - ease), opacity: 1.0 - ease)
            }
            return TextUnitDelta(opacity: 1.0)
        }
    }
}

// MARK: - Wave 4: Cascade Wave Flow (Sóng lướt uốn lượn từng ký tự từ trên xuống, tan biến hào quang sương mù từ trái qua phải)
public struct CascadeWaveFlowScript: TextAnimationScript {
    public let id = "wave_cascade_flow"
    public let displayName = "Cascade Wave"
    public let description = "Từng ký tự lướt sóng từ trên xuống uốn lượn, bồng bềnh và tan biến theo làn sương quang học từ trái sang phải"
    public let category = TextAnimationCategory.wave
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let normIdx = total > 1 ? Double(unitIndex) / Double(total - 1) : 0.0

        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, normIdx: normIdx)
        case .loop(_, let cycleProgress):
            let w = waveState(cycleProgress: cycleProgress, em: em, normIdx: normIdx)
            return TextUnitDelta(offsetY: w.y, scaleX: w.scale, scaleY: w.scale, rotation: w.rot, opacity: 1.0, glowIntensityDelta: w.glow)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, normIdx: normIdx)
        }
    }

    private func waveState(cycleProgress: Double, em: Double, normIdx: Double) -> (y: Double, scale: Double, rot: Double, glow: Double) {
        let angle = cycleProgress * .pi * 2.0 - normIdx * .pi * 1.6
        let s = sin(angle)
        let c = cos(angle)
        return (y: -s * (0.12 * em), scale: 1.0 + s * 0.035, rot: c * 2.5, glow: max(0.0, s) * 16.0)
    }

    private func evaluateIntro(progress: Double, em: Double, normIdx: Double) -> TextUnitDelta {
        let delaySpan = 0.52
        let charDur = 0.48
        let charStart = normIdx * delaySpan
        guard progress > charStart else { return TextUnitDelta(opacity: 0.0) }
        let localP = min(1.0, (progress - charStart) / charDur)
        let ease = 1.0 - pow(1.0 - localP, 3.0)
        let bounce = sin(localP * .pi) * 0.14
        let rem = 1.0 - ease
        let w = waveState(cycleProgress: progress, em: em, normIdx: normIdx)

        return TextUnitDelta(
            offsetX: rem * (0.35 * em),
            offsetY: -rem * (1.1 * em) - bounce * (0.10 * em) + ease * w.y,
            scaleX: (1.0 - rem * 0.35) + bounce * 0.08,
            scaleY: (1.0 - rem * 0.35) + bounce * 0.08,
            rotation: rem * 14.0 + ease * w.rot,
            opacity: min(1.0, localP * 2.2),
            glowIntensityDelta: ease * w.glow + bounce * 25.0,
            blurRadius: rem * (0.14 * em)
        )
    }

    private func evaluateOutro(progress: Double, em: Double, normIdx: Double) -> TextUnitDelta {
        let delaySpan = 0.48
        let charDur = 0.52
        let charStart = normIdx * delaySpan
        let localP = progress <= charStart ? 0.0 : min(1.0, (progress - charStart) / charDur)
        let outEase = pow(localP, 2.2)
        let stay = 1.0 - outEase
        let w = waveState(cycleProgress: progress, em: em, normIdx: normIdx)
        let flareGlow = sin(localP * .pi) * 32.0

        return TextUnitDelta(
            offsetY: stay * w.y - outEase * (0.22 * em),
            scaleX: stay * w.scale + outEase * 1.15,
            scaleY: stay * w.scale + outEase * 1.15,
            rotation: stay * w.rot,
            opacity: max(0.0, 1.0 - outEase),
            glowIntensityDelta: stay * w.glow + flareGlow,
            blurRadius: stay * 0.0 + outEase * (0.32 * em)
        )
    }
}

