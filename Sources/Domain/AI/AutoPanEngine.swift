import Foundation
import CoreGraphics

/// Pure domain math engine for Auto Pan centering and boundary calculations.
/// Guarantees that the camera pans to keep the subject centered along the vertical axis,
/// strictly constrained to available video overflow so zero black bars ever appear.
/// Complies with R2.3, R3.1, and R7.5 of AGENTS.md.
public enum AutoPanEngine {
    /// Computes the maximum allowable horizontal pan without exposing black borders.
    /// When displayed video width is less than or equal to canvas width, returns 0.0.
    public static func maxPanOffset(
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        let displayedWidth = max(0.0, videoWidth * scale)
        guard displayedWidth > canvasWidth else { return 0.0 }
        return (displayedWidth - canvasWidth) / 2.0
    }

    /// Clamps a target pan offset within safe bounds ensuring zero black bars.
    public static func clampPanOffset(
        _ targetPanX: Double,
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        let maxPan = maxPanOffset(videoWidth: videoWidth, scale: scale, canvasWidth: canvasWidth)
        guard maxPan > 0.0 else { return 0.0 }
        return max(-maxPan, min(maxPan, targetPanX))
    }

    /// Computes pan offset needed to center subject at normalized X (0.0 to 1.0) on canvas.
    /// - Parameter subjectNormalizedX: Normalized horizontal center of the subject (0.0 to 1.0).
    ///   0.5 represents the center of the video.
    public static func computePanOffset(
        subjectNormalizedX: Double,
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        let displayedWidth = max(0.0, videoWidth * scale)
        let rawPan = -(subjectNormalizedX - 0.5) * displayedWidth
        return clampPanOffset(rawPan, videoWidth: videoWidth, scale: scale, canvasWidth: canvasWidth)
    }

    /// Interpolates normalized X of subject at a given time from keyframes using Catmull-Rom Spline.
    /// Catmull-Rom guarantees C1 continuity (continuous velocity) without abrupt acceleration or deceleration.
    public static func interpolatedNormalizedX(
        at timeSeconds: Double,
        keyframes: [AutoPanKeyframe]
    ) -> Double {
        guard !keyframes.isEmpty else { return 0.5 }
        if keyframes.count == 1 { return keyframes[0].normalizedX }

        let count = keyframes.count
        if timeSeconds <= keyframes[0].timeSeconds { return keyframes[0].normalizedX }
        if timeSeconds >= keyframes[count - 1].timeSeconds { return keyframes[count - 1].normalizedX }

        var idx = 0
        for i in 0..<(count - 1) {
            if keyframes[i].timeSeconds <= timeSeconds && timeSeconds <= keyframes[i + 1].timeSeconds {
                idx = i
                break
            }
        }

        let t1 = keyframes[idx].timeSeconds
        let t2 = keyframes[idx + 1].timeSeconds
        let timeRange = t2 - t1
        guard timeRange > 0.0001 else { return keyframes[idx].normalizedX }

        let t = (timeSeconds - t1) / timeRange

        let p0 = keyframes[max(0, idx - 1)].normalizedX
        let p1 = keyframes[idx].normalizedX
        let p2 = keyframes[idx + 1].normalizedX
        let p3 = keyframes[min(count - 1, idx + 2)].normalizedX

        let interpX = catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        return max(0.0, min(1.0, interpX))
    }

    /// Catmull-Rom spline interpolation formula ensuring continuous first-derivative velocity.
    public static func catmullRom(p0: Double, p1: Double, p2: Double, p3: Double, t: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        )
    }

    /// Gaussian 1-2-1 smoothing filter applied across keyframe samples to eliminate single-frame detection noise.
    public static func smoothKeyframesGaussian(
        _ keyframes: [AutoPanKeyframe],
        passes: Int = 2
    ) -> [AutoPanKeyframe] {
        guard keyframes.count > 2 else { return keyframes }
        var current = keyframes
        let count = current.count

        for _ in 0..<max(1, passes) {
            var smoothed: [AutoPanKeyframe] = []
            smoothed.reserveCapacity(count)
            for i in 0..<count {
                let prev = current[max(0, i - 1)].normalizedX
                let curr = current[i].normalizedX
                let next = current[min(count - 1, i + 1)].normalizedX

                let smoothX = (prev + 2.0 * curr + next) / 4.0
                smoothed.append(AutoPanKeyframe(timeSeconds: current[i].timeSeconds, normalizedX: smoothX, confidence: current[i].confidence))
            }
            current = smoothed
        }
        return current
    }

    /// Computes smoothed pan offset at a given time for the clip.
    public static func panOffset(
        at timeSeconds: Double,
        config: AutoPanConfiguration,
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        guard config.isEnabled, !config.keyframes.isEmpty else { return 0.0 }
        let subjX = interpolatedNormalizedX(at: timeSeconds, keyframes: config.keyframes)
        return computePanOffset(
            subjectNormalizedX: subjX,
            videoWidth: videoWidth,
            scale: scale,
            canvasWidth: canvasWidth
        )
    }
}
