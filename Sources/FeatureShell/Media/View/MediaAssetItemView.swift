import AppKit
import SwiftUI
import Domain
import DesignSystem

/// Card component for user local media assets in the Left Sidebar 2-column grid.
/// Conforms to unified layout via `UnifiedLibraryCardItemView`:
/// - No favorite button (local assets do not have favorites)
/// - 26pt Add (+) button on hover at bottom-right
/// - AppKit `MediaAssetDragBridgeView` overlay for native drag-to-timeline and click dispatching.
/// Complies with AGENTS.md R3.1 (File <= 300 lines).
public struct MediaAssetItemView<Thumbnail: View>: View {
    private let asset: MediaAsset
    private let isSelected: Bool
    private let onSelect: (Bool) -> Void
    private let onAddToTimeline: () -> Void
    private let onDelete: () -> Void
    private let thumbnail: () -> Thumbnail

    @State private var isHovered: Bool = false

    public init(
        asset: MediaAsset,
        isSelected: Bool,
        onSelect: @escaping (Bool) -> Void,
        onAddToTimeline: @escaping () -> Void,
        onDelete: @escaping () -> Void = {},
        @ViewBuilder thumbnail: @escaping () -> Thumbnail
    ) {
        self.asset = asset
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
        self.onDelete = onDelete
        self.thumbnail = thumbnail
    }

    public var body: some View {
        UnifiedLibraryCardItemView(
            title: asset.name,
            isFavorite: false,
            isSelected: isSelected,
            showsFavoriteButton: false,
            showsDeleteButton: true,
            showsAddButton: true,
            isHovered: isHovered,
            onSelect: { onSelect(false) },
            onAdd: onAddToTimeline,
            onDelete: onDelete
        ) {
            thumbnail()
        }
        .overlay(
            MediaAssetDragBridgeView(
                asset: asset,
                onSelect: onSelect,
                onAddToTimeline: onAddToTimeline,
                onDelete: onDelete,
                onHover: { isHovered = $0 }
            )
        )
    }
}
