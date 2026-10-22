import Foundation
import CoreMedia
import Domain

enum TimelineClipTrimBounds {
    static func minStart(clip: TimelineClip, previousClipEnd: CMTime?) -> Double {
        var minSec = max(0.0, previousClipEnd.map { CMTimeGetSeconds($0) } ?? 0.0)
        if clip.kind.hasFixedSourceDuration {
            let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
            let sourceStartTimelineSec = CMTimeGetSeconds(clip.sourceStartTime) / speed
            minSec = max(minSec, CMTimeGetSeconds(clip.timeRange.start) - sourceStartTimelineSec)
        }
        return minSec
    }

    static func maxEnd(clip: TimelineClip, nextClipStart: CMTime?) -> Double {
        var maxSec = nextClipStart.map { CMTimeGetSeconds($0) } ?? Double.infinity
        if clip.kind.hasFixedSourceDuration, let maxDuration = clip.maxDuration {
            let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
            let remainingSource = max(0.0, CMTimeGetSeconds(maxDuration) - CMTimeGetSeconds(clip.sourceStartTime))
            let remainTimeline = max(1.0 / Double(TimeRational.defaultFPS), remainingSource / speed)
            maxSec = min(maxSec, CMTimeGetSeconds(clip.timeRange.start) + remainTimeline)
        }
        return maxSec
    }
}
