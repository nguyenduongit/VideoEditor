import Foundation

/// Per-unit (character, word, line, or whole block) kinematic, vector, 3D, and Metal GPU shader delta.
public struct TextUnitDelta: Sendable, Equatable {
    // MARK: - 1. Transform & Cursor Delta (Pure Kinematics)
    public var offsetX: Double
    public var offsetY: Double
    public var canvasOffsetXRatio: Double
    public var canvasOffsetYRatio: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotation: Double
    public var rotationX: Double
    public var rotationY: Double
    public var skewX: Double
    public var skewY: Double
    public var opacity: Double
    public var trailingCursorOpacity: Double

    // MARK: - 1b. Continuous Spatial Wave Path
    public var waveAmplitudeEm: Double
    public var waveFrequencyEm: Double
    public var wavePhaseRadians: Double

    // MARK: - 1c. Vector Trim, Cipher Scramble, Mask, Tracking, Hinge Pivot & Echo Trail
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var maskShapeMode: TextMaskShapeMode
    public var strokeTrimProgress: Double
    public var scrambleStrength: Double
    public var trackingEmDelta: Double
    public var anchorOverride: TextAnchorPoint?
    public var echoCount: Int
    public var echoOffsetXEm: Double
    public var echoOffsetYEm: Double

    // MARK: - 2. Relative Optical Effects Delta
    public var glowIntensityDelta: Double
    public var shadowDistanceDelta: Double
    public var blurRadius: Double
    public var glitchIntensity: Double
    public var noiseIntensity: Double

    // MARK: - 3. GPU Shader Channels (CoreImage + Metal Compute Kernels)
    public var perspectiveX: Double
    public var perspectiveY: Double
    public var motionBlurRadius: Double
    public var motionBlurAngle: Double
    public var lightSweepPhase: Double
    public var sweepWidthRatio: Double
    public var liquidWavePhase: Double
    public var liquidMorphIntensity: Double
    public var glitchSliceIntensity: Double
    public var glitchBlockIntensity: Double
    public var pixelateScale: Double
    public var dissolveProgress: Double
    public var dissolveAngleRadians: Double
    public var bloomIntensity: Double

    // MARK: - 4. Super-Engine Pure Geometric Relief, Particle Field & Luminance Rays
    public var bevelDepth: Double
    public var bevelLightAngle: Double
    public var bevelExtrudeDepth: Double
    public var particleFieldProgress: Double
    public var particleFieldAngle: Double
    public var volumetricRaysIntensity: Double
    public var volumetricRaysOriginX: Double
    public var volumetricRaysOriginY: Double

