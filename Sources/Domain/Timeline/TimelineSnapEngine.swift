import Foundation
import CoreMedia

public enum TimelineSnapEngine: Sendable {
    public static let defaultSnapThresholdPixels: CGFloat = 10.0

    /// Calculates snap threshold in CMTime given screen pixels and pixelsPerSecond.
    public static func thresholdTime(
        pixels: CGFloat = defaultSnapThresholdPixels,
        pixelsPerSecond: CGFloat
    ) -> CMTime {
        guard pixelsPerSecond > 0 else {
            return CMTime(seconds: 0.1, preferredTimescale: 600)
        }
        let seconds = Double(pixels / pixelsPerSecond)
        return CMTime(seconds: seconds, preferredTimescale: 600)
    }

    /// Snaps a single point in time to the closest candidate point if within threshold.
    public static func snapPoint(
        time: CMTime,
        candidates: [CMTime],
        threshold: CMTime
    ) -> (snappedTime: CMTime, didSnap: Bool) {
        let targetSec = CMTimeGetSeconds(time)
        let thresholdSec = CMTimeGetSeconds(threshold)

        var closestPoint: CMTime?
        var minDistance: Double = thresholdSec

        for candidate in candidates {
            let candidateSec = CMTimeGetSeconds(candidate)
            let distance = abs(candidateSec - targetSec)
            if distance <= minDistance {
                minDistance = distance
                closestPoint = candidate
            }
        }

        if let closest = closestPoint {
            return (closest, true)
        }
        return (time, false)
    }

    /// Snaps a moving clip defined by proposedStart and duration.
    /// Checks if the START edge snaps to any candidate.
    /// If START does not snap, checks if the END edge snaps to any candidate.
    public static func snapClipMove(
        proposedStart: CMTime,
        duration: CMTime,
        candidates: [CMTime],
        threshold: CMTime
    ) -> (snappedStart: CMTime, didSnap: Bool) {
        // 1. Try snapping the START edge
        let startResult = snapPoint(time: proposedStart, candidates: candidates, threshold: threshold)
        if startResult.didSnap {
            return (startResult.snappedTime, true)
        }

        // 2. Try snapping the END edge
        let proposedEnd = proposedStart + duration
        let endResult = snapPoint(time: proposedEnd, candidates: candidates, threshold: threshold)
        if endResult.didSnap {
            let adjustedStart = endResult.snappedTime - duration
            let safeStart = CMTimeMaximum(.zero, adjustedStart)
            return (safeStart, true)
        }

        return (proposedStart, false)
    }

    /// Snaps the start time of a clip during trim left.
    public static func snapTrimStart(
        proposedStart: CMTime,
        candidates: [CMTime],
        threshold: CMTime,
        minStart: CMTime,
        maxStart: CMTime
    ) -> CMTime {
        let (snapped, didSnap) = snapPoint(time: proposedStart, candidates: candidates, threshold: threshold)
        let effective = didSnap ? snapped : proposedStart
        return CMTimeMinimum(maxStart, CMTimeMaximum(minStart, effective))
    }

    /// Snaps the end time of a clip during trim right.
    public static func snapTrimEnd(
        proposedEnd: CMTime,
        candidates: [CMTime],
        threshold: CMTime,
        minEnd: CMTime,
        maxEnd: CMTime
    ) -> CMTime {
        let (snapped, didSnap) = snapPoint(time: proposedEnd, candidates: candidates, threshold: threshold)
        let effective = didSnap ? snapped : proposedEnd
        return CMTimeMinimum(maxEnd, CMTimeMaximum(minEnd, effective))
    }
}
