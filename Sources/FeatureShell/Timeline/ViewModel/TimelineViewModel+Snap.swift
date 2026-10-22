import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Collects candidate snap points across all unlocked layers,
    /// including timeline origin (.zero), start and end times of other clips, and playhead.
    public func snapCandidateTimes(
        excludingClipID: UUID? = nil,
        playheadTime: CMTime? = nil,
        includePlayhead: Bool = true
    ) -> [CMTime] {
        var points: [CMTime] = [.zero]
        if includePlayhead {
            let effectivePlayhead = playheadTime ?? currentTime
            if effectivePlayhead > .zero {
                points.append(effectivePlayhead)
            }
        }

        for layer in layers where !layer.isLocked {
            for clip in layer.clips {
                if let excludingClipID, clip.id == excludingClipID {
                    continue
                }
                points.append(clip.timeRange.start)
                points.append(clip.timeRange.end)
            }
        }

        return points.sorted()
    }
}
