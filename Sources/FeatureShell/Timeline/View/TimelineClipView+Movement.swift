import SwiftUI
import AppKit
import CoreMedia
import Domain

extension TimelineClipView {
    var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { handleMoveChanged(value: $0) }
            .onEnded { handleMoveEnded(value: $0) }
    }

    func handleMoveChanged(value: DragGesture.Value) {
        guard !isTrimming else { return }
        guard trimLeftOffset == 0 && trimRightOffset == 0 else { return }
        guard groupTrimLeftOffset == 0 && groupTrimRightOffset == 0 else { return }
        guard isActivelyDragging || dragOffset != 0 || dragY != 0 || (!isHoveringLeftTrim && !isHoveringRightTrim) else { return }
        guard !isLocked else { return }

        isActivelyDragging = true
        let optionNow = modifierState?.isOptionPressed ?? NSEvent.modifierFlags.contains(.option)
        if isOptionDuplicateDrag != optionNow {
            isOptionDuplicateDrag = optionNow
            if optionNow {
                NSCursor.dragCopy.set()
            } else {
                NSCursor.arrow.set()
            }
        } else if optionNow {
            NSCursor.dragCopy.set()
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
        let effectiveCandidates = filteredSnapCandidates(rawDx: rawDx, currentStartSec: currentStartSec)
        let (snappedStart, didSnap) = TimelineSnapEngine.snapClipMove(
            proposedStart: rawStart, duration: clip.timeRange.duration,
            candidates: effectiveCandidates, threshold: threshold
        )
        var effectiveStart = isShiftVerticalLock ? clip.timeRange.start : (didSnap ? snappedStart : TimeRational.snapToFrame(time: rawStart))

        if !isOptionDuplicateDrag && abs(dragY) < 15 && groupDragOffset == 0 {
            if let prevEnd = previousClipEnd, effectiveStart < prevEnd { effectiveStart = prevEnd }
            if let nextStart = nextClipStart {
                let maxStart = CMTimeSubtract(nextStart, clip.timeRange.duration)
                if maxStart >= .zero && effectiveStart > maxStart { effectiveStart = maxStart }
            }
        }

        lastProposedStart = effectiveStart
        dragOffset = CGFloat(CMTimeGetSeconds(effectiveStart) - currentStartSec) * pixelsPerSecond
        onMove(effectiveStart, dragY)
    }

    func handleMoveEnded(value: DragGesture.Value) {
        guard !isLocked else { return }
        let optionNow = modifierState?.isOptionPressed ?? NSEvent.modifierFlags.contains(.option)
        let shouldDuplicate = isOptionDuplicateDrag || optionNow
        defer {
            isActivelyDragging = false
            dragOffset = 0
            dragY = 0
            lastProposedStart = nil
            isOptionDuplicateDrag = false
            NSCursor.arrow.set()
            if shouldDuplicate, let onDuplicateMoveEnd {
                onDuplicateMoveEnd()
            } else {
                onMoveEnd()
            }
        }
        if !isSelected { onSelect(false) }
    }

    /// Tránh lực hít snap giữ chặt clip lại tại điểm xuất phát trong ~12px đầu tiên khi mới nhấc clip đi.
    private func filteredSnapCandidates(rawDx: CGFloat, currentStartSec: Double) -> [CMTime] {
        guard abs(rawDx) > 0 && abs(rawDx) <= 12.0 else {
            return snapCandidates
        }
        let currentEndSec = currentStartSec + CMTimeGetSeconds(clip.timeRange.duration)
        return snapCandidates.filter { candidate in
            let sec = CMTimeGetSeconds(candidate)
            return abs(sec - currentStartSec) > 0.005 && abs(sec - currentEndSec) > 0.005
        }
    }
}
