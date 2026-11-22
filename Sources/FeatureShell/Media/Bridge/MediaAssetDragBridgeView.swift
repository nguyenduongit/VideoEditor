import AppKit
import SwiftUI
import Domain

/// SwiftUI wrapper that places `MediaAssetDragSourceNSView` as a transparent overlay
/// on top of a sidebar library card, intercepting pointer events for unified drag-to-timeline handling.
public struct MediaAssetDragBridgeView: NSViewRepresentable {
    private let payload: TimelineDragPayload
    private let onSelect: (Bool) -> Void
    private let onAddToTimeline: (() -> Void)?
    private let onDelete: (() -> Void)?
    private let onToggleFavorite: (() -> Void)?
    private let onHover: ((Bool) -> Void)?

    public init(
        asset: MediaAsset,
        onSelect: @escaping (Bool) -> Void,
        onAddToTimeline: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.payload = .media(asset)
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onDelete = onDelete
        self.onToggleFavorite = nil
        self.onHover = onHover
    }

    public init(
        payload: TimelineDragPayload,
        onSelect: @escaping (Bool) -> Void,
        onAddToTimeline: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.payload = payload
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onDelete = onDelete
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
        view.dragPayload = payload
        if case .media(let asset) = payload {
            view.asset = asset
        }
        view.onSelect = onSelect
        view.onAddToTimeline = onAddToTimeline
        view.onDelete = onDelete
        view.onToggleFavorite = onToggleFavorite
        view.onHover = onHover
    }
}
