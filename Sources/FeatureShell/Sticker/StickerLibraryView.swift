import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Left Sidebar view for the Stickers Library (SVG Vector & GIF / APNG).
/// Features a 100pt vertical category sidebar, 2-column square card grid,
/// top-right 26pt Favorites button, and bottom-right 26pt Add button.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct StickerLibraryView: View {
    @Bindable private var viewModel: StickerLibraryViewModel
    @State private var selectedCategory: String = StickerCategory.emoji.displayName

    private let categories = StickerCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: StickerLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedPresets: [StickerPreset] {
        let base: [StickerPreset]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "sticker")
            base = viewModel.templatePresets.filter { favs.contains($0.id) }
        } else {
            if let cat = StickerCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
                base = viewModel.templatePresets.filter { $0.category == cat }
            } else {
                base = viewModel.templatePresets
            }
        }
        guard !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchQuery) }
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search stickers...",
            categories: categories,
            selectedCategory: $selectedCategory,
            favoritesCount: SidebarFavoriteManager.shared.favorites(for: "sticker").count,
            trailingAction: AnyView(reloadButton)
        ) {
            contentScrollView
        }
        .task {
            await viewModel.syncFromRemoteIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetStoreDidUpdate)) { _ in
            viewModel.reloadTemplates()
        }
    }

    private var reloadButton: some View {
        let size = LibraryScaffoldView<EmptyView>.searchControlHeight
        return Button(action: { viewModel.reloadTemplates() }) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(DSColors.windowBackground)
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .help("Reload Stickers")
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let presets = displayedPresets
            if presets.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    ForEach(presets) { preset in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: preset.id, for: "sticker")
                        UnifiedLibraryCardItemView(
                            title: preset.name,
                            isFavorite: isFav,
                            onAdd: {
                                viewModel.addStickerToTimeline(preset)
                            },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: preset.id, for: "sticker")
                            }
                        ) {
                            stickerThumbnail(for: preset)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func stickerThumbnail(for preset: StickerPreset) -> some View {
        ZStack {
            if let svg = preset.config.svgMarkup, !svg.isEmpty {
                SVGStickerThumbnailView(
                    svgMarkup: svg,
                    fallbackSymbol: preset.systemSymbolFallback
                )
                .padding(DSSpacing.xs)
            } else {
                Image(systemName: preset.systemSymbolFallback)
                    .font(.system(size: 32))
                    .foregroundStyle(DSColors.toggleCyan)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.windowBackground)
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "face.smiling")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No stickers found")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}
