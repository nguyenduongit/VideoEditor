import Foundation

/// Pure mathematical easing, periodic wave, and physics curves for `StickerAnimationScript`.
public enum StickerAnimationCurves: Sendable {
    /// Clamps progress into unit interval `0.0 ... 1.0`.
    public static func clamp01(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }

    /// Cubic ease-out deceleration.
    public static func easeOutCubic(_ t: Double) -> Double {
        let u = 1.0 - clamp01(t)
        return 1.0 - u * u * u
    }

    /// Cubic ease-in acceleration.
    public static func easeInCubic(_ t: Double) -> Double {
        let u = clamp01(t)
        return u * u * u
    }

    /// Quintic ease-out crisp arrival.
    public static func easeOutQuint(_ t: Double) -> Double {
        let u = 1.0 - clamp01(t)
        return 1.0 - u * u * u * u * u
    }

    /// Smooth sinusoidal ease in-and-out.
    public static func easeInOutSine(_ t: Double) -> Double {
        0.5 * (1.0 - cos(.pi * clamp01(t)))
    }

    /// Elastic overshoot spring arrival (`backOut`).
    public static func easeOutBack(_ t: Double, overshoot: Double = 1.70158) -> Double {
        let u = clamp01(t) - 1.0
        return 1.0 + (overshoot + 1.0) * u * u * u + overshoot * u * u
    }

    /// Elastic anticipate retract (`backIn`).
    public static func easeInBack(_ t: Double, overshoot: Double = 1.55) -> Double {
        let u = clamp01(t)
        return (overshoot + 1.0) * u * u * u - overshoot * u * u
    }

    /// Classic multi-rebound parabolic bounce settling at 1.0.
    public static func easeOutBounce(_ t: Double) -> Double {
        let u = clamp01(t)
        let n1 = 7.5625
        let d1 = 2.75
        if u < 1.0 / d1 {
            return n1 * u * u
        } else if u < 2.0 / d1 {
            let x = u - 1.5 / d1
            return n1 * x * x + 0.75
        } else if u < 2.5 / d1 {
            let x = u - 2.25 / d1
            return n1 * x * x + 0.9375
        }
        let x = u - 2.625 / d1
        return n1 * x * x + 0.984375
    }

    /// Under-damped spring oscillation starting at 0 and settling at 1.0.
    public static func easeOutElastic(_ t: Double) -> Double {
        let u = clamp01(t)
        if u <= 0.0 { return 0.0 }
        if u >= 1.0 { return 1.0 }
        let period = (2.0 * .pi) / 3.0
        return pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * period) + 1.0
    }

    /// Smooth fade-in-and-out envelope over a periodic loop (`0` at loop edges, `1` in the interior).
    public static func loopEnvelope(_ u: Double, edgeFraction: Double = 0.14) -> Double {
        let clamped = clamp01(u)
        let edge = max(0.01, min(0.45, edgeFraction))
        if clamped < edge {
            return easeInOutSine(clamped / edge)
        }
        if clamped > 1.0 - edge {
            return easeInOutSine((1.0 - clamped) / edge)
        }
        return 1.0
    }

    /// Quantized stop-motion step progression.
    public static func stepped(_ t: Double, steps: Double = 6.0) -> Double {
        let count = max(1.0, steps)
        return floor(clamp01(t) * count) / count
    }
}
