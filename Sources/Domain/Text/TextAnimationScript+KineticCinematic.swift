import Foundation

// MARK: - Kinetic 3: Pop-Up Hinge 3D (Bật dựng đứng từ bản lề đáy)
public struct PopUpHinge3DScript: TextAnimationScript {
    public let id = "pop_up_hinge_3d"
    public let displayName = "Hinge 3D Pop"
    public let description = "Từng chữ bật dựng đứng từ mặt đất theo bản lề đáy kèm biến dạng phối cảnh 3D"
    public let category = TextAnimationCategory.pop
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.45 / Double(total))) / 0.55))
            guard p > 0.0 else { return TextUnitDelta(scaleY: 0.04, opacity: 0.0, anchorOverride: .bottom) }
            let decay = exp(-p * 4.2)
            let stand = 1.0 - decay * cos(p * .pi * 3.0)
            let swingSkew = decay * cos(p * .pi * 3.0) * 28.0
            return TextUnitDelta(
                scaleX: max(0.2, 1.0 - (stand - 1.0) * 0.35), scaleY: max(0.06, stand),
                skewX: swingSkew, opacity: min(1.0, p * 4.0), anchorOverride: .bottom,
                glowIntensityDelta: max(0.0, stand - 1.0) * 40.0
            )
        case .loop(_, let cycleProgress):
            let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.52
            let bounce = max(0.0, sin(angle))
            return TextUnitDelta(
                scaleX: 1.0 - bounce * 0.10, scaleY: 1.0 + bounce * 0.22,
                skewX: cos(angle) * bounce * 10.0, opacity: 1.0, anchorOverride: .bottom
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let ease = p * p
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.20, scaleY: max(0.04, 1.0 - ease * 0.96),
                skewX: -ease * 26.0, opacity: 1.0 - ease, anchorOverride: .bottom
            )
        }
    }
}

// MARK: - Kinetic 4: Whip Echo Slam (Lao vút kèm bóng mờ chuyển động & Va chạm)
public struct WhipEchoSlamScript: TextAnimationScript {
    public let id = "whip_echo_slam"
    public let displayName = "Whip Echo Slam"
    public let description = "Từng từ lao vút từ hai biên kèm bóng ma chuyển động (Echo Trail) và nảy chấn động"
    public let category = TextAnimationCategory.kinetic
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let dir = unitIndex.isMultiple(of: 2) ? -1.0 : 1.0
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            guard p > 0.0 else { return TextUnitDelta(offsetX: dir * 2.4 * em, opacity: 0.0) }
            let decay = exp(-p * 4.6)
            let spring = 1.0 - decay * cos(p * .pi * 2.8)
            let vel = decay * (1.0 - p)
            let squash = decay * sin(p * .pi * 3.0) * 0.26
            return TextUnitDelta(
                offsetX: (1.0 - spring) * dir * (2.2 * em), scaleX: 1.0 + squash,
                scaleY: 1.0 - squash * 0.7, skewX: -dir * vel * 24.0,
                opacity: min(1.0, p * 4.5), echoCount: p < 0.78 ? 2 : 0,
                echoOffsetXEm: -dir * vel * 0.42
            )
        case .loop(_, let cycleProgress):
            let pulse = sin(cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.8)
            let punch = pow(max(0.0, pulse), 3.0)
            return TextUnitDelta(
                offsetX: pulse * (0.08 * em), scaleX: 1.0 + punch * 0.16,
                scaleY: 1.0 + punch * 0.16, skewX: -pulse * 6.0, opacity: 1.0,
                echoCount: punch > 0.45 ? 1 : 0, echoOffsetXEm: -dir * punch * 0.18
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.30 / Double(total))) / 0.70))
            let ease = pow(p, 2.2)
            return TextUnitDelta(
                offsetX: -dir * ease * (2.2 * em), scaleX: 1.0 + ease * 0.25,
                scaleY: max(0.1, 1.0 - ease * 0.45), skewX: dir * ease * 24.0,
                opacity: 1.0 - ease, echoCount: 2, echoOffsetXEm: dir * ease * 0.35
            )
        }
    }
}

// MARK: - Kinetic 5: Tornado Spiral Pop (Xoáy lốc tâm chấn & Bung giãn khoảng cách)
public struct TornadoSpiralPopScript: TextAnimationScript {
    public let id = "tornado_spiral_pop"
    public let displayName = "Tornado Spiral"
    public let description = "Chữ xoáy lốc 360° bung tỏa từ tâm ra hai bên kèm quỹ đạo орbit năng động"
    public let category = TextAnimationCategory.kinetic
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            guard p > 0.0 else { return TextUnitDelta(scaleX: 0.05, scaleY: 0.05, opacity: 0.0, trackingEmDelta: -0.55) }
            let decay = exp(-p * 4.0)
            let ease = 1.0 - pow(1.0 - p, 3.0)
            let spiralAngle = (1.0 - ease) * .pi * 2.0 + Double(unitIndex) * 0.45
            let radius = (1.0 - ease) * (0.72 * em)
            let scale = 1.0 - decay * cos(p * .pi * 2.6) * 0.85
            return TextUnitDelta(
                offsetX: cos(spiralAngle) * radius,
                offsetY: sin(spiralAngle) * radius,
                scaleX: max(0.08, scale),
                scaleY: max(0.08, scale),
                rotation: (1.0 - ease) * 360.0,
                opacity: min(1.0, p * 3.8),
                trackingEmDelta: -(1.0 - ease) * 0.48
            )
        case .loop(_, let cycleProgress):
            let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.55
            return TextUnitDelta(
                offsetX: cos(angle) * (0.09 * em),
                offsetY: sin(angle) * (0.16 * em),
                scaleX: 1.0 + sin(angle) * 0.08,
                scaleY: 1.0 + sin(angle) * 0.08,
                rotation: sin(angle) * 9.0,
                opacity: 1.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = p * p
            let angle = ease * .pi * 1.5 + Double(unitIndex) * 0.4
            return TextUnitDelta(
                offsetX: cos(angle) * ease * (0.65 * em),
                offsetY: sin(angle) * ease * (0.65 * em),
                scaleX: max(0.05, 1.0 - ease),
                scaleY: max(0.05, 1.0 - ease),
                rotation: -ease * 240.0,
                opacity: 1.0 - ease,
                trackingEmDelta: -ease * 0.50
            )
        }
    }
}

