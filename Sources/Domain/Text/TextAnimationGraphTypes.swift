import Foundation

/// Phase filter for data-driven animation graph tracks within the continuous `Intro -> Loop -> Outro` lifecycle.
public enum TextAnimationGraphPhase: String, Codable, Hashable, Sendable {
    case any
    case intro
    case loop
    case outro
}

/// Composition mode for combining multiple tracks or layers writing to the same parameter channel.
public enum TextAnimationBlendMode: String, Codable, Hashable, Sendable {
    case replace
    case add
    case subtract
    case multiply
    case minimum
    case maximum
    case screen
}

/// Normalized time input sampled by procedural graph nodes.
public enum TextAnimationTimeSource: String, Codable, Hashable, Sendable {
    case globalProgress
    case phaseProgress
    case loopProgress
    case elapsedSeconds
}

/// Waveform shapes supported by procedural oscillator nodes.
public enum TextAnimationWaveform: String, Codable, Hashable, Sendable {
    case sine
    case triangle
    case sawtooth
    case square
    case pulse
}

/// Segment easing curve between adjacent keyframes in a keyframe track.
public enum TextAnimationInterpolation: Codable, Hashable, Sendable {
    case linear
    case hold
    case smooth
    case easeIn
    case easeOut
    case easeInOut
    case cubicBezier(x1: Double, y1: Double, x2: Double, y2: Double)
}

/// A scalar keyframe point along a normalized or second-based timeline.
public struct TextAnimationKeyframe: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var time: Double
    public var value: Double
    public var interpolationToNext: TextAnimationInterpolation

    public init(
        id: String = UUID().uuidString,
        time: Double,
        value: Double,
        interpolationToNext: TextAnimationInterpolation = .linear
    ) {
        self.id = id
        self.time = time
        self.value = value
        self.interpolationToNext = interpolationToNext
    }
}

/// Post-evaluation unary transform stacked on a track before channel blending.
public enum TextAnimationModifier: Codable, Hashable, Sendable {
    case add(Double)
    case multiply(Double)
    case power(Double)
    case absolute
    case invert
    case clamp(minimum: Double, maximum: Double)
    case quantize(steps: Double)

    public func apply(to input: Double) -> Double {
        switch self {
        case .add(let value): return input + value
        case .multiply(let value): return input * value
        case .power(let exponent): return pow(max(0.0, input), exponent)
        case .absolute: return abs(input)
        case .invert: return 1.0 - input
        case .clamp(let minimum, let maximum): return min(maximum, max(minimum, input))
        case .quantize(let steps):
            let safeSteps = max(1.0, steps)
            return (input * safeSteps).rounded() / safeSteps
        }
    }
}

/// Canonical string keys for built-in graph channels and runtime external inputs (Single Source of Truth).
public enum TextAnimationChannel: Sendable {
    public static let positionX = "transform.position.x"
    public static let positionY = "transform.position.y"
    public static let canvasOffsetX = "transform.canvasOffset.x"
    public static let canvasOffsetY = "transform.canvasOffset.y"
    public static let scaleX = "transform.scale.x"
    public static let scaleY = "transform.scale.y"
    public static let rotation = "transform.rotation"
    public static let rotationX = "transform.rotationX"
    public static let rotationY = "transform.rotationY"
    public static let skewX = "transform.skew.x"
    public static let skewY = "transform.skew.y"
    public static let perspectiveX = "transform.perspective.x"
    public static let perspectiveY = "transform.perspective.y"
    public static let opacity = "transform.opacity"
    public static let anchor = "transform.anchor"

    public static let waveAmplitude = "geometry.wave.amplitude"
    public static let waveFrequency = "geometry.wave.frequency"
    public static let wavePhase = "geometry.wave.phase"

    public static let maskRevealX = "mask.reveal.x"
    public static let maskRevealY = "mask.reveal.y"
    public static let maskRevealLinear = "mask.reveal.linear"
    public static let maskShape = "mask.shape"

    public static let pathTrimProgress = "path.trim.progress"
    public static let textScramble = "text.scramble"
    public static let textTracking = "text.tracking"
    public static let trailingCursorOpacity = "text.cursor.opacity"

    public static let echoCount = "effects.echo.count"
    public static let echoOffsetX = "effects.echo.offset.x"
    public static let echoOffsetY = "effects.echo.offset.y"
    public static let glowIntensity = "effects.glow.intensity"
    public static let shadowDistance = "effects.shadow.distance"
    public static let blurRadius = "effects.blur.radius"
    public static let glitchIntensity = "effects.glitch.intensity"
    public static let glitchSlice = "effects.glitch.slice"
    public static let glitchBlock = "effects.glitch.block"
    public static let noiseIntensity = "effects.noise.intensity"
    public static let motionBlurRadius = "effects.motionBlur.radius"
    public static let motionBlurAngle = "effects.motionBlur.angle"
    public static let lightSweepPhase = "effects.lightSweep.phase"
    public static let lightSweepWidth = "effects.lightSweep.width"
    public static let liquidPhase = "effects.liquid.phase"
    public static let liquidAmount = "effects.liquid.amount"
    public static let pixelateScale = "effects.pixelate.scale"
    public static let dissolveProgress = "effects.dissolve.progress"
    public static let dissolveAngle = "effects.dissolve.angle"
    public static let bloomIntensity = "effects.bloom.intensity"
    public static let bevelDepth = "effects.bevel.depth"
    public static let bevelLightAngle = "effects.bevel.lightAngle"
    public static let bevelExtrudeDepth = "effects.bevel.extrude"
    public static let particleFieldProgress = "effects.particleField.progress"
    public static let particleFieldAngle = "effects.particleField.angle"
    public static let volumetricRaysIntensity = "effects.volumetricRays.intensity"
    public static let volumetricRaysOriginX = "effects.volumetricRays.originX"
    public static let volumetricRaysOriginY = "effects.volumetricRays.originY"

    public static let audioRMS = "audio.rms"
    public static let audioBass = "audio.bass"
    public static let audioMid = "audio.mid"
    public static let audioTreble = "audio.treble"
    public static let audioBeat = "audio.beat"
    public static let audioIsSynced = "audio.isSynced"
}
