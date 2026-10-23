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

    /// Interpolates normalized X of subject at a given time from keyframes using smooth hermite interpolation.
    public static func interpolatedNormalizedX(
        at timeSeconds: Double,
        keyframes: [AutoPanKeyframe]
    ) -> Double {
        guard !keyframes.isEmpty else { return 0.5 }
        if keyframes.count == 1 { return keyframes[0].normalizedX }

        if timeSeconds <= keyframes[0].timeSeconds {
            return keyframes[0].normalizedX
        }
        guard let last = keyframes.last else { return 0.5 }
        if timeSeconds >= last.timeSeconds {
            return last.normalizedX
        }

        for i in 0..<(keyframes.count - 1) {
            let k0 = keyframes[i]
            let k1 = keyframes[i + 1]
            if timeSeconds >= k0.timeSeconds && timeSeconds <= k1.timeSeconds {
                let dt = k1.timeSeconds - k0.timeSeconds
                guard dt > 0.0001 else { return k0.normalizedX }
                let progress = (timeSeconds - k0.timeSeconds) / dt
                let t = progress * progress * (3.0 - 2.0 * progress)
                return k0.normalizedX + t * (k1.normalizedX - k0.normalizedX)
            }
        }
        return 0.5
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
