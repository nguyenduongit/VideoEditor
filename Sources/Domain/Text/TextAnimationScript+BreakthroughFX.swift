import Foundation

// MARK: - Breakthrough 1: Vector Stroke Draw-On (Vẽ nét vector CGPath theo đúng màu Appearance)
public struct NeonStrokeDrawScript: TextAnimationScript {
    public let id = "typewriter_neon_draw"
    public let displayName = "Stroke Draw-On"
    public let description = "Traces vector letter outlines smoothly before revealing full Appearance fill"
    public let category = TextAnimationCategory.typewriter
    public let tags: [TextAnimationTag] = [.typewriter]
    public let scope = TextAnimationScope.wholeBlock

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = 1.0 - pow(1.0 - p, 2.2)
            return TextUnitDelta(
                opacity: min(1.0, p * 8.0),
                strokeTrimProgress: ease
            )
        case .loop(_, let cycleProgress):
            let breathe = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                scaleX: 1.0 + breathe * 0.025,
                scaleY: 1.0 + breathe * 0.025,
                opacity: 1.0,
                strokeTrimProgress: 1.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = pow(p, 1.7)
            return TextUnitDelta(
                opacity: max(0.0, 1.0 - pow(p, 3.0)),
                strokeTrimProgress: max(0.0, 1.0 - ease)
            )
        }
    }
}

// MARK: - Breakthrough 2: Cipher Matrix Decode (Giải mã ký tự ngẫu nhiên rồi khóa chữ)
public struct CipherMatrixDecodeScript: TextAnimationScript {
    public let id = "typewriter_cipher_decode"
    public let displayName = "Cipher Decode"
    public let description = "Scrambles glyphs cleanly before snapping into the target text with original colors"
    public let category = TextAnimationCategory.typewriter
    public let tags: [TextAnimationTag] = [.typewriter]
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let total = max(1, unitTotal)
        let normIdx = total > 1 ? Double(unitIndex) / Double(total - 1) : 0.0
        switch phase {
        case .intro(let progress):
            let startP = normIdx * 0.36
            guard progress > startP else { return TextUnitDelta(opacity: 0.0, scrambleStrength: 1.0) }
            let p = min(1.0, (progress - startP) / (1.0 - startP))
            let ease = 1.0 - pow(1.0 - p, 2.8)
            return TextUnitDelta(
                offsetY: (1.0 - ease) * (0.18 * em),
                scaleX: 0.85 + 0.15 * ease,
                scaleY: 1.12 - 0.12 * ease,
                opacity: min(1.0, p * 4.5),
                scrambleStrength: pow(1.0 - p, 1.5)
            )
        case .loop(_, let cycleProgress):
            let breathe = 0.5 - 0.5 * cos(cycleProgress * .pi * 2.0)
            return TextUnitDelta(
                offsetY: -breathe * (0.06 * em),
                opacity: 1.0,
                scrambleStrength: 0.0,
                trackingEmDelta: breathe * 0.03
            )
        case .outro(let progress):
            let startP = normIdx * 0.36
            let p = progress <= startP ? 0.0 : min(1.0, (progress - startP) / (1.0 - startP))
            return TextUnitDelta(
                offsetY: -p * (0.18 * em),
                opacity: max(0.0, 1.0 - pow(p, 1.9)),
                scrambleStrength: pow(p, 0.75)
            )
        }
    }
}
