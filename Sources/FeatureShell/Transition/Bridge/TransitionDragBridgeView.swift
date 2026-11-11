import AppKit
import SwiftUI
import Domain
import DesignSystem

/// SwiftUI bridge nhúng `TransitionDragSourceNSView` làm lớp phủ trong suốt trên thẻ Transition,
/// khởi tạo phiên kéo thả AppKit với hình ảnh đại diện là khối overlay màu xanh lơ (Cyan) thay vì thumbnail.
/// Tuân thủ AGENTS.md R1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.
public struct TransitionDragBridgeView: NSViewRepresentable {
    private let preset: TransitionPreset
    private let onSelect: () -> Void
    private let onAddToTimeline: () -> Void
    private let onToggleFavorite: () -> Void
    private let onHover: ((Bool) -> Void)?

    public init(
        preset: TransitionPreset,
        onSelect: @escaping () -> Void = {},
        onAddToTimeline: @escaping () -> Void = {},
        onToggleFavorite: @escaping () -> Void = {},
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.preset = preset
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onToggleFavorite = onToggleFavorite
        self.onHover = onHover
    }

    public func makeNSView(context: Context) -> TransitionDragSourceNSView {
        let view = TransitionDragSourceNSView()
        configure(view)
        return view
    }

    public func updateNSView(_ nsView: TransitionDragSourceNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: TransitionDragSourceNSView) {
        view.preset = preset
        view.onSelect = onSelect
        view.onAddToTimeline = onAddToTimeline
        view.onToggleFavorite = onToggleFavorite
        view.onHover = onHover
    }
}

// MARK: - TransitionDragSourceNSView

public final class TransitionDragSourceNSView: NSView {
    public var preset: TransitionPreset?
    public var onSelect: (() -> Void)?
    public var onAddToTimeline: (() -> Void)?
    public var onToggleFavorite: (() -> Void)?
    public var onHover: ((Bool) -> Void)?

    private static let dragThreshold: CGFloat = 4.0
    private static let buttonHitSize: CGFloat = 28.0

    private var mouseDownEvent: NSEvent?
    private var isClickingAddButton = false
    private var isClickingFavoriteButton = false
    private var trackingArea: NSTrackingArea?

    override public var isFlipped: Bool { true }

    public var favoriteButtonHitRect: NSRect {
        let size = Self.buttonHitSize
        let w = bounds.width
        return NSRect(x: max(0, w - size - 4), y: 4, width: size, height: size)
    }

    public var plusButtonHitRect: NSRect {
        let size = Self.buttonHitSize
        let w = bounds.width
        let h = bounds.height
        return NSRect(x: max(0, w - size - 4), y: max(0, h - size - 4), width: size, height: size)
    }

    override public func resetCursorRects() {
        super.resetCursorRects()
        if bounds.width >= Self.buttonHitSize {
            addCursorRect(favoriteButtonHitRect, cursor: .pointingHand)
            addCursorRect(plusButtonHitRect, cursor: .pointingHand)
        }
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override public func mouseEntered(with event: NSEvent) { onHover?(true) }
    override public func mouseExited(with event: NSEvent) { onHover?(false) }

    override public func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        if favoriteButtonHitRect.contains(local) {
            isClickingFavoriteButton = true
            mouseDownEvent = event
            return
        }
        if plusButtonHitRect.contains(local) {
            isClickingAddButton = true
            mouseDownEvent = event
            return
        }
        isClickingFavoriteButton = false
        isClickingAddButton = false
        mouseDownEvent = event
        onSelect?()
    }

    override public func mouseDragged(with event: NSEvent) {
        if isClickingAddButton || isClickingFavoriteButton { return }
        guard let downEvent = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - downEvent.locationInWindow.x
        let dy = event.locationInWindow.y - downEvent.locationInWindow.y
        guard dx * dx + dy * dy > Self.dragThreshold * Self.dragThreshold else { return }
        mouseDownEvent = nil
        startDragSession(from: downEvent)
    }

    override public func mouseUp(with event: NSEvent) {
        if isClickingFavoriteButton {
            isClickingFavoriteButton = false
            mouseDownEvent = nil
            let local = convert(event.locationInWindow, from: nil)
            if favoriteButtonHitRect.contains(local) { onToggleFavorite?() }
            return
        }
        if isClickingAddButton {
            isClickingAddButton = false
            mouseDownEvent = nil
            let local = convert(event.locationInWindow, from: nil)
            if plusButtonHitRect.contains(local) { onAddToTimeline?() }
            return
        }
        mouseDownEvent = nil
    }

    private func startDragSession(from downEvent: NSEvent) {
        guard let preset else { return }
        TransitionDragSessionState.shared.activePresetID = preset.id

        let overlayImg = Self.renderCyanOverlayImage(for: preset, width: 100, height: 32)
        let pbItem = NSPasteboardItem()
        pbItem.setString("transition:\(preset.id)", forType: .string)
        let item = NSDraggingItem(pasteboardWriter: pbItem)

        let localCursor = convert(downEvent.locationInWindow, from: nil)
        let frame = NSRect(
            x: localCursor.x - overlayImg.size.width * 0.5,
            y: localCursor.y - overlayImg.size.height * 0.5,
            width: overlayImg.size.width,
            height: overlayImg.size.height
        )
        item.setDraggingFrame(frame, contents: overlayImg)
        let comp = NSDraggingImageComponent(key: .icon)
        comp.contents = overlayImg
        comp.frame = NSRect(origin: .zero, size: overlayImg.size)
        item.imageComponentsProvider = { [comp] }

        let session = beginDraggingSession(with: [item], event: downEvent, source: self)
        session.draggingFormation = .none
    }

    /// Vẽ khối hình chữ nhật overlay màu xanh lơ (Cyan) có vạch chia trung tâm và biểu tượng đồng hồ cát.
    public static func renderCyanOverlayImage(for preset: TransitionPreset, width: CGFloat, height: CGFloat) -> NSImage {
        let size = NSSize(width: width, height: height)
        let img = NSImage(size: size)
        img.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.0, dy: 1.0), xRadius: 5.0, yRadius: 5.0)
        NSColor(DSColors.toggleCyan).withAlphaComponent(0.78).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.95).setStroke()
        path.lineWidth = 1.4
        path.stroke()

        let midLine = NSRect(x: width * 0.5 - 0.75, y: 0, width: 1.5, height: height)
        NSColor.white.withAlphaComponent(0.90).setFill()
        midLine.fill()

        let badgeRect = NSRect(x: width * 0.5 - 8.0, y: height * 0.5 - 8.0, width: 16.0, height: 16.0)
        let circle = NSBezierPath(ovalIn: badgeRect)
        NSColor.black.withAlphaComponent(0.45).setFill()
        circle.fill()

        let text = NSString(string: "⏳")
        let font = NSFont.systemFont(ofSize: 9.0)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: width * 0.5 - textSize.width * 0.5,
            y: height * 0.5 - textSize.height * 0.5 - 0.5,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
        img.unlockFocus()
        return img
    }
}

// MARK: - NSDraggingSource

extension TransitionDragSourceNSView: NSDraggingSource {
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
        isClickingFavoriteButton = false
        TransitionDragSessionState.shared.activePresetID = nil
    }
}

