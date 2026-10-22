import AppKit
import SwiftUI
import Domain

/// SwiftUI wrapper that places `MediaAssetDragSourceNSView` as a transparent overlay
/// on top of the media-asset card, intercepting pointer events for custom drag handling.
public struct MediaAssetDragBridgeView: NSViewRepresentable {
    private let asset: MediaAsset
    private let onSelect: (Bool) -> Void
    private let onAddToTimeline: (() -> Void)?
    private let onHover: ((Bool) -> Void)?

    public init(
        asset: MediaAsset,
        onSelect: @escaping (Bool) -> Void,
        onAddToTimeline: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil
    ) {
        self.asset = asset
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onHover = onHover
    }

    public func makeNSView(context: Context) -> MediaAssetDragSourceNSView {
        let view = MediaAssetDragSourceNSView()
        view.asset = asset
        view.onSelect = onSelect
        view.onAddToTimeline = onAddToTimeline
        view.onHover = onHover
        return view
    }

    public func updateNSView(_ nsView: MediaAssetDragSourceNSView, context: Context) {
        nsView.asset = asset
        nsView.onSelect = onSelect
        nsView.onAddToTimeline = onAddToTimeline
        nsView.onHover = onHover
    }
}
