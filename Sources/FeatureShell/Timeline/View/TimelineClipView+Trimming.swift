import SwiftUI
import Foundation
import CoreMedia
import Domain

extension TimelineClipView {
    var minStartSec: Double {
        TimelineClipTrimBounds.minStart(clip: clip, previousClipEnd: previousClipEnd)
    }

    var maxEndSec: Double {
        TimelineClipTrimBounds.maxEnd(clip: clip, nextClipStart: nextClipStart)
    }

    func handleLeftTrimChanged(dx: CGFloat) {
        let pps = pixelsPerSecond
        let ppf = pps / CGFloat(TimeRational.defaultFPS)
        let curStart = CMTimeGetSeconds(clip.timeRange.start)
        let maxStart = curStart + CMTimeGetSeconds(clip.timeRange.duration) - (1.0 / Double(TimeRational.defaultFPS))
        let proposed = CMTime(seconds: curStart + Double(round(dx / ppf) * ppf / pps), preferredTimescale: 600)
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)
        let minStart = CMTime(seconds: minStartSec, preferredTimescale: 600)
        let maxStartT = CMTime(seconds: maxStart, preferredTimescale: 600)
        let snapped = TimelineSnapEngine.snapTrimStart(
            proposedStart: proposed,
            candidates: snapCandidates,
            threshold: threshold,
            minStart: minStart,
            maxStart: maxStartT
        )
        trimLeftOffset = CGFloat(CMTimeGetSeconds(snapped) - curStart) * pps
    }

    func handleLeftTrimEnded() {
        let deltaSec = Double(trimLeftOffset / pixelsPerSecond)
        trimLeftOffset = 0
        guard abs(deltaSec) > 0.0001 else { return }
        let curStart = CMTimeGetSeconds(clip.timeRange.start)
        let maxStart = curStart + CMTimeGetSeconds(clip.timeRange.duration) - (1.0 / Double(TimeRational.defaultFPS))
        let effDelta = min(maxStart, max(minStartSec, curStart + deltaSec)) - curStart
        let snappedStart = TimeRational.snapToFrame(time: CMTime(seconds: curStart + effDelta, preferredTimescale: 600))
        let newDur = max(1.0 / Double(TimeRational.defaultFPS), CMTimeGetSeconds(clip.timeRange.duration) - effDelta)
        let minDur = TimeRational.time(forFrame: 1)
        let snappedDuration = CMTimeMaximum(minDur, TimeRational.snapToFrame(time: CMTime(seconds: newDur, preferredTimescale: 600)))
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let deltaSourceSec = effDelta * speed
        let newSrc = max(0.0, CMTimeGetSeconds(clip.sourceStartTime) + deltaSourceSec)
        let snappedSource = TimeRational.snapToFrame(time: CMTime(seconds: newSrc, preferredTimescale: 600))
        onTrim(snappedStart, snappedDuration, snappedSource)
    }

    func handleRightTrimChanged(dx: CGFloat) {
        let pps = pixelsPerSecond
        let ppf = pps / CGFloat(TimeRational.defaultFPS)
        let curStart = CMTimeGetSeconds(clip.timeRange.start)
        let curDur = CMTimeGetSeconds(clip.timeRange.duration)
        let proposed = CMTime(seconds: curStart + curDur + Double(round(dx / ppf) * ppf / pps), preferredTimescale: 600)
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)
        let minEnd = CMTime(seconds: curStart + (1.0 / Double(TimeRational.defaultFPS)), preferredTimescale: 600)
        let maxEnd = CMTime(seconds: maxEndSec, preferredTimescale: 600)
        let snapped = TimelineSnapEngine.snapTrimEnd(
            proposedEnd: proposed,
            candidates: snapCandidates,
            threshold: threshold,
            minEnd: minEnd,
            maxEnd: maxEnd
        )
        trimRightOffset = CGFloat((CMTimeGetSeconds(snapped) - curStart) - curDur) * pps
    }

    func handleRightTrimEnded() {
        let deltaSec = Double(trimRightOffset / pixelsPerSecond)
        trimRightOffset = 0
        guard abs(deltaSec) > 0.0001 else { return }
        let curStart = CMTimeGetSeconds(clip.timeRange.start)
        let curDur = CMTimeGetSeconds(clip.timeRange.duration)
        let clampedEnd = max(curStart + (1.0 / Double(TimeRational.defaultFPS)), min(maxEndSec, curStart + curDur + deltaSec))
        let minDur = TimeRational.time(forFrame: 1)
        let snappedDur = CMTimeMaximum(minDur, TimeRational.snapToFrame(time: CMTime(seconds: clampedEnd - curStart, preferredTimescale: 600)))
        onTrim(clip.timeRange.start, snappedDur, nil as CMTime?)
    }
}
