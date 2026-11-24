import Foundation
import CoreGraphics
import Domain

/// Evaluates runtime transform and CoreImage shader parameters for Script-Driven Sticker Animations.
public enum StickerAnimationEvaluator: Sendable {
    public struct EvaluationResult: Sendable {
        public var positionX: Double
        public var positionY: Double
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

        public init(
            positionX: Double,
            positionY: Double,
            scaleX: Double,
            scaleY: Double,
            rotation: Double,
            skewX: Double = 0.0,
            skewY: Double = 0.0,
            opacity: Double,
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
            self.positionX = positionX
            self.positionY = positionY
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
    }

    /// Evaluates active `StickerAnimationConfiguration` at `localTime` across `Intro → Loop → Outro`.
    public static func evaluate(
        animation: StickerAnimationConfiguration,
        localTime: Double,
        clipDuration: Double,
        baseStickerSize: CGSize,
        positionX: Double,
        positionY: Double,
        scale: Double,
        rotation: Double,
        opacity: Double
    ) -> EvaluationResult {
        var result = EvaluationResult(
            positionX: positionX,
            positionY: positionY,
            scaleX: scale,
            scaleY: scale,
            rotation: rotation,
            opacity: opacity
        )
        guard animation.hasScriptAnimation,
              let script = StickerAnimationScriptRegistry.shared.script(for: animation.scriptId) else {
            return result
        }
        let rawDelta = script.evaluate(
            localTime: localTime,
            clipDuration: clipDuration,
            speed: animation.scriptSpeed,
            isBeatSyncEnabled: animation.isBeatSyncEnabled,
            beatBPM: animation.beatBPM,
            beatBarMode: animation.beatBarMode
        )
        let delta = rawDelta.scaled(by: animation.scriptIntensity)
        apply(delta: delta, baseScale: scale, baseStickerSize: baseStickerSize, to: &result)
        return result
    }

    private static func apply(
        delta: StickerAnimationDelta,
        baseScale: Double,
        baseStickerSize: CGSize,
        to result: inout EvaluationResult
    ) {
        let motionScale = max(0.25, baseScale)
        let refW = max(16.0, Double(baseStickerSize.width)) * motionScale
        let refH = max(16.0, Double(baseStickerSize.height)) * motionScale
        result.positionX += delta.offsetX * refW
        result.positionY += delta.offsetY * refH
        result.scaleX *= max(0.01, delta.scaleX)
        result.scaleY *= max(0.01, delta.scaleY)
        result.rotation += delta.rotation
        result.skewX = max(-0.8, min(0.8, delta.skewX))
        result.skewY = max(-0.8, min(0.8, delta.skewY))
        result.opacity = max(0.0, min(1.0, result.opacity * delta.opacity))
        result.clipRevealX = max(0.01, min(1.0, delta.clipRevealX))
        result.clipRevealY = max(0.01, min(1.0, delta.clipRevealY))
        result.anchorPoint = delta.anchorPoint
        result.echoCount = max(0, min(4, delta.echoCount))
        result.echoOffsetX = delta.echoOffsetX * refW
        result.echoOffsetY = delta.echoOffsetY * refH
        result.glowIntensity = delta.glowIntensity
        result.blurRadius = delta.blurRadius
        result.glitchIntensity = delta.glitchIntensity
    }
}
