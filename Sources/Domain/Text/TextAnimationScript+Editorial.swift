import Foundation

// MARK: - Editorial 2: Curtain Baseline Rise (Trồi lên từ mặt nạ đường cơ sở vô hình)
public struct CurtainBaselineRiseScript: TextAnimationScript {
    public let id = "curtain_baseline_rise"
    public let displayName = "Curtain Rise"
    public let description = "Clean Keynote-style word rise emerging smoothly from an invisible baseline mask"
    public let category = TextAnimationCategory.fade
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let phaseOffset = Double(unitIndex) * 0.6
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.42 / Double(total))) / 0.58))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealY: 0.0) }
            let ease = 1.0 - pow(1.0 - p, 3.6)
            let wY = -sin(progress * .pi * 2.0 - phaseOffset) * (0.05 * em)
            return TextUnitDelta(offsetY: (1.0 - ease) * (0.68 * em) + ease * wY, opacity: min(1.0, p * 4.5), clipRevealY: ease)
        case .loop(_, let cycleProgress):
            let gentle = sin(cycleProgress * .pi * 2.0 - phaseOffset)
            return TextUnitDelta(offsetY: -gentle * (0.05 * em), opacity: 1.0, clipRevealY: 1.0)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            let ease = pow(p, 2.4)
            let wY = -sin(progress * .pi * 2.0 - phaseOffset) * (0.05 * em)
            return TextUnitDelta(offsetY: (1.0 - ease) * wY + ease * (0.65 * em), opacity: 1.0 - ease, clipRevealY: max(0.0, 1.0 - ease))
        }
    }
}

// MARK: - Editorial 5: Flip Counter Roll (Bảng lật số cơ học Odometer)
public struct FlipCounterRollScript: TextAnimationScript {
    public let id = "flip_counter_roll"
    public let displayName = "Flip Roll"
    public let description = "Mechanical odometer vertical roll inside a clipped slit with crisp bounce"
    public let category = TextAnimationCategory.typewriter
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.46 / Double(total))) / 0.54))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealY: 0.0) }
            let decay = exp(-p * 4.4) * (1.0 - p)
            let roll = 1.0 - decay * cos(p * .pi * 2.6)
            let lY = sin(progress * .pi * 2.0 - Double(unitIndex) * 0.45) * (0.06 * em) * dir
            return TextUnitDelta(offsetY: (1.0 - roll) * dir * (0.75 * em) + p * lY, scaleY: 0.85 + 0.15 * min(1.0, p * 2.0), opacity: min(1.0, p * 4.5), clipRevealY: min(1.0, p * 1.4))
        case .loop(_, let cycleProgress):
            let tick = sin(cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.45)
            return TextUnitDelta(offsetY: tick * (0.06 * em) * dir, opacity: 1.0, clipRevealY: 1.0)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            let ease = p * p
            let lY = sin(progress * .pi * 2.0 - Double(unitIndex) * 0.45) * (0.06 * em) * dir
            return TextUnitDelta(offsetY: (1.0 - ease) * lY - dir * ease * (0.72 * em), opacity: 1.0 - ease, clipRevealY: max(0.0, 1.0 - ease))
        }
    }
}

