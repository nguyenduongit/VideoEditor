import Foundation
import CoreGraphics
import Domain

/// Real-time Text Animation Engine driven by unified `TextAnimationGraph` and compiled `TextAnimationScript` blocks (`Intro -> Loop -> Outro`).
/// Enforces AGENTS.md Điều 14 (no detached In/Loop/Out runtime assembly).
public enum TextAnimationEvaluator {

    public struct EvaluationResult: Sendable {
        public var config: TextConfiguration
        public var blurRadius: Double
        public var pixelateScale: Double
        public var noiseIntensity: Double
        public var overlay: TextTransformOverlay
        /// Preserves evaluated graph channels (built-in & custom) for shaders and modular render plugins.
        public var animationParameters: TextAnimationParameterBag

        public init(
            config: TextConfiguration,
            blurRadius: Double = 0.0,
            pixelateScale: Double = 0.0,
            noiseIntensity: Double = 0.0,
            overlay: TextTransformOverlay = TextTransformOverlay(),
            animationParameters: TextAnimationParameterBag = TextAnimationParameterBag()
        ) {
            self.config = config
            self.blurRadius = blurRadius
            self.pixelateScale = pixelateScale
            self.noiseIntensity = noiseIntensity
            self.overlay = overlay
            self.animationParameters = animationParameters
        }
    }