    public init(
        offsetX: Double = 0.0, offsetY: Double = 0.0,
        canvasOffsetXRatio: Double = 0.0, canvasOffsetYRatio: Double = 0.0,
        scaleX: Double = 1.0, scaleY: Double = 1.0,
        rotation: Double = 0.0, rotationX: Double = 0.0, rotationY: Double = 0.0,
        skewX: Double = 0.0, skewY: Double = 0.0,
        opacity: Double = 1.0, trailingCursorOpacity: Double = 0.0,
        waveAmplitudeEm: Double = 0.0, waveFrequencyEm: Double = 0.0, wavePhaseRadians: Double = 0.0,
        clipRevealX: Double = 1.0, clipRevealY: Double = 1.0, maskShapeMode: TextMaskShapeMode = .rect,
        strokeTrimProgress: Double = 1.0, scrambleStrength: Double = 0.0,
        trackingEmDelta: Double = 0.0, anchorOverride: TextAnchorPoint? = nil,
        echoCount: Int = 0, echoOffsetXEm: Double = 0.0, echoOffsetYEm: Double = 0.0,
        glowIntensityDelta: Double = 0.0, shadowDistanceDelta: Double = 0.0,
        blurRadius: Double = 0.0, glitchIntensity: Double = 0.0, noiseIntensity: Double = 0.0,
        perspectiveX: Double = 0.0, perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0, motionBlurAngle: Double = 0.0,
        lightSweepPhase: Double = -1.0, sweepWidthRatio: Double = 0.16,
        liquidWavePhase: Double = -1.0, liquidMorphIntensity: Double = 0.0,
        glitchSliceIntensity: Double = 0.0, glitchBlockIntensity: Double = 0.0,
        pixelateScale: Double = 0.0,
        dissolveProgress: Double = 0.0, dissolveAngleRadians: Double = -0.75,
        bloomIntensity: Double = 0.0,
        bevelDepth: Double = 0.0, bevelLightAngle: Double = 0.75,
        bevelExtrudeDepth: Double = 0.0,
        particleFieldProgress: Double = 0.0, particleFieldAngle: Double = -0.60,
        volumetricRaysIntensity: Double = 0.0, volumetricRaysOriginX: Double = 0.5, volumetricRaysOriginY: Double = 0.65
    ) {
        self.offsetX = offsetX; self.offsetY = offsetY
        self.canvasOffsetXRatio = canvasOffsetXRatio; self.canvasOffsetYRatio = canvasOffsetYRatio
        self.scaleX = scaleX; self.scaleY = scaleY
        self.rotation = rotation; self.rotationX = rotationX; self.rotationY = rotationY
        self.skewX = skewX; self.skewY = skewY
        self.opacity = max(0.0, min(1.0, opacity))
        self.trailingCursorOpacity = max(0.0, min(1.0, trailingCursorOpacity))
        self.waveAmplitudeEm = waveAmplitudeEm; self.waveFrequencyEm = waveFrequencyEm; self.wavePhaseRadians = wavePhaseRadians
        self.clipRevealX = max(0.0, min(1.0, clipRevealX)); self.clipRevealY = max(0.0, min(1.0, clipRevealY))
        self.maskShapeMode = maskShapeMode
        self.strokeTrimProgress = max(0.0, min(1.0, strokeTrimProgress))
        self.scrambleStrength = max(0.0, min(1.0, scrambleStrength))
        self.trackingEmDelta = trackingEmDelta; self.anchorOverride = anchorOverride
        self.echoCount = max(0, min(3, echoCount)); self.echoOffsetXEm = echoOffsetXEm; self.echoOffsetYEm = echoOffsetYEm
        self.glowIntensityDelta = glowIntensityDelta; self.shadowDistanceDelta = shadowDistanceDelta
        self.blurRadius = max(0.0, blurRadius)
        self.glitchIntensity = max(0.0, min(100.0, glitchIntensity)); self.noiseIntensity = max(0.0, min(100.0, noiseIntensity))
        self.perspectiveX = max(-0.85, min(0.85, perspectiveX)); self.perspectiveY = max(-0.85, min(0.85, perspectiveY))
        self.motionBlurRadius = max(0.0, min(45.0, motionBlurRadius)); self.motionBlurAngle = motionBlurAngle
        self.lightSweepPhase = lightSweepPhase; self.sweepWidthRatio = max(0.04, min(0.5, sweepWidthRatio))
        self.liquidWavePhase = liquidWavePhase; self.liquidMorphIntensity = max(0.0, min(2.0, liquidMorphIntensity))
        self.glitchSliceIntensity = max(0.0, glitchSliceIntensity); self.glitchBlockIntensity = max(0.0, min(2.0, glitchBlockIntensity))
        self.pixelateScale = max(0.0, pixelateScale)
        self.dissolveProgress = max(0.0, min(1.0, dissolveProgress)); self.dissolveAngleRadians = dissolveAngleRadians
        self.bloomIntensity = max(0.0, min(2.0, bloomIntensity))
        self.bevelDepth = max(0.0, min(24.0, bevelDepth))
        self.bevelLightAngle = bevelLightAngle
        self.bevelExtrudeDepth = max(0.0, min(24.0, bevelExtrudeDepth))
        self.particleFieldProgress = max(0.0, min(1.0, particleFieldProgress))
        self.particleFieldAngle = particleFieldAngle
        self.volumetricRaysIntensity = max(0.0, min(2.0, volumetricRaysIntensity))
        self.volumetricRaysOriginX = max(0.0, min(1.0, volumetricRaysOriginX))
        self.volumetricRaysOriginY = max(0.0, min(1.0, volumetricRaysOriginY))
    }

    public static let identity = TextUnitDelta()

