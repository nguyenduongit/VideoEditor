import AppKit
import SwiftUI
import Domain
import DesignSystem

/// SwiftUI bridge nhúng `MediaAssetDragSourceNSView` cho thẻ Transition,
/// đồng thời cung cấp hàm vẽ khối overlay màu xanh lơ (Cyan) cho phiên kéo thả Transition.
/// Tuân thủ AGENTS.md R1 (File <= 300 dòng, Hàm <= 50 dòng).
public struct TransitionDragBridgeView: NSViewRepresentable {
    private let item: TransitionLibraryItem
    private let onSelect: () -> Void
    private let onAddToTimeline: () -> Void
    private let onToggleFavorite: () -> Void
    private let onHover: ((Bool) -> Void)?

    public init(
        item: TransitionLibraryItem,
        onSelect: @escaping () -> Void = {},
        onAddToTimeline: @escaping () -> Void = {},
        onToggleFavorite: @escaping () -> Void = {},
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.item = item
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onToggleFavorite = onToggleFavorite
        self.onHover = onHover
    }

    public func makeNSView(context: Context) -> MediaAssetDragSourceNSView {
        let view = MediaAssetDragSourceNSView()
        configure(view)
        return view
    }

    public func updateNSView(_ nsView: MediaAssetDragSourceNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: MediaAssetDragSourceNSView) {
        view.dragPayload = .transition(item)
        view.onSelect = { _ in onSelect() }
        view.onAddToTimeline = onAddToTimeline
        view.onToggleFavorite = onToggleFavorite
        view.onHover = onHover
    }
}

// MARK: - TransitionDragSourceNSView (Cyan Preview Renderer)

public enum TransitionDragSourceNSView {
    /// Draws a Cyan rectangle overlay with center line marker and hourglass badge.
    public static func renderCyanOverlayImage(
        for item: TransitionLibraryItem,
        width: CGFloat,
        height: CGFloat
    ) -> NSImage {
        renderCyanOverlayImage(width: width, height: height)
    }

    public static func renderCyanOverlayImage(
        width: CGFloat,
        height: CGFloat
    ) -> NSImage {
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
