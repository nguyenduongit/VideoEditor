import SwiftUI
import CoreMedia
import Domain

extension TimelineClipView {
    var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { handleMoveChanged(value: $0) }
            .onEnded { handleMoveEnded(value: $0) }
    }

    func handleMoveChanged(value: DragGesture.Value) {
        guard !isHoveringLeftTrim && !isHoveringRightTrim else { return }
        guard !isLocked else { return }

        if !isSelected { onSelect(false) }
        let rawDx = value.translation.width
        dragY = value.translation.height
        let deltaSeconds = Double(rawDx / pixelsPerSecond)
        let currentStartSec = CMTimeGetSeconds(clip.timeRange.start)
        var rawStartSec = max(0, currentStartSec + deltaSeconds)

        if abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd { rawStartSec = max(rawStartSec, CMTimeGetSeconds(prevEnd)) }
            if let nextStart = nextClipStart {
                let maxStartSec = max(0, CMTimeGetSeconds(nextStart) - CMTimeGetSeconds(clip.timeRange.duration))
                rawStartSec = min(rawStartSec, maxStartSec)
            }
        }

        let rawStart = CMTime(seconds: rawStartSec, preferredTimescale: 600)
        let threshold = TimelineSnapEngine.thresholdTime(pixelsPerSecond: pixelsPerSecond)
        let (snappedStart, didSnap) = TimelineSnapEngine.snapClipMove(
            proposedStart: rawStart, duration: clip.timeRange.duration,
            candidates: snapCandidates, threshold: threshold
        )
        var effectiveStart = didSnap ? snappedStart : TimeRational.snapToFrame(time: rawStart)

        if abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd, effectiveStart < prevEnd { effectiveStart = prevEnd }
            if let nextStart = nextClipStart {
                let maxStart = CMTimeSubtract(nextStart, clip.timeRange.duration)
                if maxStart >= .zero && effectiveStart > maxStart { effectiveStart = maxStart }
            }
        }

        let effectiveDx = CGFloat(CMTimeGetSeconds(effectiveStart) - currentStartSec) * pixelsPerSecond
        dragOffset = effectiveDx
        onMove(effectiveStart, dragY)
    }

    func handleMoveEnded(value: DragGesture.Value) {
        guard !isHoveringLeftTrim && !isHoveringRightTrim else { return }
        guard !isLocked else { return }
        dragOffset = 0
        dragY = 0
        if !isSelected { onSelect(false) }
        onMoveEnd()
    }
}
