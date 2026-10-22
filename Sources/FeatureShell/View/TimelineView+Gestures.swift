import SwiftUI
import CoreMedia
import Domain
import DesignSystem

extension TimelineView {
    func handleCmdZoom(delta: CGFloat, cursorX: CGFloat) {
        let visibleWidth = enclosingScrollView?.contentView.bounds.width ?? viewModel.viewportWidth
        let cursorXInViewport = max(0, min(visibleWidth, cursorX - DSSize.layerHeaderWidth))
        let oldPPS = viewModel.pixelsPerSecond
        let currentOffset = enclosingScrollView?.contentView.bounds.origin.x ?? scrollOffset
        viewModel.applyZoomDelta(delta)
        let newPPS = viewModel.pixelsPerSecond
        guard newPPS != oldPPS else { return }
        let newContentWidth = viewModel.contentWidth
        let targetOffset = TimelineZoom.anchoredScrollOffset(
            currentScrollOffset: currentOffset,
            cursorXInViewport: cursorXInViewport,
            oldPPS: oldPPS,
            newPPS: newPPS,
            newContentWidth: newContentWidth,
            viewportWidth: visibleWidth
        )
        scrollEnclosing(to: targetOffset, maxDimension: newContentWidth, isVertical: false)
    }

    func handleClipMoving(
        clipID: UUID,
        clipKind: ClipKind,
        from layerID: UUID,
        at index: Int,
        newStart: CMTime,
        dragY: CGFloat
    ) {
        movingClipID = clipID
        movingSourceLayerID = layerID
        pendingStartTime = newStart
        if viewModel.selectedClipIDs.count > 1 && viewModel.selectedClipIDs.contains(clipID) {
            viewModel.updateGroupMove(pivotClipID: clipID, proposedStart: newStart)
        } else {
            viewModel.updateDropTarget(sourceIndex: index, movingClipKind: clipKind, dragY: dragY)
        }
    }

    func handleClipMoveEnd(clipID: UUID) {
        guard let sourceLayerID = movingSourceLayerID else { return }
        if viewModel.selectedClipIDs.count > 1 && viewModel.selectedClipIDs.contains(clipID) {
            let effectiveDelta = viewModel.clampedGroupMoveDelta(pivotClipID: clipID, proposedStart: pendingStartTime)
            viewModel.commitGroupMove(delta: effectiveDelta)
        } else {
            viewModel.moveClip(
                clipID: clipID,
                from: sourceLayerID,
                to: viewModel.hoverLayerID ?? sourceLayerID,
                insertAtIndex: viewModel.dropBetweenIndex,
                newStartTime: pendingStartTime
            )
            if !viewModel.selectedClipIDs.contains(clipID) {
                viewModel.selectClip(clipID)
            }
        }
        playheadState.seek(to: playheadState.currentTime, force: true)
        viewModel.hoverLayerID = nil
        viewModel.dropBetweenIndex = nil
        movingClipID = nil
        movingSourceLayerID = nil
    }

    func handleEmptyCanvasTap(x: CGFloat, pps: CGFloat) {
        isTimelineFocused = true
        viewModel.clearSelection()
        let rawTime = CMTime(seconds: max(0, Double(x / pps)), preferredTimescale: 600)
        let (snapped, didSnap) = TimelineSnapEngine.snapPoint(
            time: rawTime,
            candidates: viewModel.snapCandidateTimes(includePlayhead: false),
            threshold: TimelineSnapEngine.thresholdTime(pixelsPerSecond: pps)
        )
        playheadState.seek(to: didSnap ? snapped : TimeRational.snapToFrame(time: rawTime), force: true)
    }

    func handleMarqueeDrag(value: DragGesture.Value, topSpacerHeight: CGFloat) {
        let start = value.startLocation
        guard start.y <= topSpacerHeight else { return }
        let current = value.location
        let dx = current.x - start.x
        let dy = current.y - start.y
        guard hypot(dx, dy) >= 3 else { return }
        isTimelineFocused = true
        let rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(dx), height: abs(dy))
        marqueeRect = rect
        viewModel.updateMarqueeSelection(rect: rect, topSpacerHeight: topSpacerHeight)
    }

    func handleMarqueeEnd(value: DragGesture.Value, topSpacerHeight: CGFloat, pps: CGFloat) {
        if marqueeRect != nil {
            marqueeRect = nil
        } else if value.startLocation.y <= topSpacerHeight && hypot(value.location.x - value.startLocation.x, value.location.y - value.startLocation.y) < 3 {
            handleEmptyCanvasTap(x: value.location.x, pps: pps)
        }
    }

    func scrollEnclosing(to offset: CGFloat, maxDimension: CGFloat, isVertical: Bool) {
        guard let sv = enclosingScrollView else { return }
        if !isVertical, let doc = sv.documentView, doc.frame.size.width < maxDimension {
            doc.setFrameSize(NSSize(width: maxDimension, height: doc.frame.size.height))
        }
        let visible = isVertical ? sv.contentView.bounds.height : sv.contentView.bounds.width
        let clamped = max(0, min(max(0, maxDimension - max(1.0, visible)), offset))
        let pt = isVertical
            ? NSPoint(x: sv.contentView.bounds.origin.x, y: clamped)
            : NSPoint(x: clamped, y: sv.contentView.bounds.origin.y)
        sv.contentView.scroll(to: pt)
        sv.reflectScrolledClipView(sv.contentView)
        if isVertical {
            verticalScrollOffset = clamped
        } else {
            scrollOffset = clamped
        }
    }
}
