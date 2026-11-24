import Foundation

/// Per-frame transform and visual shader delta output by a `StickerAnimationScript`.
/// Translation offsets (`offsetX`, `offsetY`) are resolution-independent fractions of sticker base size.
public struct StickerAnimationDelta: Sendable, Equatable {
    public var offsetX: Double
    public var offsetY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotation: Double
    public var skewX: Double
    public var skewY: Double
    public var opacity: Double
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var anchorPoint: StickerAnchorPoint
    public var echoCount: Int
    public var echoOffsetX: Double
    public var echoOffsetY: Double
    public var glowIntensity: Double
    public var blurRadius: Double
    public var glitchIntensity: Double

    public static let identity = StickerAnimationDelta()

    public init(
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        rotation: Double = 0.0,
        skewX: Double = 0.0,
        skewY: Double = 0.0,
        opacity: Double = 1.0,
        clipRevealX: Double = 1.0,
        clipRevealY: Double = 1.0,
        anchorPoint: StickerAnchorPoint = .center,
        echoCount: Int = 0,
        echoOffsetX: Double = 0.0,
        echoOffsetY: Double = 0.0,
        glowIntensity: Double = 0.0,
        blurRadius: Double = 0.0,
        glitchIntensity: Double = 0.0
    ) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
        self.skewX = skewX
        self.skewY = skewY
        self.opacity = opacity
        self.clipRevealX = clipRevealX
        self.clipRevealY = clipRevealY
        self.anchorPoint = anchorPoint
        self.echoCount = echoCount
        self.echoOffsetX = echoOffsetX
        self.echoOffsetY = echoOffsetY
        self.glowIntensity = glowIntensity
        self.blurRadius = blurRadius
        self.glitchIntensity = glitchIntensity
    }

    /// Linearly blends between `identity` (at `intensity = 0`) and this evaluated delta (at `intensity = 1+`).
    public func scaled(by intensity: Double) -> StickerAnimationDelta {
        let k = max(0.05, min(2.0, intensity))
        guard abs(k - 1.0) > 0.001 else { return self }
        var out = self
        out.offsetX = offsetX * k
        out.offsetY = offsetY * k
        out.scaleX = max(0.01, 1.0 + (scaleX - 1.0) * k)
        out.scaleY = max(0.01, 1.0 + (scaleY - 1.0) * k)
        out.rotation = rotation * k
        out.skewX = skewX * k
        out.skewY = skewY * k
        out.echoOffsetX = echoOffsetX * k
        out.echoOffsetY = echoOffsetY * k
        out.glowIntensity = max(0.0, min(1.5, glowIntensity * k))
        out.blurRadius = max(0.0, min(60.0, blurRadius * k))
        out.glitchIntensity = max(0.0, min(1.5, glitchIntensity * k))
        return out
    }
}