    public static func evaluate(
        config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        charIndex: Int = 0,
        charCount: Int = 1,
        externalInputs: [String: Double] = [:]
    ) -> EvaluationResult {
        guard !config.animation.isDefault else {
            return EvaluationResult(config: config, noiseIntensity: config.noiseIntensity)
        }

        let anim = config.animation
        let safeDur = max(0.1, duration)
        let t = max(0.0, min(safeDur, localTime))

        if let graph = anim.graph {
            let mapped = TextAnimationGraphMapper.evaluate(
                graph: graph,
                baseConfig: config,
                t: t,
                totalDuration: safeDur,
                unitIndex: charIndex,
                unitCount: charCount,
                externalInputs: externalInputs
            )
            let delta = scaleScriptDelta(mapped.delta, intensity: anim.scriptIntensity)
            return assembleScriptResult(
                delta: delta,
                baseConfig: config,
                canvasSize: canvasSize,
                linearRevealProgress: mapped.linearRevealProgress,
                animationParameters: mapped.parameters
            )
        }

        if anim.hasScriptAnimation,
           let script = TextAnimationScriptRegistry.shared.script(for: anim.scriptId) {
            return evaluateScriptAnimation(
                script: script,
                baseConfig: config,
                canvasSize: canvasSize,
                t: t,
                totalDuration: safeDur,
                charIndex: charIndex,
                charCount: charCount
            )
        }

        return EvaluationResult(
            config: config,
            blurRadius: 0.0,
            pixelateScale: 0.0,
            noiseIntensity: config.noiseIntensity,
            overlay: TextTransformOverlay()
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
        return assembleScriptResult(delta: delta, baseConfig: baseConfig, canvasSize: canvasSize)
    }

    private static func assembleScriptResult(
        delta: TextUnitDelta,
        baseConfig: TextConfiguration,
        canvasSize: CGSize,
        linearRevealProgress: Double = -1.0,
        animationParameters: TextAnimationParameterBag = TextAnimationParameterBag()
    ) -> EvaluationResult {
        var evaluated = baseConfig
        var overlay = buildOverlay(from: delta, anim: baseConfig.animation)
        if linearRevealProgress >= 0.0 {
            overlay.revealProgress = max(0.0, min(1.0, linearRevealProgress))
        }
        let rawDx = delta.offsetX + delta.canvasOffsetXRatio * Double(canvasSize.width)
        let rawDy = delta.offsetY + delta.canvasOffsetYRatio * Double(canvasSize.height)
        let bounded = (baseConfig.background.isActive && !baseConfig.background.animateWithText)
            ? boundOffsetForFixedBackground(dx: rawDx, dy: rawDy, em: max(16.0, baseConfig.fontSize))
            : (dx: rawDx, dy: rawDy)

        evaluated.positionX += bounded.dx
        evaluated.positionY += bounded.dy
        overlay.scaleX *= delta.scaleX
        overlay.scaleY *= delta.scaleY
        evaluated.skewX += delta.skewX
        evaluated.skewY += delta.skewY
        evaluated.rotation += delta.rotation
        evaluated.opacity = max(0.0, min(1.0, evaluated.opacity * delta.opacity))
        if let anchorOverride = delta.anchorOverride { evaluated.animation.anchorPoint = anchorOverride }
        if delta.shadowDistanceDelta != 0.0, baseConfig.shadow.isActive {
            evaluated.shadow.distance = max(0.0, baseConfig.shadow.distance + delta.shadowDistanceDelta)
        }

        let effectiveNoise = max(baseConfig.noiseIntensity, delta.noiseIntensity)
        return EvaluationResult(
            config: evaluated,
            blurRadius: max(0.0, delta.blurRadius),
            pixelateScale: delta.pixelateScale,
            noiseIntensity: effectiveNoise,
            overlay: overlay,
            animationParameters: animationParameters
        )
    }

    private static func buildOverlay(from delta: TextUnitDelta, anim: TextAnimationConfiguration) -> TextTransformOverlay {
        var overlay = TextTransformOverlay()
        overlay.rotationX = delta.rotationX
        overlay.rotationY = delta.rotationY
        overlay.offsetZEm = delta.offsetZEm
        overlay.anchorPoint = delta.anchorOverride ?? anim.anchorPoint
        overlay.trailingCursorOpacity = anim.isTypewriterCursorVisible ? delta.trailingCursorOpacity : 0.0
        overlay.waveAmplitudeEm = delta.waveAmplitudeEm
        overlay.waveFrequencyEm = delta.waveFrequencyEm
        overlay.wavePhaseRadians = delta.wavePhaseRadians
        overlay.clipRevealX = delta.clipRevealX
        overlay.clipRevealY = delta.clipRevealY
        overlay.maskShapeMode = delta.maskShapeMode
        overlay.strokeTrimProgress = delta.strokeTrimProgress
        overlay.scrambleStrength = delta.scrambleStrength
        overlay.trackingEmDelta = delta.trackingEmDelta
        overlay.echoCount = delta.echoCount
        overlay.echoOffsetXEm = delta.echoOffsetXEm
        overlay.echoOffsetYEm = delta.echoOffsetYEm
        overlay.perspectiveX = delta.perspectiveX
        overlay.perspectiveY = delta.perspectiveY
        if anim.isMotionBlurEnabled && delta.motionBlurRadius > 0.5 {
            overlay.motionBlurRadius = delta.motionBlurRadius
            overlay.motionBlurAngle = delta.motionBlurAngle
        }
        overlay.liquidWavePhase = delta.liquidWavePhase
        overlay.liquidMorphIntensity = delta.liquidMorphIntensity
        overlay.dissolveProgress = delta.dissolveProgress
        overlay.dissolveAngleRadians = delta.dissolveAngleRadians
        overlay.bevelDepth = delta.bevelDepth
        overlay.bevelLightAngle = delta.bevelLightAngle
        overlay.bevelExtrudeDepth = delta.bevelExtrudeDepth
        overlay.particleFieldProgress = delta.particleFieldProgress
        overlay.particleFieldAngle = delta.particleFieldAngle
        overlay.meshWarpMode = delta.meshWarpMode
        overlay.meshWarpAmount = delta.meshWarpAmount
        overlay.meshWarpFrequency = delta.meshWarpFrequency
        overlay.meshWarpPhase = delta.meshWarpPhase
        return overlay
    }

    private static func scaleScriptDelta(_ d: TextUnitDelta, intensity: Double) -> TextUnitDelta {
        let amp = max(0.2, min(2.0, intensity))
        guard abs(amp - 1.0) > 0.001 else { return d }
        return TextUnitDelta(
            offsetX: d.offsetX * amp, offsetY: d.offsetY * amp, offsetZEm: d.offsetZEm * amp,
            canvasOffsetXRatio: d.canvasOffsetXRatio, canvasOffsetYRatio: d.canvasOffsetYRatio,
            scaleX: max(0.02, 1.0 + (d.scaleX - 1.0) * amp), scaleY: max(0.02, 1.0 + (d.scaleY - 1.0) * amp),
            rotation: d.rotation * amp, rotationX: d.rotationX * amp, rotationY: d.rotationY * amp,
            skewX: d.skewX * amp, skewY: d.skewY * amp,
            opacity: d.opacity, trailingCursorOpacity: d.trailingCursorOpacity,
            waveAmplitudeEm: d.waveAmplitudeEm * amp, waveFrequencyEm: d.waveFrequencyEm, wavePhaseRadians: d.wavePhaseRadians,
            clipRevealX: d.clipRevealX, clipRevealY: d.clipRevealY, maskShapeMode: d.maskShapeMode,
            strokeTrimProgress: d.strokeTrimProgress, scrambleStrength: d.scrambleStrength,
            trackingEmDelta: d.trackingEmDelta * amp, anchorOverride: d.anchorOverride,
            echoCount: d.echoCount, echoOffsetXEm: d.echoOffsetXEm * amp, echoOffsetYEm: d.echoOffsetYEm * amp,
            shadowDistanceDelta: d.shadowDistanceDelta * amp,
            blurRadius: d.blurRadius * amp, noiseIntensity: d.noiseIntensity * amp,
            perspectiveX: max(-0.85, min(0.85, d.perspectiveX * amp)), perspectiveY: max(-0.85, min(0.85, d.perspectiveY * amp)),
            motionBlurRadius: d.motionBlurRadius * amp, motionBlurAngle: d.motionBlurAngle,
            liquidWavePhase: d.liquidWavePhase, liquidMorphIntensity: d.liquidMorphIntensity * amp,
            pixelateScale: d.pixelateScale > 1.0 ? 1.0 + (d.pixelateScale - 1.0) * amp : d.pixelateScale,
            dissolveProgress: d.dissolveProgress, dissolveAngleRadians: d.dissolveAngleRadians,
            bevelDepth: d.bevelDepth * amp, bevelLightAngle: d.bevelLightAngle,
            bevelExtrudeDepth: d.bevelExtrudeDepth * amp,
            particleFieldProgress: d.particleFieldProgress, particleFieldAngle: d.particleFieldAngle,
            meshWarpMode: d.meshWarpMode,
            meshWarpAmount: max(-2.0, min(2.0, d.meshWarpAmount * amp)),
            meshWarpFrequency: d.meshWarpFrequency,
            meshWarpPhase: d.meshWarpPhase
        )
    }

    public static func boundOffsetForFixedBackground(dx: Double, dy: Double, em: Double) -> (dx: Double, dy: Double) {
        let maxDx = em * 0.48, maxDy = em * 0.36
        return (maxDx > 0 ? maxDx * tanh(dx / maxDx) : dx, maxDy > 0 ? maxDy * tanh(dy / maxDy) : dy)
    }
}
