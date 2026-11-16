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
        guard !isTrimming else { return }
        guard trimLeftOffset == 0 && trimRightOffset == 0 else { return }
        guard groupTrimLeftOffset == 0 && groupTrimRightOffset == 0 else { return }
        guard dragOffset != 0 || dragY != 0 || (!isHoveringLeftTrim && !isHoveringRightTrim) else { return }
        guard !isLocked else { return }

        if dragOffset == 0 && dragY == 0 {
            isOptionDuplicateDrag = NSEvent.modifierFlags.contains(.option)
        } else if NSEvent.modifierFlags.contains(.option) {
            isOptionDuplicateDrag = true
        }
        if !isSelected { onSelect(false) }

        let isShiftVerticalLock = NSEvent.modifierFlags.contains(.shift) && abs(value.translation.height) >= 15
        let rawDx = isShiftVerticalLock ? 0 : value.translation.width
        dragY = value.translation.height
        let deltaSeconds = Double(rawDx / pixelsPerSecond)
        let currentStartSec = CMTimeGetSeconds(clip.timeRange.start)
        var rawStartSec = max(0, currentStartSec + deltaSeconds)

        if !isOptionDuplicateDrag && abs(dragY) < 15 && groupDragOffset == 0 {
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
        var effectiveStart = isShiftVerticalLock ? clip.timeRange.start : (didSnap ? snappedStart : TimeRational.snapToFrame(time: rawStart))

        if !isOptionDuplicateDrag && abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd, effectiveStart < prevEnd { effectiveStart = prevEnd }
            if let nextStart = nextClipStart {
                let maxStart = CMTimeSubtract(nextStart, clip.timeRange.duration)
                if maxStart >= .zero && effectiveStart > maxStart { effectiveStart = maxStart }
            }
        }

        dragOffset = CGFloat(CMTimeGetSeconds(effectiveStart) - currentStartSec) * pixelsPerSecond
        onMove(effectiveStart, dragY)
    }

    func handleMoveEnded(value: DragGesture.Value) {
        guard !isLocked else { return }
        let shouldDuplicate = isOptionDuplicateDrag || NSEvent.modifierFlags.contains(.option)
        defer {
            dragOffset = 0
            dragY = 0
            isOptionDuplicateDrag = false
            if shouldDuplicate, let onDuplicateMoveEnd {
                onDuplicateMoveEnd()
            } else {
                onMoveEnd()
            }
        }
        if !isSelected { onSelect(false) }
    }
}
