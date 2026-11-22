import SwiftUI
import AppKit

/// Tay kéo cắt biên (Trim Handle) dùng AppKit `NSView` gốc để đảm bảo:
/// - Con trỏ 2 chiều (`resizeLeftRight`) bám chính xác từng pixel trong `NSScrollView` qua `resetCursorRects()`
/// - Không bị lệch vị trí hay mất con trỏ khi cuộn/zoom/kéo thả nhờ theo dõi tọa độ màn hình trực tiếp.
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Hàm <= 50 dòng).
public struct ClipTrimHandleView: View {
    private let isLeft: Bool
    private let width: CGFloat
    private let height: CGFloat
    private let isSelected: Bool
    @Binding private var isHovering: Bool
    private let onSelectIfNeeded: () -> Void
    private let onTap: () -> Void
    private let onTrimChanged: (CGFloat) -> Void
    private let onTrimEnded: () -> Void

    public static let handleHitWidth: CGFloat = 10.0

    public init(
        isLeft: Bool,
        width: CGFloat = ClipTrimHandleView.handleHitWidth,
        height: CGFloat,
        isSelected: Bool = true,
        isHovering: Binding<Bool>,
        onSelectIfNeeded: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {},
        onTrimChanged: @escaping (CGFloat) -> Void,
        onTrimEnded: @escaping () -> Void
    ) {
        self.isLeft = isLeft
        self.width = width
        self.height = height
        self.isSelected = isSelected
        self._isHovering = isHovering
        self.onSelectIfNeeded = onSelectIfNeeded
        self.onTap = onSelect
        self.onTrimChanged = onTrimChanged
        self.onTrimEnded = onTrimEnded
    }

    public var body: some View {
        ClipTrimHandleBridge(
            isLeft: isLeft,
            isSelected: isSelected,
            onHoverChanged: { hovering in
                if isHovering != hovering {
                    isHovering = hovering
                }
            },
            onSelectIfNeeded: onSelectIfNeeded,
            onTap: onTap,
            onTrimChanged: onTrimChanged,
            onTrimEnded: onTrimEnded
        )
        .frame(width: width, height: height)
        .contentShape(Rectangle())
    }
}

// MARK: - AppKit Cursor & Drag Bridge (Private Cohesion)

private struct ClipTrimHandleBridge: NSViewRepresentable {
    let isLeft: Bool
    let isSelected: Bool
    let onHoverChanged: (Bool) -> Void
    let onSelectIfNeeded: () -> Void
    let onTap: () -> Void
    let onTrimChanged: (CGFloat) -> Void
    let onTrimEnded: () -> Void

    func makeNSView(context: Context) -> ClipTrimHandleNSView {
        let view = ClipTrimHandleNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: ClipTrimHandleNSView, context: Context) {
        configure(nsView)
        nsView.refreshCursorRects()
    }

    static func dismantleNSView(_ nsView: ClipTrimHandleNSView, coordinator: ()) {
        nsView.cleanup()
    }

    private func configure(_ view: ClipTrimHandleNSView) {
        view.isSelected = isSelected
        view.onHoverChanged = onHoverChanged
        view.onSelectIfNeeded = onSelectIfNeeded
        view.onTap = onTap
        view.onTrimChanged = onTrimChanged
        view.onTrimEnded = onTrimEnded
    }
}

private final class ClipTrimHandleNSView: NSView {
    var isSelected: Bool = true
    var onHoverChanged: ((Bool) -> Void)?
    var onSelectIfNeeded: (() -> Void)?
    var onTap: (() -> Void)?
    var onTrimChanged: ((CGFloat) -> Void)?
    var onTrimEnded: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isDragging: Bool = false
    private var dragStartScreenX: CGFloat = 0

    override var isFlipped: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        discardCursorRects()
        let rect = visibleRect
        if !rect.isEmpty {
            addCursorRect(rect, cursor: .resizeLeftRight)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .cursorUpdate,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshCursorRects()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        refreshCursorRects()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshCursorRects()
    }

    override func layout() {
        super.layout()
        refreshCursorRects()
    }

    func refreshCursorRects() {
        window?.invalidateCursorRects(for: self)
    }

    func cleanup() {
        if isDragging {
            isDragging = false
        }
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        onHoverChanged?(false)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        guard !isDragging else { return }
        onHoverChanged?(false)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartScreenX = NSEvent.mouseLocation.x
        NSCursor.resizeLeftRight.set()
        if !isSelected {
            onSelectIfNeeded?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        NSCursor.resizeLeftRight.set()
        let dx = NSEvent.mouseLocation.x - dragStartScreenX
        onTrimChanged?(dx)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        let movedDistance = abs(NSEvent.mouseLocation.x - dragStartScreenX)
        isDragging = false
        onTrimEnded?()
        if movedDistance < 1.5 {
            onTap?()
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        let isInside = bounds.contains(localPoint) && !visibleRect.isEmpty && visibleRect.contains(localPoint)
        onHoverChanged?(isInside)
        if isInside {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.arrow.set()
        }
        refreshCursorRects()
    }
}