    /// Smooth linear interpolation between two deltas to guarantee exact phase-boundary continuity.
    public static func lerp(_ a: TextUnitDelta, _ b: TextUnitDelta, t: Double) -> TextUnitDelta {
        let k = max(0.0, min(1.0, t))
        let inv = 1.0 - k
        let sweepP = (a.lightSweepPhase >= 0 && b.lightSweepPhase >= 0) ? (inv * a.lightSweepPhase + k * b.lightSweepPhase) : (k > 0.5 ? b.lightSweepPhase : a.lightSweepPhase)
        let liqP = (a.liquidWavePhase >= 0 && b.liquidWavePhase >= 0) ? (inv * a.liquidWavePhase + k * b.liquidWavePhase) : (k > 0.5 ? b.liquidWavePhase : a.liquidWavePhase)
        return TextUnitDelta(
            offsetX: inv * a.offsetX + k * b.offsetX, offsetY: inv * a.offsetY + k * b.offsetY,
            canvasOffsetXRatio: inv * a.canvasOffsetXRatio + k * b.canvasOffsetXRatio,
            canvasOffsetYRatio: inv * a.canvasOffsetYRatio + k * b.canvasOffsetYRatio,
            scaleX: inv * a.scaleX + k * b.scaleX, scaleY: inv * a.scaleY + k * b.scaleY,
            rotation: inv * a.rotation + k * b.rotation, rotationX: inv * a.rotationX + k * b.rotationX, rotationY: inv * a.rotationY + k * b.rotationY,
            skewX: inv * a.skewX + k * b.skewX, skewY: inv * a.skewY + k * b.skewY,
            opacity: inv * a.opacity + k * b.opacity, trailingCursorOpacity: inv * a.trailingCursorOpacity + k * b.trailingCursorOpacity,
            waveAmplitudeEm: inv * a.waveAmplitudeEm + k * b.waveAmplitudeEm, waveFrequencyEm: inv * a.waveFrequencyEm + k * b.waveFrequencyEm,
            wavePhaseRadians: inv * a.wavePhaseRadians + k * b.wavePhaseRadians,
            clipRevealX: inv * a.clipRevealX + k * b.clipRevealX, clipRevealY: inv * a.clipRevealY + k * b.clipRevealY,
            maskShapeMode: k > 0.5 ? b.maskShapeMode : a.maskShapeMode,
            strokeTrimProgress: inv * a.strokeTrimProgress + k * b.strokeTrimProgress, scrambleStrength: inv * a.scrambleStrength + k * b.scrambleStrength,
            trackingEmDelta: inv * a.trackingEmDelta + k * b.trackingEmDelta,
            anchorOverride: k > 0.5 ? (b.anchorOverride ?? a.anchorOverride) : (a.anchorOverride ?? b.anchorOverride),
            echoCount: k > 0.5 ? b.echoCount : a.echoCount,
            echoOffsetXEm: inv * a.echoOffsetXEm + k * b.echoOffsetXEm, echoOffsetYEm: inv * a.echoOffsetYEm + k * b.echoOffsetYEm,
            glowIntensityDelta: inv * a.glowIntensityDelta + k * b.glowIntensityDelta,
            shadowDistanceDelta: inv * a.shadowDistanceDelta + k * b.shadowDistanceDelta,
            blurRadius: inv * a.blurRadius + k * b.blurRadius, glitchIntensity: inv * a.glitchIntensity + k * b.glitchIntensity,
            noiseIntensity: inv * a.noiseIntensity + k * b.noiseIntensity,
            perspectiveX: inv * a.perspectiveX + k * b.perspectiveX, perspectiveY: inv * a.perspectiveY + k * b.perspectiveY,
            motionBlurRadius: inv * a.motionBlurRadius + k * b.motionBlurRadius, motionBlurAngle: inv * a.motionBlurAngle + k * b.motionBlurAngle,
            lightSweepPhase: sweepP, sweepWidthRatio: inv * a.sweepWidthRatio + k * b.sweepWidthRatio,
            liquidWavePhase: liqP, liquidMorphIntensity: inv * a.liquidMorphIntensity + k * b.liquidMorphIntensity,
            glitchSliceIntensity: inv * a.glitchSliceIntensity + k * b.glitchSliceIntensity,
            glitchBlockIntensity: inv * a.glitchBlockIntensity + k * b.glitchBlockIntensity,
            pixelateScale: inv * a.pixelateScale + k * b.pixelateScale,
            dissolveProgress: inv * a.dissolveProgress + k * b.dissolveProgress, dissolveAngleRadians: inv * a.dissolveAngleRadians + k * b.dissolveAngleRadians,
            bloomIntensity: inv * a.bloomIntensity + k * b.bloomIntensity,
            bevelDepth: inv * a.bevelDepth + k * b.bevelDepth, bevelLightAngle: inv * a.bevelLightAngle + k * b.bevelLightAngle,
            bevelExtrudeDepth: inv * a.bevelExtrudeDepth + k * b.bevelExtrudeDepth,
            particleFieldProgress: inv * a.particleFieldProgress + k * b.particleFieldProgress, particleFieldAngle: inv * a.particleFieldAngle + k * b.particleFieldAngle,
            volumetricRaysIntensity: inv * a.volumetricRaysIntensity + k * b.volumetricRaysIntensity,
            volumetricRaysOriginX: inv * a.volumetricRaysOriginX + k * b.volumetricRaysOriginX,
            volumetricRaysOriginY: inv * a.volumetricRaysOriginY + k * b.volumetricRaysOriginY
        )
    }
}
