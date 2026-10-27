import AppKit
import AVFoundation
import CoreMedia
import Domain
import DesignSystem

// MARK: - MediaAssetDragSourceNSView

/// Transparent NSView overlay that handles pointer events for a media asset item.
/// Initiates a native AppKit drag session with a compact thumbnail card outside timeline.
/// When the cursor enters the timeline, the drop target transitions it to a 1:1 clip block.
public final class MediaAssetDragSourceNSView: NSView {

    // MARK: Configuration

    public var asset: MediaAsset?
    public var onSelect: ((Bool) -> Void)?
    public var onAddToTimeline: (() -> Void)?
    public var onHover: ((Bool) -> Void)?

    // MARK: Constants

    private static let previewPixelsPerSecond: CGFloat = 100
    private static let minBlockWidth: CGFloat = 140
    private static let maxBlockWidth: CGFloat = 800
    private static let dragThreshold: CGFloat = 4
    private static let plusButtonSize: CGFloat = 30

    // MARK: State

    private var mouseDownEvent: NSEvent?
    private var isClickingAddButton = false
    private var trackingArea: NSTrackingArea?

    // MARK: NSView

    override public var isFlipped: Bool { true }

    public var plusButtonHitRect: NSRect {
        let size = Self.plusButtonSize
        let w = bounds.width
        return NSRect(x: max(0, w - size), y: max(0, w - size), width: size, height: size)
    }

    override public func resetCursorRects() {
        super.resetCursorRects()
        if onAddToTimeline != nil && bounds.width >= Self.plusButtonSize {
            addCursorRect(plusButtonHitRect, cursor: .pointingHand)
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
        if onAddToTimeline != nil && plusButtonHitRect.contains(localPoint) {
            isClickingAddButton = true
            mouseDownEvent = event
            return
        }
        isClickingAddButton = false
        mouseDownEvent = event
        let isCmd = event.modifierFlags.contains(.command)
        onSelect?(isCmd)
    }

    override public func mouseDragged(with event: NSEvent) {
        if isClickingAddButton { return }
        guard let downEvent = mouseDownEvent else { return }
        guard displaceExceedsThreshold(event: event, origin: downEvent) else { return }
        mouseDownEvent = nil
        startDragSession(from: downEvent)
    }

    override public func mouseUp(with event: NSEvent) {
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

    private func startDragSession(from downEvent: NSEvent) {
        guard let asset else { return }
        let url = asset.url
        guard let mediaType = MediaType.from(fileExtension: url.pathExtension) else { return }

        let kind = mediaType.clipKind
        let dur = resolveDuration(url: url, type: mediaType)
        let (targetW, targetH) = blockDimensions(kind: kind, duration: dur)

        // Pre-warm the clip block image into cache for zero-latency transition upon timeline entry
        _ = renderBlockImage(
            url: url, kind: kind, duration: dur, width: targetW, height: targetH
        )

        // Drag session outside timeline ALWAYS displays a compact thumbnail card
        let thumbImg = TimelineClipBlockRenderer.dragThumbnail(for: url, type: mediaType)
        let thumbSize = thumbImg.size

        let item = makeDragItem(
            url: url,
            thumbImg: thumbImg,
            size: thumbSize,
            event: downEvent
        )
        let session = beginDraggingSession(with: [item], event: downEvent, source: self)
        session.draggingFormation = .none
    }

    private func resolveDuration(url: URL, type: MediaType) -> CMTime {
        TimelineMediaDurationResolver.resolveDuration(for: url, type: type)
            ?? CMTime(seconds: 5, preferredTimescale: 600)
    }

    private func blockDimensions(kind: ClipKind, duration: CMTime) -> (CGFloat, CGFloat) {
        let h: CGFloat = kind.presentation.defaultLayerHeight - 6
        let rawW = CGFloat(CMTimeGetSeconds(duration)) * Self.previewPixelsPerSecond
        let w = max(Self.minBlockWidth, min(Self.maxBlockWidth, rawW))
        return (w, h)
    }

    private func renderBlockImage(
        url: URL, kind: ClipKind, duration: CMTime, width: CGFloat, height: CGFloat
    ) -> NSImage? {
        let thumb = (kind == .video) ? TimelineClipBlockRenderer.quickThumbnail(for: url) : nil
        return TimelineClipBlockRenderer.renderImage(
            name: url.lastPathComponent,
            duration: duration,
            kind: kind,
            width: width,
            height: height,
            thumbnail: thumb
        )
    }

    /// Builds an `NSDraggingItem` whose frame anchors the **left edge**
    /// directly under the cursor (anchorX = 0.0) so the cursor and ruler guide
    /// remain at the head (cạnh trái) throughout the drag session.
    private func makeDragItem(
        url: URL, thumbImg: NSImage, size: NSSize, event: NSEvent
    ) -> NSDraggingItem {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let localCursor = convert(event.locationInWindow, from: nil)
        let frame = NSRect(
            x: localCursor.x,
            y: localCursor.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        item.setDraggingFrame(frame, contents: thumbImg)
        let comp = NSDraggingImageComponent(key: .icon)
        comp.contents = thumbImg
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
    }
}
