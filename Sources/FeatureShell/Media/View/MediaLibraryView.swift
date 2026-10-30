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
        GridItem(.flexible(), spacing: DSSpacing.md),
        GridItem(.flexible(), spacing: DSSpacing.md)
    ]

    public init(viewModel: MediaLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ),
            searchPlaceholder: "Tìm kiếm tệp...",
            categories: MediaLibraryViewModel.MediaFilter.allCases.map(\.displayName),
            selectedCategory: categoryBinding,
            trailingAction: trailingHeaderAction
        ) {
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

    private var categoryBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedFilter.displayName },
            set: { name in
                if let found = MediaLibraryViewModel.MediaFilter.allCases.first(where: { $0.displayName == name }) {
                    viewModel.selectedFilter = found
                }
            }
        )
    }

    private var trailingHeaderAction: AnyView? {
        if !viewModel.selectedAssetIDs.isEmpty {
            return AnyView(deleteButton)
        }
        return nil
    }

    private var deleteButton: some View {
        Button(action: { viewModel.deleteSelected() }) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(Color.red.opacity(0.9))
                .padding(5)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
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
                importTileCard
            }
            .padding(DSSpacing.md)
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

    private var importTileCard: some View {
        Button(action: {
            isFocused = true
            viewModel.importFiles()
        }) {
            VStack(spacing: DSSpacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.block)
                        .fill(DSColors.windowBackground.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.block)
                                .stroke(DSColors.blockBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .aspectRatio(1.0, contentMode: .fit)

                Text(String(localized: "Thêm tệp"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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
