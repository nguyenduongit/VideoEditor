import Foundation

// MARK: - Breakthrough 6: 3D Card Carousel (Lật thẻ 3D từng ký tự có chiều sâu)
public struct ThreeDCardCarouselScript: TextAnimationScript {
    public let id = "three_d_card_carousel"
    public let displayName = "3D Card Carousel"
    public let description = "Per-character true 3D yaw flip with smooth depth foreshortening"
    public let category = TextAnimationCategory.threeD
    public let tags: [TextAnimationTag] = [.threeD, .pop]
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let wave = sin(prog * .pi * 2.0 - Double(unitIndex) * 0.55)
            return TextUnitDelta(
                offsetY: -wave * (0.08 * em),
                rotationY: wave * 18.0,
                opacity: 1.0
            )
        }
        switch phase {
        case .intro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.42
            let p = min(1.0, max(0.0, (progress - startP) / (1.0 - startP)))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(scaleX: 0.65, scaleY: 0.65, rotationY: -125.0, opacity: 0.0)
            } else {
                let decay = exp(-p * 4.2) * (1.0 - p)
                let swing = decay * cos(p * .pi * 2.5)
                let ease = 1.0 - pow(1.0 - p, 3.0)
                raw = TextUnitDelta(
                    offsetY: (1.0 - ease) * (-0.30 * em),
                    scaleX: 0.72 + 0.28 * ease,
                    scaleY: 0.72 + 0.28 * ease,
                    rotationY: swing * 125.0 - (1.0 - ease) * 90.0,
                    opacity: min(1.0, p * 4.2)
                )
            }
            guard progress > 0.74 else { return raw }
            let t = (progress - 0.74) / 0.26
            return TextUnitDelta.lerp(raw, loopAt(progress), t: t * t * (3.0 - 2.0 * t))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.36
            let p = min(1.0, max(0.0, (progress - startP) / (1.0 - startP)))
            let ease = p * p
            let outDelta = TextUnitDelta(
                offsetY: ease * (0.28 * em),
                scaleX: 1.0 - ease * 0.35,
                scaleY: 1.0 - ease * 0.35,
                rotationY: ease * 115.0,
                opacity: 1.0 - ease
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: min(1.0, progress / 0.25))
        }
    }
}

// MARK: - Breakthrough 7: Diagonal Slash Reveal (Mặt nạ chém chéo sắc nét)
public struct DiagonalSlashRevealScript: TextAnimationScript {
    public let id = "fade_diagonal_slash"
    public let displayName = "Diagonal Slash"
    public let description = "Angled geometric slash wipe reveal with tracking lock and smooth motion glide"
    public let category = TextAnimationCategory.fade
    public let tags: [TextAnimationTag] = [.fade]
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let breathe = 0.5 - 0.5 * cos(prog * .pi * 2.0)
            return TextUnitDelta(opacity: 1.0, maskShapeMode: .diagonalSlash, trackingEmDelta: breathe * 0.04)
        }
        switch phase {
        case .intro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.36
            let p = min(1.0, max(0.0, (progress - startP) / (1.0 - startP)))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(offsetX: -0.35 * em, opacity: 0.0, clipRevealX: 0.0, maskShapeMode: .diagonalSlash)
            } else {
                let ease = 1.0 - pow(1.0 - p, 3.2)
                raw = TextUnitDelta(
                    offsetX: -(1.0 - ease) * (0.35 * em),
                    opacity: min(1.0, p * 4.5),
                    clipRevealX: ease,
                    maskShapeMode: .diagonalSlash,
                    trackingEmDelta: (1.0 - ease) * 0.14
                )
            }
            guard progress > 0.74 else { return raw }
            let t = (progress - 0.74) / 0.26
            return TextUnitDelta.lerp(raw, loopAt(progress), t: t * t * (3.0 - 2.0 * t))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.34
            let p = min(1.0, max(0.0, (progress - startP) / (1.0 - startP)))
            let ease = pow(p, 2.2)
            let outDelta = TextUnitDelta(
                offsetX: ease * (0.35 * em),
                opacity: 1.0 - ease,
                clipRevealX: max(0.0, 1.0 - ease),
                maskShapeMode: .diagonalSlash,
                trackingEmDelta: ease * 0.14
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: min(1.0, progress / 0.25))
        }
    }
}

