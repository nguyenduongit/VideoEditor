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
    /// Also applies median + deadzone + heavy Gaussian smoothing to vertical body lines (waistY, ankleY)
    /// so in-place jumps do not bounce the background while forward/backward movement glides smoothly.
    public static func smoothKeyframesGaussian(
        _ keyframes: [AutoPanKeyframe],
        passes: Int = 2
    ) -> [AutoPanKeyframe] {
        guard keyframes.count > 2 else { return keyframes }
        var current = stabilizeVerticalBodyLines(keyframes)
        let count = current.count

        for _ in 0..<max(1, passes) {
            var smoothed: [AutoPanKeyframe] = []
            smoothed.reserveCapacity(count)
            for i in 0..<count {
                let prev = current[max(0, i - 1)].normalizedX
                let curr = current[i].normalizedX
                let next = current[min(count - 1, i + 1)].normalizedX

                let smoothX = (prev + 2.0 * curr + next) / 4.0
                smoothed.append(
                    AutoPanKeyframe(
                        timeSeconds: current[i].timeSeconds,
                        normalizedX: smoothX,
                        confidence: current[i].confidence,
                        waistY: current[i].waistY,
                        ankleY: current[i].ankleY
                    )
                )
            }
            current = smoothed
        }
        return current
    }

    /// Stabilizes vertical waist/ankle lines against jumping/bouncing while preserving depth movement.
    public static func stabilizeVerticalBodyLines(_ keyframes: [AutoPanKeyframe]) -> [AutoPanKeyframe] {
        let count = keyframes.count
        guard count > 0 else { return keyframes }
        let rawWaists = keyframes.compactMap(\.waistY)
        let rawAnkles = keyframes.compactMap(\.ankleY)
        guard !rawWaists.isEmpty, !rawAnkles.isEmpty else { return keyframes }

        let fallbackW = medianValue(rawWaists)
        let fallbackA = max(fallbackW + 0.15, medianValue(rawAnkles))

        var waists = keyframes.map { $0.waistY ?? fallbackW }
        var ankles = keyframes.map { $0.ankleY ?? fallbackA }

        // 1. Moving median window (radius 2 -> 5 samples) to reject jump/squat spikes
        waists = movingMedian(waists, radius: 2)
        ankles = movingMedian(ankles, radius: 2)

        // 2. Deadzone hysteresis (~2%) so in-place dancing stays rock solid
        waists = applyDeadzone(waists, threshold: 0.02)
        ankles = applyDeadzone(ankles, threshold: 0.02)

        // 3. Heavy Gaussian smoothing (6 passes) for smooth forward/backward depth transitions
        for _ in 0..<6 {
            waists = gaussianPass(waists)
            ankles = gaussianPass(ankles)
        }

        return keyframes.enumerated().map { idx, kf in
            let w = max(0.10, min(0.82, waists[idx]))
            let a = max(w + 0.10, min(0.96, ankles[idx]))
            return AutoPanKeyframe(
                timeSeconds: kf.timeSeconds,
                normalizedX: kf.normalizedX,
                confidence: kf.confidence,
                waistY: w,
                ankleY: a
            )
        }
    }

    /// Interpolates smoothed (waistY, ankleY) at a given timestamp using Catmull-Rom spline.
    public static func interpolatedBodyLines(
        at timeSeconds: Double,
        keyframes: [AutoPanKeyframe]
    ) -> (waistY: Double, ankleY: Double)? {
        let valid = keyframes.filter { $0.waistY != nil && $0.ankleY != nil }
        guard !valid.isEmpty else { return nil }
        if valid.count == 1, let w = valid[0].waistY, let a = valid[0].ankleY {
            return (w, max(w + 0.08, a))
        }
        let count = valid.count
        if timeSeconds <= valid[0].timeSeconds, let w = valid[0].waistY, let a = valid[0].ankleY {
            return (w, max(w + 0.08, a))
        }
        if timeSeconds >= valid[count - 1].timeSeconds, let w = valid[count - 1].waistY, let a = valid[count - 1].ankleY {
            return (w, max(w + 0.08, a))
        }
        var idx = 0
        for i in 0..<(count - 1) where valid[i].timeSeconds <= timeSeconds && timeSeconds <= valid[i + 1].timeSeconds {
            idx = i
            break
        }
        let t1 = valid[idx].timeSeconds
        let t2 = valid[idx + 1].timeSeconds
        let dt = t2 - t1
        guard dt > 0.0001 else {
            let w = valid[idx].waistY ?? 0.33
            let a = valid[idx].ankleY ?? 0.67
            return (w, max(w + 0.08, a))
        }
        let t = (timeSeconds - t1) / dt
        let i0 = max(0, idx - 1), i1 = idx, i2 = idx + 1, i3 = min(count - 1, idx + 2)
        let w = catmullRom(p0: valid[i0].waistY ?? 0.33, p1: valid[i1].waistY ?? 0.33, p2: valid[i2].waistY ?? 0.33, p3: valid[i3].waistY ?? 0.33, t: t)
        let a = catmullRom(p0: valid[i0].ankleY ?? 0.67, p1: valid[i1].ankleY ?? 0.67, p2: valid[i2].ankleY ?? 0.67, p3: valid[i3].ankleY ?? 0.67, t: t)
        let clampedW = max(0.08, min(0.85, w))
        let clampedA = max(clampedW + 0.08, min(0.96, a))
        return (clampedW, clampedA)
    }

    /// Returns representative median (waistY, ankleY) across all keyframes.
    public static func representativeBodyLines(from keyframes: [AutoPanKeyframe]) -> (waistY: Double, ankleY: Double)? {
        let waists = keyframes.compactMap(\.waistY)
        let ankles = keyframes.compactMap(\.ankleY)
        guard !waists.isEmpty, !ankles.isEmpty else { return nil }
        let w = max(0.08, min(0.85, medianValue(waists)))
        let a = max(w + 0.10, min(0.96, medianValue(ankles)))
        return (w, a)
    }

    private static func medianValue(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2.0 : sorted[mid]
    }

    private static func movingMedian(_ values: [Double], radius: Int) -> [Double] {
        let count = values.count
        guard count > 2 else { return values }
        return (0..<count).map { i in
            let lo = max(0, i - radius)
            let hi = min(count - 1, i + radius)
            return medianValue(Array(values[lo...hi]))
        }
    }

    private static func applyDeadzone(_ values: [Double], threshold: Double) -> [Double] {
        guard var anchor = values.first else { return values }
        return values.map { v in
            if abs(v - anchor) >= threshold {
                anchor = v
            }
            return anchor
        }
    }

    private static func gaussianPass(_ values: [Double]) -> [Double] {
        let count = values.count
        guard count > 2 else { return values }
        return (0..<count).map { i in
            let prev = values[max(0, i - 1)]
            let curr = values[i]
            let next = values[min(count - 1, i + 1)]
            return (prev + 2.0 * curr + next) / 4.0
        }
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
