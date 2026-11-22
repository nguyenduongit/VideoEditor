import Foundation
import CoreMedia

public struct AudioWaveformMath: Sendable {
    /// True peak / clipping warning threshold in dBFS (default: -1.5 dBFS).
    /// Peak transients exceeding this are highlighted with orange warning tips,
    /// while the main body of the waveform remains clean cyan-blue.
    public static let defaultThresholdDB: Float = -1.5

    /// Linear amplitude corresponding to -1.5 dBFS: 10^(-1.5/20) ~ 0.8414
    public static let thresholdLinearAmplitude: Float = pow(10.0, defaultThresholdDB / 20.0)

    /// Perceptual display height fraction in [0, 1].
    /// Linear amplitude ensures natural dynamic range and realistic waveform hills/valleys.
    public static func perceptualHeightFraction(amplitude: Float) -> Float {
        let clamped = max(0.0, min(1.0, amplitude))
        return clamped
    }

    /// Determines if a linear amplitude exceeds the threshold in dBFS.
    public static func isAboveThreshold(amplitude: Float, thresholdDB: Float = defaultThresholdDB) -> Bool {
        let threshLinear = pow(10.0, thresholdDB / 20.0)
        return amplitude > threshLinear
    }

    /// Calculates the peak amplitude in a given source time interval [sourceStartTime, sourceEndTime]
    /// from a dense peak array sampled at `peaksPerSecond`.
    public static func peakInRange(
        peaks: [Float],
        sourceStartTime: Double,
        sourceEndTime: Double,
        peaksPerSecond: Double = 100.0
    ) -> Float {
        guard !peaks.isEmpty, sourceEndTime >= sourceStartTime, sourceStartTime >= 0 else { return 0.0 }
        let startIndex = max(0, min(peaks.count - 1, Int(sourceStartTime * peaksPerSecond)))
        let endIndex = max(startIndex, min(peaks.count - 1, Int(ceil(sourceEndTime * peaksPerSecond))))

        var maxVal: Float = 0.0
        for i in startIndex...endIndex where peaks[i] > maxVal {
            maxVal = peaks[i]
        }
        return maxVal
    }

    /// Smooth S-curve (Hermite smoothstep: `3u^2 - 2u^3`) mapping normalized fade progress `u in [0, 1]`
    /// to a natural curved audio gain multiplier in `[0, 1]` with zero derivative at both endpoints.
    @inline(__always)
    public static func curvedFadeMultiplier(_ progress: Double) -> Float {
        let u = max(0.0, min(1.0, progress))
        return Float(u * u * (3.0 - 2.0 * u))
    }

    /// Calculates the envelope gain multiplier in [0, 4] at a relative clip time `t` (seconds).
    /// Handles clip volume gain (0%...400%) as well as fade-in (at start) and fade-out (at end) with smooth S-curve ramps.
    public static func envelopeGain(
        at t: Double,
        duration: Double,
        fadeIn: Double,
        fadeOut: Double,
        volume: Double = 1.0
    ) -> Float {
        let clampedVol = Float(max(0.0, min(4.0, volume)))
        guard duration > 0 else { return clampedVol }
        var inGain: Float = 1.0
        var outGain: Float = 1.0

        if fadeIn > 0.001 {
            if t <= 0 {
                inGain = 0.0
            } else if t < fadeIn {
                inGain = curvedFadeMultiplier(t / fadeIn)
            }
        }

        if fadeOut > 0.001 {
            let fadeOutStart = duration - fadeOut
            if t >= duration {
                outGain = 0.0
            } else if t > fadeOutStart {
                outGain = curvedFadeMultiplier((duration - t) / fadeOut)
            }
        }

        return max(0.0, min(4.0, clampedVol * inGain * outGain))
    }

    /// Maps volume gain in [0.0, 4.0] to a normalized envelope line height fraction in [0.0, 1.0]
    /// (0.0 -> 0%, 1.0 -> 50% baseline, 4.0 -> 100% top).
    public static func volumeLineHeightFraction(volume: Double) -> CGFloat {
        let v = max(0.0, min(4.0, volume))
        if v <= 1.0 {
            return CGFloat(v * 0.5)
        } else {
            return CGFloat(0.5 + ((v - 1.0) / 3.0) * 0.5)
        }
    }
}
