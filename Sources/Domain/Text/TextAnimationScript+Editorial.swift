import Foundation

// MARK: - Glitch 4: Quantum Teleport Flicker (Dịch chuyển lượng tử đa phân mảnh)
public struct QuantumTeleportFlickerScript: TextAnimationScript {
    public let id = "quantum_teleport_flicker"
    public let displayName = "Quantum Teleport"
    public let description = "Characters teleport across fragmented coordinates with echo trails before locking"
    public let category = TextAnimationCategory.glitch
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let seed = Double((unitIndex * 29 + 7) % 17)
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0) }
            if p >= 0.86 { return TextUnitDelta(opacity: 1.0) }
            let qStep = floor(p * 9.0)
            let env = 1.0 - p / 0.86
            let jumpX = sin(qStep * 3.7 + seed) * env * (0.68 * em)
            let jumpY = cos(qStep * 5.1 + seed) * env * (0.52 * em)
            return TextUnitDelta(
                offsetX: jumpX,
                offsetY: jumpY,
                scaleX: 1.0 + env * 0.25,
                scaleY: 1.0 - env * 0.18,
                opacity: Int(qStep + seed).isMultiple(of: 4) ? 0.35 : 0.95,
                echoCount: 2,
                echoOffsetXEm: -jumpX / em * 0.45,
                echoOffsetYEm: -jumpY / em * 0.45,
                glitchIntensity: env * 78.0
            )
        case .loop(let time, _):
            let slot = floor(time * 10.0)
            let active = sin(slot * 2.9 + seed * 1.7) > 0.82
            guard active else { return TextUnitDelta(opacity: 1.0) }
            let dx = cos(slot * 4.1 + seed) * 0.22
            let dy = sin(slot * 3.3 + seed) * 0.16
            return TextUnitDelta(
                offsetX: dx * em,
                offsetY: dy * em,
                opacity: 0.88,
                echoCount: 2,
                echoOffsetXEm: -dx * 0.7,
                echoOffsetYEm: -dy * 0.7,
                glitchIntensity: 52.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let qStep = floor(p * 8.0)
            let dx = sin(qStep * 4.3 + seed) * p * 0.75
            let dy = cos(qStep * 3.9 + seed) * p * 0.60
            return TextUnitDelta(
                offsetX: dx * em,
                offsetY: dy * em,
                opacity: 1.0 - p,
                echoCount: 2,
                echoOffsetXEm: -dx * 0.5,
                echoOffsetYEm: -dy * 0.5,
                glitchIntensity: p * 85.0
            )
        }
    }
}

// MARK: - Glitch 5: Cyber Shutter Slice (Cửa chớp kỹ thuật số cắt dọc)
public struct CyberShutterSliceScript: TextAnimationScript {
    public let id = "cyber_shutter_slice"
    public let displayName = "Cyber Shutter"
    public let description = "Stepped horizontal shutter mask reveals characters with modern RGB pulses"
    public let category = TextAnimationCategory.glitch
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.45 / Double(total))) / 0.55))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealX: 0.0) }
            let steppedReveal = min(1.0, floor(p * 8.0 + 1.0) / 8.0)
            let jitter = (1.0 - p) * dir
            return TextUnitDelta(
                offsetY: jitter * (0.28 * em),
                skewY: jitter * 18.0,
                opacity: 1.0,
                clipRevealX: steppedReveal,
                glitchIntensity: (1.0 - p) * 70.0
            )
        case .loop(let time, _):
            let step = floor(time * 12.0)
            let pulse = sin(step * 2.3 + Double(unitIndex) * 1.5) > 0.78
            return TextUnitDelta(
                offsetY: pulse ? dir * (0.10 * em) : 0.0,
                opacity: 1.0,
                clipRevealX: pulse ? 0.78 : 1.0,
                glitchIntensity: pulse ? 42.0 : 0.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let stepped = max(0.0, 1.0 - floor(p * 7.0) / 7.0)
            return TextUnitDelta(
                offsetY: -dir * p * (0.30 * em),
                opacity: 1.0 - p,
                clipRevealX: stepped,
                glitchIntensity: p * 75.0
            )
        }
    }
}

// MARK: - Editorial 2: Curtain Baseline Rise (Trồi lên từ mặt nạ đường cơ sở vô hình)
public struct CurtainBaselineRiseScript: TextAnimationScript {
    public let id = "curtain_baseline_rise"
    public let displayName = "Curtain Rise"
    public let description = "Clean Keynote-style word rise emerging smoothly from an invisible baseline mask"
    public let category = TextAnimationCategory.slide
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

// MARK: - Editorial 3: Shutter Blind Reveal (Mở cửa chớp ngang kiến trúc tối giản)
public struct ShutterBlindRevealScript: TextAnimationScript {
    public let id = "shutter_blind_reveal"
    public let displayName = "Shutter Blind"
    public let description = "Architectural left-to-right shutter blind reveal per character"
    public let category = TextAnimationCategory.editorial
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.48 / Double(total))) / 0.52))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealX: 0.0) }
            let ease = 1.0 - pow(1.0 - p, 3.2)
            return TextUnitDelta(
                offsetX: -(1.0 - ease) * (0.28 * em),
                opacity: min(1.0, p * 5.0),
                clipRevealX: ease
            )
        case .loop(_, let cycleProgress):
            let breathe = (1.0 - cos(cycleProgress * .pi * 2.0)) * 0.5
            return TextUnitDelta(
                opacity: 1.0,
                clipRevealX: 1.0,
                trackingEmDelta: breathe * 0.04
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            let ease = p * p
            return TextUnitDelta(
                offsetX: ease * (0.25 * em),
                opacity: 1.0 - ease,
                clipRevealX: max(0.0, 1.0 - ease)
            )
        }
    }
}

// MARK: - Editorial 4: Soft Breathe Cascade (Lấy nét sương mờ & Nhịp thở tĩnh tại)
public struct SoftBreatheCascadeScript: TextAnimationScript {
    public let id = "soft_breathe_cascade"
    public let displayName = "Soft Breathe"
    public let description = "Words emerge through silky optical mist with an understated breathing expand"
    public let category = TextAnimationCategory.fade
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let breatheAt: (Double) -> (y: Double, scale: Double) = { prog in
            let b = (1.0 + sin(prog * .pi * 2.0 - Double(unitIndex) * 0.65)) * 0.5
            return (-b * (0.08 * em), 1.0 + b * 0.05)
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.45 / Double(total))) / 0.55))
            guard p > 0.0 else { return TextUnitDelta(offsetY: 0.32 * em, scaleX: 0.90, scaleY: 0.90, opacity: 0.0, blurRadius: 0.30 * em) }
            let ease = 1.0 - pow(1.0 - p, 3.0), b = breatheAt(progress), s = (1.0 - ease) * 0.90 + ease * b.scale
            return TextUnitDelta(offsetY: (1.0 - ease) * (0.32 * em) + ease * b.y, scaleX: s, scaleY: s, opacity: ease, blurRadius: (1.0 - ease) * (0.28 * em))
        case .loop(_, let cycleProgress):
            let b = breatheAt(cycleProgress)
            return TextUnitDelta(offsetY: b.y, scaleX: b.scale, scaleY: b.scale, opacity: 1.0)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let ease = p * p, stay = 1.0 - ease, b = breatheAt(progress), s = stay * b.scale + ease * 1.08
            return TextUnitDelta(offsetY: stay * b.y - ease * (0.28 * em), scaleX: s, scaleY: s, opacity: stay, blurRadius: ease * (0.26 * em))
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

