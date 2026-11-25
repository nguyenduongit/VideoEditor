import Foundation
import Domain

/// Instantaneous kinematic, vector, 3D, and GPU shader overlay state for a text block or unit.
public struct TextTransformOverlay: Sendable, Equatable {
    public var scaleX: Double
    public var scaleY: Double
    public var skewX: Double
    public var rotationX: Double
    public var rotationY: Double
    public var perspectiveX: Double
    public var perspectiveY: Double
    public var motionBlurRadius: Double
    public var motionBlurAngle: Double
    public var liquidWavePhase: Double
    public var liquidMorphIntensity: Double
    public var revealProgress: Double
    public var trailingCursorOpacity: Double
    public var waveAmplitudeEm: Double
    public var waveFrequencyEm: Double
    public var wavePhaseRadians: Double
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var maskShapeMode: TextMaskShapeMode
    public var strokeTrimProgress: Double
    public var scrambleStrength: Double
    public var trackingEmDelta: Double
    public var echoCount: Int
    public var echoOffsetXEm: Double
    public var echoOffsetYEm: Double
    public var dissolveProgress: Double
    public var dissolveAngleRadians: Double
    public var offsetZEm: Double
    public var anchorPoint: TextAnchorPoint
    public var bevelDepth: Double
    public var bevelLightAngle: Double
    public var bevelExtrudeDepth: Double
    public var particleFieldProgress: Double
    public var particleFieldAngle: Double
    public var meshWarpMode: TextMeshWarpMode
    public var meshWarpAmount: Double
    public var meshWarpFrequency: Double
    public var meshWarpPhase: Double

    public init(
        scaleX: Double = 1.0, scaleY: Double = 1.0, skewX: Double = 0.0,
        offsetZEm: Double = 0.0, anchorPoint: TextAnchorPoint = .center,
        rotationX: Double = 0.0, rotationY: Double = 0.0,
        perspectiveX: Double = 0.0, perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0, motionBlurAngle: Double = 0.0,
        liquidWavePhase: Double = -1.0, liquidMorphIntensity: Double = 0.0,
        revealProgress: Double = -1.0, trailingCursorOpacity: Double = 0.0,
        waveAmplitudeEm: Double = 0.0, waveFrequencyEm: Double = 0.0, wavePhaseRadians: Double = 0.0,
        clipRevealX: Double = 1.0, clipRevealY: Double = 1.0, maskShapeMode: TextMaskShapeMode = .rect,
        strokeTrimProgress: Double = 1.0, scrambleStrength: Double = 0.0,
        trackingEmDelta: Double = 0.0, echoCount: Int = 0, echoOffsetXEm: Double = 0.0, echoOffsetYEm: Double = 0.0,
        dissolveProgress: Double = 0.0, dissolveAngleRadians: Double = -0.75,
        bevelDepth: Double = 0.0, bevelLightAngle: Double = 0.75,
        bevelExtrudeDepth: Double = 0.0,
        particleFieldProgress: Double = 0.0, particleFieldAngle: Double = -0.60,
        meshWarpMode: TextMeshWarpMode = .none, meshWarpAmount: Double = 0.0,
        meshWarpFrequency: Double = 1.5, meshWarpPhase: Double = 0.0
    ) {
        self.scaleX = scaleX; self.scaleY = scaleY; self.skewX = skewX
        self.offsetZEm = offsetZEm; self.anchorPoint = anchorPoint
        self.rotationX = rotationX; self.rotationY = rotationY
        self.perspectiveX = perspectiveX; self.perspectiveY = perspectiveY
        self.motionBlurRadius = motionBlurRadius; self.motionBlurAngle = motionBlurAngle
        self.liquidWavePhase = liquidWavePhase; self.liquidMorphIntensity = liquidMorphIntensity
        self.revealProgress = revealProgress; self.trailingCursorOpacity = trailingCursorOpacity
        self.waveAmplitudeEm = waveAmplitudeEm; self.waveFrequencyEm = waveFrequencyEm; self.wavePhaseRadians = wavePhaseRadians
        self.clipRevealX = clipRevealX; self.clipRevealY = clipRevealY; self.maskShapeMode = maskShapeMode
        self.strokeTrimProgress = strokeTrimProgress; self.scrambleStrength = scrambleStrength
        self.trackingEmDelta = trackingEmDelta
        self.echoCount = echoCount; self.echoOffsetXEm = echoOffsetXEm; self.echoOffsetYEm = echoOffsetYEm
        self.dissolveProgress = dissolveProgress; self.dissolveAngleRadians = dissolveAngleRadians
        self.bevelDepth = bevelDepth; self.bevelLightAngle = bevelLightAngle
        self.bevelExtrudeDepth = bevelExtrudeDepth
        self.particleFieldProgress = particleFieldProgress; self.particleFieldAngle = particleFieldAngle
        self.meshWarpMode = meshWarpMode; self.meshWarpAmount = meshWarpAmount
        self.meshWarpFrequency = meshWarpFrequency; self.meshWarpPhase = meshWarpPhase
    }
}
