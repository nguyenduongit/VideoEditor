import AppKit
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
    @State private var selectedCategory: String = "Local Files"
    @FocusState private var isFocused: Bool

    private let categories = [
        "Local Files",
        SidebarFavoriteManager.dividerCategory,
        "Stock Videos",
        "Backgrounds",
        "SFX"
    ]

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    private let dependencies: EditorDependencies?
    @State private var stockItems: [StockMediaItem] = StockMediaItem.builtInCatalog

    public init(viewModel: MediaLibraryViewModel, dependencies: EditorDependencies? = nil) {
        self.viewModel = viewModel
        self.dependencies = dependencies
    }

    private var displayedAssets: [MediaAsset] {
        let base = viewModel.assets
        guard !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchQuery) }
    }

    private var displayedStockItems: [StockMediaItem] {
        let base: [StockMediaItem]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "media")
            base = stockItems.filter { favs.contains($0.id) }
        } else {
            base = stockItems.filter { $0.category == selectedCategory }
        }
        guard !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchQuery) }
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ),
            searchPlaceholder: "Search files...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "media").count,
            trailingAction: trailingHeaderAction
        ) {
            contentArea
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            syncStockItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetStoreDidUpdate)) { _ in
            syncStockItems()
        }
        .onKeyPress(.delete) { handleDeleteKeyPress() }
        .onKeyPress(KeyEquivalent("\u{7f}")) { handleDeleteKeyPress() }
        .onKeyPress { press in
            guard !isTextInputActive else { return .ignored }
            if press.key == KeyEquivalent("i") && press.modifiers == .command {
                selectedCategory = "Local Files"
                viewModel.importFiles()
                return .handled
            }
            if press.key == KeyEquivalent("z") && press.modifiers == .command {
                if viewModel.canUndo { _ = viewModel.undo(); return .handled }
                return .ignored
            }
            if press.key == KeyEquivalent("z") && press.modifiers == [.command, .shift] {
                if viewModel.canRedo { _ = viewModel.redo(); return .handled }
                return .ignored
            }
            return .ignored
        }
    }

    private var isTextInputActive: Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else { return false }
        return firstResponder is NSTextView || firstResponder is NSTextField
    }

    private func handleDeleteKeyPress() -> KeyPress.Result {
        guard !isTextInputActive else { return .ignored }
        guard !viewModel.selectedAssetIDs.isEmpty else { return .ignored }
        viewModel.deleteSelected()
        return .handled
    }

    private var trailingHeaderAction: AnyView? {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        let isLocal = selectedCategory == "Local Files"
        return AnyView(
            Button(action: {
                if isLocal { isFocused = true; viewModel.importFiles() } else { syncStockItems() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .fill(isLocal ? DSColors.toggleCyan : DSColors.blockBackground)
                    Image(systemName: isLocal ? "plus" : "arrow.clockwise")
                        .font(.system(size: 11, weight: isLocal ? .bold : .medium))
                        .foregroundStyle(isLocal ? Color.white : DSColors.textSecondary)
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
            .help(isLocal ? "Import Media Files" : "Reload Stock Media")
        )
    }

    private func syncStockItems() {
        guard let repo = dependencies?.presetRepositories.stockMediaRepository else { return }
        Task {
            if let items = try? await repo.fetchStockItems() {
                await MainActor.run {
                    self.stockItems = items
                }
            }
        }
    }

    private var contentArea: some View {
        GeometryReader { geo in
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                VStack(spacing: 0) {
                    LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                        if selectedCategory == "Local Files" {
                            ForEach(displayedAssets) { asset in
                                userAssetCard(asset)
                            }
                        } else {
                            ForEach(displayedStockItems) { stock in
                                stockAssetCard(stock)
                            }
                        }
                    }
                    .padding(DSSpacing.sm)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                    viewModel.clearSelection()
                }
            }
            .coordinateSpace(name: "MediaGridSpace")
            .overlay(alignment: .topLeading) { dragSelectionOverlay }
            .simultaneousGesture(dragSelectionGesture)
            .onPreferenceChange(MediaItemFrameKey.self) { frames in itemFrames = frames }
        }
    }

    private func userAssetCard(_ asset: MediaAsset) -> some View {
        MediaAssetItemView(
            asset: asset,
            isSelected: viewModel.selectedAssetIDs.contains(asset.id),
            onSelect: { isCmd in
                isFocused = true
                viewModel.toggleSelection(for: asset.id, isCmdPressed: isCmd)
            },
            onAddToTimeline: { viewModel.addAssetToTimeline(asset) },
            onDelete: {
                if viewModel.selectedAssetIDs.contains(asset.id) {
                    viewModel.deleteSelected()
                } else {
                    viewModel.deleteAsset(asset)
                }
            }
        ) {
            thumbnailView(for: asset)
        }
        .background(frameReporter(for: asset.id))
    }

    private func stockAssetCard(_ stock: StockMediaItem) -> some View {
        let isFav = SidebarFavoriteManager.shared.isFavorite(id: stock.id, for: "media")
        return UnifiedLibraryCardItemView(
            title: stock.name,
            isFavorite: isFav,
            showsFavoriteButton: true,
            onAdd: {
                let asset = MediaAsset(url: stock.mediaURL, name: stock.name, type: stock.type)
                viewModel.addAssetToTimeline(asset)
            },
            onToggleFavorite: { SidebarFavoriteManager.shared.toggleFavorite(id: stock.id, for: "media") }
        ) {
            VStack(spacing: 4) {
                Image(systemName: stock.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(stock.type == .audio ? DSColors.toggleCyan : DSColors.accent)
                Text(stock.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.windowBackground.opacity(0.5))
        }
    }

    @ViewBuilder
    private func thumbnailView(for asset: MediaAsset) -> some View {
        if asset.type == .audio {
            VStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 26))
                    .foregroundStyle(DSColors.toggleCyan)
                Text("AUDIO")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(DSColors.textSecondary)
            }
        } else if let img = viewModel.thumbnails[asset.id] {
            img.resizable().scaledToFill()
        } else {
            Image(systemName: asset.type == .video ? "video.fill" : "photo.fill")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary)
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
