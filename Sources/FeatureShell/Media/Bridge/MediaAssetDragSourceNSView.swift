import AppKit
import AVFoundation
import CoreMedia
import Domain
import DesignSystem

// MARK: - MediaAssetDragSourceNSView

/// Transparent NSView overlay that handles pointer events for any sidebar library card item.
/// Initiates a native AppKit drag session with a compact thumbnail card (or cyan pill for transitions)
/// outside the timeline, and pre-warms the 1:1 clip block image at the timeline's active zoom level.
public final class MediaAssetDragSourceNSView: NSView {

    // MARK: Configuration

    public var asset: MediaAsset? {
        didSet {
            if let asset {
                dragPayload = .media(asset)
            }
        }
    }
    public var dragPayload: TimelineDragPayload?
    public var onSelect: ((Bool) -> Void)?
    public var onAddToTimeline: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onToggleFavorite: (() -> Void)?
    public var onHover: ((Bool) -> Void)?

    // MARK: Constants

    private static let dragThreshold: CGFloat = 4
    private static let plusButtonSize: CGFloat = 30

    // MARK: State

    private var mouseDownEvent: NSEvent?
    private var isClickingAddButton = false
    private var isClickingTopRightButton = false
    private var trackingArea: NSTrackingArea?

    // MARK: NSView

    override public var isFlipped: Bool { true }

    public var plusButtonHitRect: NSRect {
        let size = Self.plusButtonSize
        let w = bounds.width
        return NSRect(x: max(0, w - size), y: max(0, w - size), width: size, height: size)
    }

    public var deleteButtonHitRect: NSRect {
        let size = Self.plusButtonSize
        let w = bounds.width
        return NSRect(x: max(0, w - size), y: 0, width: size, height: size)
    }

    private var hasTopRightAction: Bool {
        onDelete != nil || onToggleFavorite != nil
    }

    override public func resetCursorRects() {
        super.resetCursorRects()
        if onAddToTimeline != nil && bounds.width >= Self.plusButtonSize {
            addCursorRect(plusButtonHitRect, cursor: .pointingHand)
        }
        if hasTopRightAction && bounds.width >= Self.plusButtonSize {
            addCursorRect(deleteButtonHitRect, cursor: .pointingHand)
        }
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override public func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override public func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    // MARK: Mouse events

    override public func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if hasTopRightAction && deleteButtonHitRect.contains(localPoint) {
            isClickingTopRightButton = true
            mouseDownEvent = event
            return
        }
        if onAddToTimeline != nil && plusButtonHitRect.contains(localPoint) {
            isClickingAddButton = true
            mouseDownEvent = event
            return
        }
        isClickingTopRightButton = false
        isClickingAddButton = false
        mouseDownEvent = event
        let isCmd = event.modifierFlags.contains(.command)
        onSelect?(isCmd)
    }

    override public func mouseDragged(with event: NSEvent) {
        if isClickingAddButton || isClickingTopRightButton { return }
        guard let downEvent = mouseDownEvent else { return }
        guard displaceExceedsThreshold(event: event, origin: downEvent) else { return }
        mouseDownEvent = nil
        startDragSession(from: downEvent)
    }

    override public func mouseUp(with event: NSEvent) {
        if isClickingTopRightButton {
            isClickingTopRightButton = false
            mouseDownEvent = nil
            let localPoint = convert(event.locationInWindow, from: nil)
            if deleteButtonHitRect.contains(localPoint) {
                if let onToggleFavorite {
                    onToggleFavorite()
                } else {
                    onDelete?()
                }
            }
            return
        }
        if isClickingAddButton {
            isClickingAddButton = false
            mouseDownEvent = nil
            let localPoint = convert(event.locationInWindow, from: nil)
            if plusButtonHitRect.contains(localPoint) {
                onAddToTimeline?()
            }
            return
        }
        mouseDownEvent = nil
    }

    // MARK: Drag session

    private func displaceExceedsThreshold(event: NSEvent, origin: NSEvent) -> Bool {
        let dx = event.locationInWindow.x - origin.locationInWindow.x
        let dy = event.locationInWindow.y - origin.locationInWindow.y
        return dx * dx + dy * dy > Self.dragThreshold * Self.dragThreshold
    }

    private func resolvedPayload() -> TimelineDragPayload? {
        if let dragPayload { return dragPayload }
        if let asset { return .media(asset) }
        return nil
    }

    private func startDragSession(from downEvent: NSEvent) {
        guard let payload = resolvedPayload() else { return }
        TransitionDragSessionState.shared.begin(payload: payload)

        if let kind = payload.clipKind {
            let dur = payload.resolvedDuration()
            let pps = TransitionDragSessionState.shared.timelinePixelsPerSecond
            let (targetW, targetH) = TimelineClipBlockRenderer.blockDimensions(
                for: kind,
                duration: dur,
                pixelsPerSecond: pps
            )
            let thumb: NSImage? = {
                if case .media(let asset) = payload, kind == .video {
                    return TimelineClipBlockRenderer.quickThumbnail(for: asset.url)
                }
                return nil
            }()
            _ = TimelineClipBlockRenderer.renderImage(
                name: payload.displayName,
                duration: dur,
                kind: kind,
                width: targetW,
                height: targetH,
                thumbnail: thumb
            )
        }

        let dragImg = TimelineClipBlockRenderer.dragThumbnail(for: payload)
        let item = makeDragItem(payload: payload, dragImg: dragImg, event: downEvent)
        let session = beginDraggingSession(with: [item], event: downEvent, source: self)
        session.draggingFormation = .none
    }

    private func makeDragItem(
        payload: TimelineDragPayload,
        dragImg: NSImage,
        event: NSEvent
    ) -> NSDraggingItem {
        let writer: any NSPasteboardWriting = {
            if case .media(let mediaAsset) = payload {
                return mediaAsset.url as NSURL
            }
            let pbItem = NSPasteboardItem()
            pbItem.setString(payload.pasteboardToken, forType: .string)
            return pbItem
        }()

        let item = NSDraggingItem(pasteboardWriter: writer)
        let size = dragImg.size
        let localCursor = convert(event.locationInWindow, from: nil)
        let isTransition = payload.transitionPresetID != nil
        let originX = isTransition ? (localCursor.x - size.width * 0.5) : localCursor.x
        let frame = NSRect(
            x: originX,
            y: localCursor.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        item.setDraggingFrame(frame, contents: dragImg)
        let comp = NSDraggingImageComponent(key: .icon)
        comp.contents = dragImg
        comp.frame = NSRect(origin: .zero, size: size)
        item.imageComponentsProvider = { [comp] }
        return item
    }
}

// MARK: - NSDraggingSource

extension MediaAssetDragSourceNSView: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    public func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        isClickingAddButton = false
        isClickingTopRightButton = false
        TransitionDragSessionState.shared.clear()
    }
}
