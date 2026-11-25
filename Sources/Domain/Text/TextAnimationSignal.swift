import Foundation

/// Recursive procedural signal tree evaluated against `TextAnimationGraphContext`.
/// Allows authoring arbitrary motion curves, springs, waves, noise, and audio-reactive graphs via pure data.
public indirect enum TextAnimationSignal: Codable, Hashable, Sendable {
    case constant(Double)
    case progress(TextAnimationTimeSource)
    case unitProgress
    case unitIndex
    case unitCenterDistance
    case unitRandom(seed: UInt64)
    case externalInput(name: String, fallback: Double)
    case keyframes([TextAnimationKeyframe], time: TextAnimationTimeSource)
    case oscillator(
        waveform: TextAnimationWaveform,
        frequency: Double,
        amplitude: Double,
        phase: Double,
        offset: Double,
        pulseWidth: Double,
        time: TextAnimationTimeSource
    )
    case spring(
        from: Double,
        to: Double,
        frequency: Double,
        damping: Double,
        time: TextAnimationTimeSource
    )
    case noise(seed: UInt64, frequency: Double, amplitude: Double, time: TextAnimationTimeSource)
    case motionPath(TextAnimationMotionPath, output: TextAnimationMotionPath.SampleOutput, time: TextAnimationTimeSource)
    case add(TextAnimationSignal, TextAnimationSignal)
    case subtract(TextAnimationSignal, TextAnimationSignal)
    case multiply(TextAnimationSignal, TextAnimationSignal)
    case divide(TextAnimationSignal, TextAnimationSignal)
    case minimum(TextAnimationSignal, TextAnimationSignal)
    case maximum(TextAnimationSignal, TextAnimationSignal)
    case mix(from: TextAnimationSignal, to: TextAnimationSignal, amount: TextAnimationSignal)
    case absolute(TextAnimationSignal)
    case oneMinus(TextAnimationSignal)
    case clamp(TextAnimationSignal, minimum: Double, maximum: Double)
    case remap(TextAnimationSignal, inputMin: Double, inputMax: Double, outputMin: Double, outputMax: Double)
    case smoothstep(TextAnimationSignal)

    public func evaluate(in context: TextAnimationGraphContext) -> Double {
        switch self {
        case .constant, .progress, .unitProgress, .unitIndex,
             .unitCenterDistance, .unitRandom, .externalInput:
            return evaluatePrimitive(in: context)
        case .keyframes, .oscillator, .spring, .noise, .motionPath:
            return evaluateGenerator(in: context)
        default:
            return evaluateCompositeMath(in: context)
        }
    }

    private func evaluatePrimitive(in context: TextAnimationGraphContext) -> Double {
        switch self {
        case .constant(let value):
            return value
        case .progress(let source):
            return context.value(for: source)
        case .unitProgress:
            return context.phaseProgress
        case .unitIndex:
            return context.unitCount > 1 ? Double(context.unitIndex) / Double(context.unitCount - 1) : 0.0
        case .unitCenterDistance:
            guard context.unitCount > 1 else { return 0.0 }
            let center = Double(context.unitCount - 1) * 0.5
            return abs(Double(context.unitIndex) - center) / max(0.5, center)
        case .unitRandom(let seed):
            return Self.randomUnit(seed: seed ^ context.randomSeed, index: context.unitIndex)
        case .externalInput(let name, let fallback):
            return context.externalInputs[name] ?? fallback
        default:
            return 0.0
        }
    }

    private func evaluateGenerator(in context: TextAnimationGraphContext) -> Double {
        switch self {
        case .keyframes(let frames, let source):
            return Self.sample(frames: frames, at: context.value(for: source))
        case .oscillator(let shape, let frequency, let amplitude, let phase, let offset, let pulseWidth, let source):
            let cycles = context.value(for: source) * frequency + phase / (2.0 * .pi)
            return offset + Self.waveform(shape, at: cycles, pulseWidth: pulseWidth) * amplitude
        case .spring(let from, let to, let frequency, let damping, let source):
            return Self.evaluateSpring(from: from, to: to, frequency: frequency, damping: damping, t: max(0.0, context.value(for: source)))
        case .noise(let seed, let frequency, let amplitude, let source):
            let unitSeed = seed ^ context.randomSeed ^ (UInt64(context.unitIndex) &* 0x9E3779B97F4A7C15)
            return Self.noise(seed: unitSeed, position: context.value(for: source) * frequency) * amplitude
        case .motionPath(let path, let output, let source):
            return path.sampleValue(for: output, at: context.value(for: source))
        default:
            return 0.0
        }
    }

    private func evaluateCompositeMath(in context: TextAnimationGraphContext) -> Double {
        switch self {
        case .add(let lhs, let rhs):
            return lhs.evaluate(in: context) + rhs.evaluate(in: context)
        case .subtract(let lhs, let rhs):
            return lhs.evaluate(in: context) - rhs.evaluate(in: context)
        case .multiply(let lhs, let rhs):
            return lhs.evaluate(in: context) * rhs.evaluate(in: context)
        case .divide(let lhs, let rhs):
            let denom = rhs.evaluate(in: context)
            return abs(denom) < 0.000001 ? 0.0 : lhs.evaluate(in: context) / denom
        case .minimum(let lhs, let rhs):
            return min(lhs.evaluate(in: context), rhs.evaluate(in: context))
        case .maximum(let lhs, let rhs):
            return max(lhs.evaluate(in: context), rhs.evaluate(in: context))
        case .mix(let from, let to, let amount):
            let p = min(1.0, max(0.0, amount.evaluate(in: context)))
            return from.evaluate(in: context) + (to.evaluate(in: context) - from.evaluate(in: context)) * p
        case .absolute(let value):
            return abs(value.evaluate(in: context))
        case .oneMinus(let value):
            return 1.0 - value.evaluate(in: context)
        case .clamp(let value, let minimum, let maximum):
            return min(maximum, max(minimum, value.evaluate(in: context)))
        case .remap(let value, let inMin, let inMax, let outMin, let outMax):
            let span = inMax - inMin
            let p = abs(span) < 0.000001 ? 0.0 : (value.evaluate(in: context) - inMin) / span
            return outMin + (outMax - outMin) * p
        case .smoothstep(let value):
            let x = min(1.0, max(0.0, value.evaluate(in: context)))
            return x * x * (3.0 - 2.0 * x)
        default:
            return 0.0
        }
    }

    private static func evaluateSpring(
        from: Double,
        to: Double,
        frequency: Double,
        damping: Double,
        t: Double
    ) -> Double {
        if t >= 1.0 { return to }
        let zeta = min(2.0, max(0.0, damping))
        let omega = 2.0 * .pi * max(0.01, frequency)
        let settleFade: Double
        if t > 0.80 {
            let u = (t - 0.80) / 0.20
            settleFade = 1.0 - u * u * (3.0 - 2.0 * u)
        } else {
            settleFade = 1.0
        }
        let response: Double
        if zeta < 0.0001 {
            response = 1.0 - cos(omega * t) * settleFade
        } else if zeta < 1.0 {
            let dampedRoot = sqrt(1.0 - zeta * zeta)
            let wd = omega * dampedRoot
            let decay = exp(-zeta * omega * t) * settleFade
            response = 1.0 - decay * (cos(wd * t) + (zeta / dampedRoot) * sin(wd * t))
        } else {
            response = 1.0 - exp(-omega * t) * settleFade
        }
        return from + (to - from) * response
    }

    private static func waveform(_ shape: TextAnimationWaveform, at t: Double, pulseWidth: Double) -> Double {
        let p = t - floor(t)
        switch shape {
        case .sine: return sin(t * 2.0 * .pi)
        case .triangle: return 1.0 - 4.0 * abs(p - 0.5)
        case .sawtooth: return 2.0 * p - 1.0
        case .square: return p < 0.5 ? 1.0 : -1.0
        case .pulse: return p < min(0.99, max(0.01, pulseWidth)) ? 1.0 : 0.0
        }
    }

    private static func sample(frames: [TextAnimationKeyframe], at rawTime: Double) -> Double {
        guard !frames.isEmpty else { return 0.0 }
        let isSorted = zip(frames, frames.dropFirst()).allSatisfy { $0.time <= $1.time }
        let sorted = isSorted ? frames : frames.sorted { $0.time < $1.time }
        guard let first = sorted.first else { return 0.0 }
        guard sorted.count > 1 else { return first.value }

        let time = max(0.0, rawTime)
        if let exact = sorted.last(where: { abs($0.time - time) < 0.0000001 }) {
            return exact.value
        }
        if time < first.time { return first.value }
        guard let upperIndex = sorted.firstIndex(where: { $0.time > time }), upperIndex > 0 else {
            return sorted.last?.value ?? first.value
        }
        let prev = sorted[upperIndex - 1]
        let next = sorted[upperIndex]
        let span = next.time - prev.time
        guard span > 0.000001 else { return next.value }
        let rawT = min(1.0, max(0.0, (time - prev.time) / span))
        let eased = interpolate(rawT, using: prev.interpolationToNext)
        return prev.value + (next.value - prev.value) * eased
    }

    private static func interpolate(_ t: Double, using mode: TextAnimationInterpolation) -> Double {
        switch mode {
        case .linear: return t
        case .hold: return 0.0
        case .smooth: return t * t * (3.0 - 2.0 * t)
        case .easeIn: return t * t
        case .easeOut: return 1.0 - (1.0 - t) * (1.0 - t)
        case .easeInOut: return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
        case .cubicBezier(let x1, let y1, let x2, let y2):
            return cubicBezierY(forX: t, x1: x1, y1: y1, x2: x2, y2: y2)
        }
    }

    private static func cubicBezierY(forX x: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        func coordinate(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let u = 1.0 - t
            return 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t
        }
        var low = 0.0
        var high = 1.0
        for _ in 0..<18 {
            let mid = (low + high) * 0.5
            if coordinate(mid, x1, x2) < x { low = mid } else { high = mid }
        }
        return coordinate((low + high) * 0.5, y1, y2)
    }

    private static func noise(seed: UInt64, position: Double) -> Double {
        let left = Int64(floor(position))
        let fraction = position - floor(position)
        let t = fraction * fraction * (3.0 - 2.0 * fraction)
        let a = randomSigned(seed: seed, index: left)
        let b = randomSigned(seed: seed, index: left &+ 1)
        return a + (b - a) * t
    }

    private static func randomUnit(seed: UInt64, index: Int) -> Double {
        let bits = mix(seed ^ UInt64(bitPattern: Int64(index)))
        return Double(bits >> 11) / Double(1 << 53)
    }

    private static func randomSigned(seed: UInt64, index: Int64) -> Double {
        randomUnit(seed: seed, index: Int(truncatingIfNeeded: index)) * 2.0 - 1.0
    }

    private static func mix(_ input: UInt64) -> UInt64 {
        var value = input &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