// MARK: - Breakthrough 8: Center Split Reveal (Mở tách từ tâm thuần hình học)
public struct CenterSplitRevealScript: TextAnimationScript {
    public let id = "slide_center_split"
    public let displayName = "Center Split"
    public let description = "Symmetric horizontal mask expansion from center with tight letter tracking lock"
    public let category = TextAnimationCategory.fade
    public let tags: [TextAnimationTag] = [.fade]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 3.4)
            return TextUnitDelta(
                scaleX: 0.88 + 0.12 * ease,
                opacity: min(1.0, p * 4.5),
                clipRevealX: ease,
                maskShapeMode: .centerSplitX,
                trackingEmDelta: (1.0 - ease) * -0.10
            )
        case .loop(_, let cycleProgress):
            let breathe = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                scaleX: 1.0 + breathe * 0.025,
                scaleY: 1.0 + breathe * 0.025,
                opacity: 1.0,
                maskShapeMode: .centerSplitX,
                trackingEmDelta: breathe * 0.05
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 2.2)
            return TextUnitDelta(
                scaleX: 1.0 - ease * 0.12,
                opacity: 1.0 - ease,
                clipRevealX: max(0.0, 1.0 - ease),
                maskShapeMode: .centerSplitX,
                trackingEmDelta: -ease * 0.10
            )
        }
    }
}

// MARK: - Breakthrough 9: Kinetic Collision Slam (Đáp mạnh dồn lực đẩy các từ lân cận)
public struct KineticCollisionSlamScript: TextAnimationScript {
    public let id = "pop_collision_slam"
    public let displayName = "Collision Slam"
    public let description = "Heavy word impact squash with reactive horizontal shockwave preserving original text color"
    public let category = TextAnimationCategory.pop
    public let tags: [TextAnimationTag] = [.pop]
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let beat = pow(max(0.0, sin(prog * .pi * 2.0 - Double(unitIndex) * 0.7)), 3.0)
            return TextUnitDelta(
                offsetY: -beat * (0.08 * em),
                scaleX: 1.0 + beat * 0.10,
                scaleY: 1.0 - beat * 0.05,
                opacity: 1.0,
                trackingEmDelta: beat * 0.06
            )
        }
        switch phase {
        case .intro(let progress):
            let startP = (Double(unitIndex) / Double(total)) * 0.42
            let p = min(1.0, max(0.0, (progress - startP) / (1.0 - startP)))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(offsetY: -1.4 * em, scaleX: 0.75, scaleY: 1.35, opacity: 0.0, anchorOverride: .bottom)
            } else {
                let decay = exp(-p * 4.8) * (1.0 - p)
                let squash = decay * sin(p * .pi * 3.4) * 0.34
                let dropEase = 1.0 - pow(1.0 - min(1.0, p * 1.8), 3.0)
                raw = TextUnitDelta(
                    offsetY: (1.0 - dropEase) * (-1.4 * em),
                    scaleX: max(0.3, 1.0 + squash),
                    scaleY: max(0.3, 1.0 - squash * 0.85),
                    opacity: min(1.0, p * 5.0),
                    trackingEmDelta: max(0.0, squash) * 0.45,
                    anchorOverride: .bottom
                )
            }
            guard progress > 0.74 else { return raw }
            let t = (progress - 0.74) / 0.26
            return TextUnitDelta.lerp(raw, loopAt(progress), t: t * t * (3.0 - 2.0 * t))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let ease = pow(min(1.0, max(0.0, progress)), 2.2)
            let outDelta = TextUnitDelta(
                offsetY: ease * (1.2 * em),
                scaleX: 1.0 + ease * 0.18,
                scaleY: max(0.15, 1.0 - ease * 0.65),
                opacity: 1.0 - ease,
                anchorOverride: .bottom
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: min(1.0, progress / 0.25))
        }
    }
}
