import SwiftUI
import Domain
import DesignSystem

private struct MediaItemFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct MediaLibraryView: View {
    private let viewModel: MediaLibraryViewModel
    @State private var dragRect: CGRect?
    @State private var itemFrames: [UUID: CGRect] = [:]
    @FocusState private var isFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: MediaLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            subTabBar
            contentArea
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.delete) {
            viewModel.deleteSelected()
            return .handled
        }
        .onKeyPress(KeyEquivalent("\u{7f}")) {
            viewModel.deleteSelected()
            return .handled
        }
        .onKeyPress { press in
            if press.key == KeyEquivalent("i") && press.modifiers == .command {
                viewModel.importFiles()
                return .handled
            }
            if press.key == KeyEquivalent("z") && press.modifiers == .command {
                _ = viewModel.undo()
                return .handled
            }
            if press.key == KeyEquivalent("z") && press.modifiers == [.command, .shift] {
                _ = viewModel.redo()
                return .handled
            }
            return .ignored
        }
    }

    private var subTabBar: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(MediaLibraryViewModel.MediaFilter.allCases, id: \.self) { filter in
                Button(action: {
                    viewModel.selectedFilter = filter
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: viewModel.selectedFilter == filter ? .semibold : .medium))
                        .foregroundStyle(viewModel.selectedFilter == filter ? DSColors.textPrimary : DSColors.textSecondary)
                        .padding(.vertical, DSSpacing.xs)
                        .padding(.horizontal, DSSpacing.md)
                        .background(
                            viewModel.selectedFilter == filter ? Color.white.opacity(0.12) : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if !viewModel.selectedAssetIDs.isEmpty {
                deleteButton
            }
            itemCountLabel
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
    }

    private var deleteButton: some View {
        Button(action: { viewModel.deleteSelected() }) {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(Color.red.opacity(0.9))
                .padding(DSSpacing.xs)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .contentShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
    }

    private var itemCountLabel: some View {
        Text(String(localized: "\(viewModel.filteredAssets.count) items"))
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(DSColors.textSecondary)
    }

    private var contentArea: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(viewModel.filteredAssets) { asset in
                    MediaAssetItemView(
                        asset: asset,
                        isSelected: viewModel.selectedAssetIDs.contains(asset.id),
                        thumbnail: viewModel.thumbnails[asset.id],
                        onSelect: { isCmd in
                            isFocused = true
                            viewModel.toggleSelection(for: asset.id, isCmdPressed: isCmd)
                        },
                        onAddToTimeline: {
                            viewModel.addAssetToTimeline(asset)
                        }
                    )
                    .background(frameReporter(for: asset.id))
                }
            }
            .padding(.leading, DSSpacing.lg)
            .padding(.trailing, DSSpacing.sm)
            .padding(.vertical, DSSpacing.lg)
        }
        .coordinateSpace(name: "MediaGridSpace")
        .overlay(alignment: .topLeading) {
            dragSelectionOverlay
        }
        .simultaneousGesture(dragSelectionGesture)
        .onPreferenceChange(MediaItemFrameKey.self) { frames in
            itemFrames = frames
        }
        .onTapGesture {
            isFocused = true
            viewModel.clearSelection()
        }
    }

    private func frameReporter(for id: UUID) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: MediaItemFrameKey.self,
                value: [id: geo.frame(in: .named("MediaGridSpace"))]
            )
        }
    }

    @ViewBuilder
    private var dragSelectionOverlay: some View {
        if let rect = dragRect {
            DSMarqueeSelectionView(rect: rect)
        }
    }

    private var dragSelectionGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("MediaGridSpace"))
            .onChanged { value in
                isFocused = true
                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
                dragRect = rect
                viewModel.updateDragSelection(rect: rect, itemFrames: itemFrames)
            }
            .onEnded { _ in
                dragRect = nil
            }
    }
}
