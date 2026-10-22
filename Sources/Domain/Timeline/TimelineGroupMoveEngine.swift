import Foundation
import CoreMedia

public enum TimelineGroupMoveEngine: Sendable {
    public struct MoveLimits: Sendable, Equatable {
        public let minDelta: CMTime
        public let maxDelta: CMTime

        public init(minDelta: CMTime, maxDelta: CMTime) {
            self.minDelta = minDelta
            self.maxDelta = maxDelta
        }

        public var canMove: Bool {
            minDelta <= maxDelta && (minDelta < .zero || maxDelta > .zero)
        }
    }

    /// Computes the collective allowed delta range for a set of selected clips across all layers.
    /// If even one clip is blocked in a direction, the whole group cannot move past that blockage.
    public static func calculateLimits(
        layers: [TimelineLayer],
        selectedClipIDs: Set<UUID>
    ) -> MoveLimits {
        guard !selectedClipIDs.isEmpty else {
            return MoveLimits(minDelta: .zero, maxDelta: .zero)
        }

        var groupMinDelta = CMTime(seconds: -86400 * 365, preferredTimescale: 600)
        var groupMaxDelta = CMTime(seconds: 86400 * 365, preferredTimescale: 600)

        for layer in layers {
            let selectedClips = layer.clips.filter { selectedClipIDs.contains($0.id) }
            guard !selectedClips.isEmpty else { continue }

            if layer.isLocked {
                return MoveLimits(minDelta: .zero, maxDelta: .zero)
            }

            let unselectedClips = layer.clips.filter { !selectedClipIDs.contains($0.id) }

            for clip in selectedClips {
                let start = clip.timeRange.start
                let end = clip.timeRange.end

                var clipMinDelta = CMTimeSubtract(.zero, start)
                var clipMaxDelta = CMTime(seconds: 86400 * 365, preferredTimescale: 600)

                for u in unselectedClips {
                    let uStart = u.timeRange.start
                    let uEnd = u.timeRange.end

                    if uEnd <= start {
                        let dist = CMTimeSubtract(uEnd, start)
                        clipMinDelta = CMTimeMaximum(clipMinDelta, dist)
                    } else if uStart >= end {
                        let dist = CMTimeSubtract(uStart, end)
                        clipMaxDelta = CMTimeMinimum(clipMaxDelta, dist)
                    } else {
                        return MoveLimits(minDelta: .zero, maxDelta: .zero)
                    }
                }

                groupMinDelta = CMTimeMaximum(groupMinDelta, clipMinDelta)
                groupMaxDelta = CMTimeMinimum(groupMaxDelta, clipMaxDelta)
            }
        }

        if groupMinDelta > groupMaxDelta {
            return MoveLimits(minDelta: .zero, maxDelta: .zero)
        }
        return MoveLimits(minDelta: groupMinDelta, maxDelta: groupMaxDelta)
    }

    /// Clamps a proposed delta time within the computed limits.
    public static func clamp(
        delta: CMTime,
        limits: MoveLimits
    ) -> CMTime {
        guard limits.minDelta <= limits.maxDelta else { return .zero }
        if delta < limits.minDelta { return limits.minDelta }
        if delta > limits.maxDelta { return limits.maxDelta }
        return delta
    }
}
