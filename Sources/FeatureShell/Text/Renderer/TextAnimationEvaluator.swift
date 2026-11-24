import Foundation
import CoreGraphics
import Domain

/// Tham số biến dạng hình học & VFX tức thời của hoạt ảnh (Scale X/Y, Skew, 3D Perspective, Motion Blur, Light Sweep).
public struct TextTransformOverlay: Sendable, Equatable {
    public var scaleX: Double
    public var scaleY: Double
    public var skewX: Double
    public var perspectiveX: Double
    public var perspectiveY: Double
    public var motionBlurRadius: Double
    public var motionBlurAngle: Double
    public var lightSweepPhase: Double
    public var glitchSliceIntensity: Double
    public var liquidWavePhase: Double
    public var revealProgress: Double
    public var trailingCursorOpacity: Double
    public var waveAmplitudeEm: Double
    public var waveFrequencyEm: Double
    public var wavePhaseRadians: Double
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var trackingEmDelta: Double
    public var echoCount: Int
    public var echoOffsetXEm: Double
    public var echoOffsetYEm: Double

    public init(
        scaleX: Double = 1.0, scaleY: Double = 1.0, skewX: Double = 0.0,
        perspectiveX: Double = 0.0, perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0, motionBlurAngle: Double = 0.0,
        lightSweepPhase: Double = -1.0, glitchSliceIntensity: Double = 0.0,
        liquidWavePhase: Double = -1.0, revealProgress: Double = -1.0,
        trailingCursorOpacity: Double = 0.0,
        waveAmplitudeEm: Double = 0.0, waveFrequencyEm: Double = 0.0, wavePhaseRadians: Double = 0.0,
        clipRevealX: Double = 1.0, clipRevealY: Double = 1.0, trackingEmDelta: Double = 0.0,
        echoCount: Int = 0, echoOffsetXEm: Double = 0.0, echoOffsetYEm: Double = 0.0
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.skewX = skewX
        self.perspectiveX = perspectiveX
        self.perspectiveY = perspectiveY
        self.motionBlurRadius = motionBlurRadius
        self.motionBlurAngle = motionBlurAngle
        self.lightSweepPhase = lightSweepPhase
        self.glitchSliceIntensity = glitchSliceIntensity
        self.liquidWavePhase = liquidWavePhase
        self.revealProgress = revealProgress
        self.trailingCursorOpacity = trailingCursorOpacity
        self.waveAmplitudeEm = waveAmplitudeEm
        self.waveFrequencyEm = waveFrequencyEm
        self.wavePhaseRadians = wavePhaseRadians
        self.clipRevealX = clipRevealX
        self.clipRevealY = clipRevealY
        self.trackingEmDelta = trackingEmDelta
        self.echoCount = echoCount
        self.echoOffsetXEm = echoOffsetXEm
        self.echoOffsetYEm = echoOffsetYEm
    }
}

/// Real-time Text Animation Engine driven exclusively by unified `TextAnimationScript` blocks (`Intro -> Loop -> Outro`).
/// Enforces AGENTS.md Điều 14 (no detached In/Loop/Out runtime assembly).
public enum TextAnimationEvaluator {

    public struct EvaluationResult: Sendable {
        public var config: TextConfiguration
        public var blurRadius: Double
        public var hueAngle: Double
        public var pixelateScale: Double
        public var rgbSplitIntensity: Double
        public var overlay: TextTransformOverlay

        public init(
            config: TextConfiguration, blurRadius: Double = 0.0, hueAngle: Double = 0.0,
            pixelateScale: Double = 0.0, rgbSplitIntensity: Double = 0.0,
            overlay: TextTransformOverlay = TextTransformOverlay()
        ) {
            self.config = config
            self.blurRadius = blurRadius
            self.hueAngle = hueAngle
            self.pixelateScale = pixelateScale
            self.rgbSplitIntensity = rgbSplitIntensity
            self.overlay = overlay
        }
    }

