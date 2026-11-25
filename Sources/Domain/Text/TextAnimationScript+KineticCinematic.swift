import Foundation

// MARK: - Kinetic 3: Pop-Up Hinge 3D (Bật dựng đứng 3D thật từ bản lề đáy)
public struct PopUpHinge3DScript: TextAnimationScript {
    public let id = "pop_up_hinge_3d"
    public let displayName = "Hinge 3D Pop"
    public let description = "Characters hinge upward from the bottom baseline with true 3D X-axis perspective"
    public let category = TextAnimationCategory.threeD
    public let tags: [TextAnimationTag] = [.threeD, .pop]
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let loopAt: (Double) -> (rx: Double, sy: Double) = { prog in
            let a = prog * .pi * 2.0 - Double(unitIndex) * 0.52, b = max(0.0, sin(a))
            return (cos(a) * b * 18.0, 1.0 + b * 0.08)
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.45 / Double(total))) / 0.55))
            guard p > 0.0 else { return TextUnitDelta(scaleY: 0.45, rotationX: -82.0, opacity: 0.0, anchorOverride: .bottom) }
            let decay = exp(-p * 4.2) * (1.0 - p), swing = decay * cos(p * .pi * 2.8)
            let l = loopAt(progress)
            return TextUnitDelta(
                scaleY: (1.0 - p) * 0.90 + p * l.sy,
                rotationX: -swing * 82.0 + p * l.rx,
                opacity: min(1.0, p * 4.0), anchorOverride: .bottom
            )
        case .loop(_, let cycleProgress):
            let l = loopAt(cycleProgress)
            return TextUnitDelta(scaleY: l.sy, rotationX: l.rx, opacity: 1.0, anchorOverride: .bottom)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let ease = p * p, stay = 1.0 - ease, l = loopAt(progress)
            return TextUnitDelta(
                scaleY: max(0.35, stay * l.sy + ease * 0.40),
                rotationX: stay * l.rx + ease * 82.0,
                opacity: stay, anchorOverride: .bottom
            )
        }
    }
}

// MARK: - Kinetic 5: Tornado Spiral Pop (Xoáy lốc tâm chấn & Bung giãn khoảng cách)
public struct TornadoSpiralPopScript: TextAnimationScript {
    public let id = "tornado_spiral_pop"
    public let displayName = "Tornado Spiral"
    public let description = "360-degree tornado swirl bursting outward from center with dynamic orbit"
    public let category = TextAnimationCategory.pop
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let angle = prog * .pi * 2.0 - Double(unitIndex) * 0.55
            return TextUnitDelta(
                offsetX: cos(angle) * (0.09 * em), offsetY: sin(angle) * (0.16 * em),
                scaleX: 1.0 + sin(angle) * 0.08, scaleY: 1.0 + sin(angle) * 0.08,
                rotation: sin(angle) * 9.0, opacity: 1.0
            )
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(scaleX: 0.05, scaleY: 0.05, opacity: 0.0, trackingEmDelta: -0.55)
            } else {
                let decay = exp(-p * 4.0), ease = 1.0 - pow(1.0 - p, 3.0)
                let spiralAngle = (1.0 - ease) * .pi * 2.0 + Double(unitIndex) * 0.45
                let radius = (1.0 - ease) * (0.72 * em), scale = 1.0 - decay * cos(p * .pi * 2.6) * 0.85
                raw = TextUnitDelta(
                    offsetX: cos(spiralAngle) * radius, offsetY: sin(spiralAngle) * radius,
                    scaleX: max(0.08, scale), scaleY: max(0.08, scale),
                    rotation: (1.0 - ease) * 360.0, opacity: min(1.0, p * 3.8),
                    trackingEmDelta: -(1.0 - ease) * 0.48
                )
            }
            let blendT = min(1.0, max(0.0, (p - 0.42) / 0.58))
            return TextUnitDelta.lerp(raw, loopAt(progress), t: blendT * blendT * (3.0 - 2.0 * blendT))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            let ease = p * p, s = p * p * (3.0 - 2.0 * p)
            let angle = ease * .pi * 1.5 + Double(unitIndex) * 0.4
            let outDelta = TextUnitDelta(
                offsetX: cos(angle) * ease * (0.65 * em), offsetY: sin(angle) * ease * (0.65 * em),
                scaleX: max(0.05, 1.0 - ease), scaleY: max(0.05, 1.0 - ease),
                rotation: -ease * 240.0, opacity: 1.0 - ease, trackingEmDelta: -ease * 0.50
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: s)
        }
    }
}

// MARK: - Cinematic 4: Pendulum Hinge Swing (Đung đưa con lắc trên bản lề đỉnh)
public struct PendulumHingeSwingScript: TextAnimationScript {
    public let id = "pendulum_hinge_swing"
    public let displayName = "Pendulum Swing"
    public let description = "Characters hang from a top hinge and sway like classic clock pendulums"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let sway = sin(prog * .pi * 2.0 - Double(unitIndex) * 0.45)
            return TextUnitDelta(rotation: sway * 7.5, skewX: sway * 5.0, opacity: 1.0, anchorOverride: .top)
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.42 / Double(total))) / 0.58))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(scaleY: 0.08, rotation: -65.0, opacity: 0.0, anchorOverride: .top)
            } else {
                let decay = exp(-p * 3.8), swing = decay * cos(p * .pi * 3.2), dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
                raw = TextUnitDelta(
                    scaleY: max(0.1, 1.0 - decay * 0.65), rotation: swing * 42.0 * dir,
                    skewX: swing * 18.0 * dir, opacity: min(1.0, p * 3.5), anchorOverride: .top
                )
            }
            let blendT = min(1.0, max(0.0, (p - 0.42) / 0.58))
            return TextUnitDelta.lerp(raw, loopAt(progress), t: blendT * blendT * (3.0 - 2.0 * blendT))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.35 / Double(total))) / 0.65))
            let ease = p * p, s = p * p * (3.0 - 2.0 * p)
            let outDelta = TextUnitDelta(
                scaleY: max(0.08, 1.0 - ease * 0.88), rotation: ease * 48.0,
                skewX: ease * 20.0, opacity: 1.0 - ease, anchorOverride: .top
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: s)
        }
    }
}