// MARK: - Cinematic 3: Trailer Tracking Expand (Giãn khoảng cách chữ điện ảnh Anamorphic)
public struct TrailerTrackingExpandScript: TextAnimationScript {
    public let id = "trailer_tracking_expand"
    public let displayName = "Tracking Slide"
    public let description = "Hội tụ khoảng cách chữ từ xa vào tâm kèm lấy nét ống kính và nhịp thở giãn chữ điện ảnh"
    public let category = TextAnimationCategory.slide
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.2)
            let track = (1.0 - ease) * 0.46
            let scale = 1.24 - 0.24 * ease
            return TextUnitDelta(
                scaleX: scale,
                scaleY: scale,
                opacity: min(1.0, p * 2.2),
                trackingEmDelta: track,
                blurRadius: (1.0 - ease) * (0.28 * em)
            )
        case .loop(_, let cycleProgress):
            let breathe = (1.0 - cos(cycleProgress * .pi * 2.0)) * 0.5
            return TextUnitDelta(
                scaleX: 1.0 + breathe * 0.04,
                scaleY: 1.0 + breathe * 0.04,
                opacity: 1.0,
                trackingEmDelta: breathe * 0.09
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.2)
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.22,
                scaleY: 1.0 + ease * 0.22,
                opacity: 1.0 - ease,
                trackingEmDelta: ease * 0.42,
                blurRadius: ease * (0.28 * em)
            )
        }
    }
}

// MARK: - Cinematic 4: Pendulum Hinge Swing (Đung đưa con lắc trên bản lề đỉnh)
public struct PendulumHingeSwingScript: TextAnimationScript {
    public let id = "pendulum_hinge_swing"
    public let displayName = "Pendulum Swing"
    public let description = "Từng chữ treo trên bản lề đỉnh đung đưa như con lắc đồng hồ cổ điển"
    public let category = TextAnimationCategory.cinematic
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.42 / Double(total))) / 0.58))
            guard p > 0.0 else { return TextUnitDelta(scaleY: 0.08, rotation: -65.0, opacity: 0.0, anchorOverride: .top) }
            let decay = exp(-p * 3.8)
            let swing = decay * cos(p * .pi * 3.2)
            let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
            return TextUnitDelta(
                scaleY: max(0.1, 1.0 - decay * 0.65),
                rotation: swing * 42.0 * dir,
                skewX: swing * 18.0 * dir,
                opacity: min(1.0, p * 3.5),
                anchorOverride: .top
            )
        case .loop(_, let cycleProgress):
            let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.45
            let sway = sin(angle)
            return TextUnitDelta(
                rotation: sway * 7.5,
                skewX: sway * 5.0,
                opacity: 1.0,
                anchorOverride: .top
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.35 / Double(total))) / 0.65))
            let ease = p * p
            return TextUnitDelta(
                scaleY: max(0.08, 1.0 - ease * 0.88),
                rotation: ease * 48.0,
                skewX: ease * 20.0,
                opacity: 1.0 - ease,
                anchorOverride: .top
            )
        }
    }
}

// MARK: - Cinematic 5: Anamorphic Split Reveal (Mặt nạ cắt ngang xuất hiện đối xứng)
public struct AnamorphicSplitRevealScript: TextAnimationScript {
    public let id = "anamorphic_split_reveal"
    public let displayName = "Split Mask Reveal"
    public let description = "Chữ trồi lên qua mặt nạ cắt ngang vô hình đan xen trên dưới chuẩn danh đề điện ảnh"
    public let category = TextAnimationCategory.cinematic
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.44 / Double(total))) / 0.56))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealY: 0.0) }
            let ease = 1.0 - pow(1.0 - p, 3.2)
            return TextUnitDelta(
                offsetY: (1.0 - ease) * dir * (0.58 * em),
                skewX: (1.0 - ease) * dir * 14.0,
                opacity: min(1.0, p * 4.0),
                clipRevealY: ease,
                trackingEmDelta: (1.0 - ease) * 0.14
            )
        case .loop(_, let cycleProgress):
            let wave = sin(cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.4)
            return TextUnitDelta(
                offsetY: wave * (0.06 * em),
                opacity: 1.0,
                clipRevealY: 1.0,
                trackingEmDelta: (1.0 - cos(cycleProgress * .pi * 2.0)) * 0.03
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.38 / Double(total))) / 0.62))
            let ease = p * p
            return TextUnitDelta(
                offsetY: -dir * ease * (0.55 * em),
                opacity: 1.0 - ease,
                clipRevealY: max(0.0, 1.0 - ease)
            )
        }
    }
}
