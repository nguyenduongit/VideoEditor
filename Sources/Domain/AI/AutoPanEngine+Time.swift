import Foundation
import CoreMedia

/// Extension providing CMTime and RationalTime overloads for AutoPanEngine calculations.
/// Conforms to AGENTS.md R2.3 (preferring rational time representation over floating-point seconds).
extension AutoPanEngine {
    /// Interpolates normalized X of subject at a given CMTime from keyframes using Catmull-Rom Spline.
    public static func interpolatedNormalizedX(
        at time: CMTime,
        keyframes: [AutoPanKeyframe]
    ) -> Double {
        interpolatedNormalizedX(at: time.seconds, keyframes: keyframes)
    }

    /// Interpolates normalized X of subject at a given RationalTime from keyframes using Catmull-Rom Spline.
    public static func interpolatedNormalizedX(
        at time: RationalTime,
        keyframes: [AutoPanKeyframe]
    ) -> Double {
        interpolatedNormalizedX(at: time.seconds, keyframes: keyframes)
    }

    /// Interpolates smoothed (waistY, ankleY) at a given CMTime using Catmull-Rom spline.
    public static func interpolatedBodyLines(
        at time: CMTime,
        keyframes: [AutoPanKeyframe]
    ) -> (waistY: Double, ankleY: Double)? {
        interpolatedBodyLines(at: time.seconds, keyframes: keyframes)
    }

    /// Interpolates smoothed (waistY, ankleY) at a given RationalTime using Catmull-Rom spline.
    public static func interpolatedBodyLines(
        at time: RationalTime,
        keyframes: [AutoPanKeyframe]
    ) -> (waistY: Double, ankleY: Double)? {
        interpolatedBodyLines(at: time.seconds, keyframes: keyframes)
    }

    /// Computes smoothed pan offset at a given CMTime for the clip.
    public static func panOffset(
        at time: CMTime,
        config: AutoPanConfiguration,
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        panOffset(
            at: time.seconds,
            config: config,
            videoWidth: videoWidth,
            scale: scale,
            canvasWidth: canvasWidth
        )
    }

    /// Computes smoothed pan offset at a given RationalTime for the clip.
    public static func panOffset(
        at time: RationalTime,
        config: AutoPanConfiguration,
        videoWidth: Double,
        scale: Double,
        canvasWidth: Double
    ) -> Double {
        panOffset(
            at: time.seconds,
            config: config,
            videoWidth: videoWidth,
            scale: scale,
            canvasWidth: canvasWidth
        )
    }
}