    /// Evaluates continuous unified script animation (or passive shader modifiers) at `localTime`.
    public static func evaluate(
        config: TextConfiguration, localTime: Double, duration: Double,
        canvasSize: CGSize, charIndex: Int = 0, charCount: Int = 1
    ) -> EvaluationResult {
        guard !config.animation.isDefault else { return EvaluationResult(config: config) }

        let anim = config.animation
        let safeDur = max(0.1, duration)
        let t = max(0.0, min(safeDur, localTime))

        if anim.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: anim.scriptId) {
            return evaluateScriptAnimation(
                script: script, baseConfig: config, canvasSize: canvasSize, t: t,
                totalDuration: safeDur, charIndex: charIndex, charCount: charCount
            )
        }

        var overlay = TextTransformOverlay()
        if anim.lightSweepIntensity > 0.01 {
            overlay.lightSweepPhase = (t * max(0.2, anim.scriptSpeed) * 0.7).truncatingRemainder(dividingBy: 1.0)
        }
        return EvaluationResult(
            config: config, blurRadius: 0.0, hueAngle: 0.0,
            pixelateScale: 0.0, rgbSplitIntensity: anim.rgbSplitIntensity, overlay: overlay
        )
    }

    private static func evaluateScriptAnimation(
        script: any TextAnimationScript,
        baseConfig: TextConfiguration,
        canvasSize: CGSize,
        t: Double,
        totalDuration: Double,
        charIndex: Int,
        charCount: Int
    ) -> EvaluationResult {
        let anim = baseConfig.animation
        let effectiveIndex = (charCount > 1 && anim.staggerDirection != .forward)
            ? max(0, min(charCount - 1, Int(TextAnimationCurves.staggerOrderIndex(
                index: charIndex, count: charCount, direction: anim.staggerDirection
            ).rounded())))
            : charIndex
        let phase = script.resolvePhase(anim: anim, localTime: t, duration: totalDuration)
        let rawDelta = script.evaluatePhase(base: baseConfig, phase: phase, unitIndex: effectiveIndex, unitTotal: charCount)
        let delta = scaleScriptDelta(rawDelta, intensity: anim.scriptIntensity)
        return assembleScriptResult(delta: delta, baseConfig: baseConfig, canvasSize: canvasSize, t: t)
    }

    private static func assembleScriptResult(
        delta: TextUnitDelta,
        baseConfig: TextConfiguration,
        canvasSize: CGSize,
        t: Double
    ) -> EvaluationResult {
        var evaluated = baseConfig
        var overlay = TextTransformOverlay()
        let anim = baseConfig.animation
        let rawDx = delta.offsetX + delta.canvasOffsetXRatio * Double(canvasSize.width)
        let rawDy = delta.offsetY + delta.canvasOffsetYRatio * Double(canvasSize.height)
        let bounded = (baseConfig.background.isActive && !baseConfig.background.animateWithText)
            ? boundOffsetForFixedBackground(dx: rawDx, dy: rawDy, em: max(16.0, baseConfig.fontSize))
            : (dx: rawDx, dy: rawDy)

        evaluated.positionX += bounded.dx; evaluated.positionY += bounded.dy
        overlay.scaleX *= delta.scaleX; overlay.scaleY *= delta.scaleY
        evaluated.skewX += delta.skewX; evaluated.skewY += delta.skewY
        evaluated.rotation += delta.rotation
        evaluated.opacity = max(0.0, min(1.0, evaluated.opacity * delta.opacity))
        overlay.trailingCursorOpacity = delta.trailingCursorOpacity
        overlay.waveAmplitudeEm = delta.waveAmplitudeEm
        overlay.waveFrequencyEm = delta.waveFrequencyEm
        overlay.wavePhaseRadians = delta.wavePhaseRadians
        overlay.clipRevealX = delta.clipRevealX; overlay.clipRevealY = delta.clipRevealY
        overlay.trackingEmDelta = delta.trackingEmDelta
        overlay.echoCount = delta.echoCount
        overlay.echoOffsetXEm = delta.echoOffsetXEm; overlay.echoOffsetYEm = delta.echoOffsetYEm
        overlay.perspectiveX = delta.perspectiveX
        overlay.perspectiveY = delta.perspectiveY
        if anim.isMotionBlurEnabled && delta.motionBlurRadius > 0.5 {
            overlay.motionBlurRadius = delta.motionBlurRadius
            overlay.motionBlurAngle = delta.motionBlurAngle
        }
        overlay.liquidWavePhase = delta.liquidWavePhase
        overlay.glitchSliceIntensity = delta.glitchSliceIntensity
        if let anchorOverride = delta.anchorOverride { evaluated.animation.anchorPoint = anchorOverride }
        if delta.lightSweepPhase >= 0.0 {
            overlay.lightSweepPhase = delta.lightSweepPhase
        } else if anim.lightSweepIntensity > 0.01 {
            overlay.lightSweepPhase = (t * max(0.2, anim.scriptSpeed) * 0.7).truncatingRemainder(dividingBy: 1.0)
        }
        if delta.glowIntensityDelta != 0.0, baseConfig.glow.isActive {
            evaluated.glow.intensity = max(0.0, min(100.0, baseConfig.glow.intensity + delta.glowIntensityDelta))
        }
        if delta.shadowDistanceDelta != 0.0, baseConfig.shadow.isActive {
            evaluated.shadow.distance = max(0.0, baseConfig.shadow.distance + delta.shadowDistanceDelta)
        }
        return EvaluationResult(
            config: evaluated, blurRadius: max(0.0, delta.blurRadius), hueAngle: delta.hueAngle,
            pixelateScale: delta.pixelateScale, rgbSplitIntensity: max(anim.rgbSplitIntensity, delta.glitchIntensity), overlay: overlay
        )
    }

    private static func scaleScriptDelta(_ d: TextUnitDelta, intensity: Double) -> TextUnitDelta {
        let amp = max(0.2, min(2.0, intensity))
        guard abs(amp - 1.0) > 0.001 else { return d }
        return TextUnitDelta(
            offsetX: d.offsetX * amp,
            offsetY: d.offsetY * amp,
            canvasOffsetXRatio: d.canvasOffsetXRatio,
            canvasOffsetYRatio: d.canvasOffsetYRatio,
            scaleX: max(0.02, 1.0 + (d.scaleX - 1.0) * amp),
            scaleY: max(0.02, 1.0 + (d.scaleY - 1.0) * amp),
            rotation: d.rotation * amp,
            skewX: d.skewX * amp,
            skewY: d.skewY * amp,
            opacity: d.opacity,
            trailingCursorOpacity: d.trailingCursorOpacity,
            waveAmplitudeEm: d.waveAmplitudeEm * amp,
            waveFrequencyEm: d.waveFrequencyEm,
            wavePhaseRadians: d.wavePhaseRadians,
            clipRevealX: d.clipRevealX,
            clipRevealY: d.clipRevealY,
            trackingEmDelta: d.trackingEmDelta * amp,
            anchorOverride: d.anchorOverride,
            echoCount: d.echoCount,
            echoOffsetXEm: d.echoOffsetXEm * amp,
            echoOffsetYEm: d.echoOffsetYEm * amp,
            glowIntensityDelta: d.glowIntensityDelta * amp,
            shadowDistanceDelta: d.shadowDistanceDelta * amp,
            blurRadius: d.blurRadius * amp,
            glitchIntensity: d.glitchIntensity * amp,
            noiseIntensity: d.noiseIntensity * amp,
            perspectiveX: max(-0.85, min(0.85, d.perspectiveX * amp)),
            perspectiveY: max(-0.85, min(0.85, d.perspectiveY * amp)),
            motionBlurRadius: d.motionBlurRadius * amp,
            motionBlurAngle: d.motionBlurAngle,
            lightSweepPhase: d.lightSweepPhase,
            liquidWavePhase: d.liquidWavePhase,
            glitchSliceIntensity: d.glitchSliceIntensity * amp,
            pixelateScale: d.pixelateScale > 1.0 ? 1.0 + (d.pixelateScale - 1.0) * amp : d.pixelateScale,
            hueAngle: d.hueAngle * amp
        )
    }

    public static func boundOffsetForFixedBackground(dx: Double, dy: Double, em: Double) -> (dx: Double, dy: Double) {
        let maxDx = em * 0.48, maxDy = em * 0.36
        return (maxDx > 0 ? maxDx * tanh(dx / maxDx) : dx, maxDy > 0 ? maxDy * tanh(dy / maxDy) : dy)
    }
}
