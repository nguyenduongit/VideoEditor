import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Left Sidebar view for the Dev-Authored Stickers System Library (`StickerLibrary`).
/// Read-only to end users per AGENTS.md Article 15 (local Favorites via `UserDefaults`, no Supabase sync).
public struct StickerLibraryView: View {
    @Bindable private var viewModel: StickerLibraryViewModel
    @State private var selectedCategory: String = StickerCategory.emoji.displayName
    @State private var selectedItemID: String?

    private let categories = StickerCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: StickerLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedItems: [StickerLibraryItem] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let matchesQuery: (StickerLibraryItem) -> Bool = { item in
            item.name.localizedCaseInsensitiveContains(trimmed)
                || item.description.localizedCaseInsensitiveContains(trimmed)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
        if !trimmed.isEmpty && selectedCategory != SidebarFavoriteManager.favoritesCategory {
            return viewModel.items.filter(matchesQuery)
        }
        let base: [StickerLibraryItem]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "sticker")
            base = viewModel.items.filter { favs.contains($0.id) }
        } else if let cat = StickerCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
            base = viewModel.items.filter { $0.category == cat }
        } else {
            base = viewModel.items
        }
        guard !trimmed.isEmpty else { return base }
        return base.filter(matchesQuery)
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search stickers...",
            categories: categories,
            selectedCategory: $selectedCategory
        ) {
            contentScrollView
        }
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            let items = displayedItems
            if items.isEmpty {
                emptyView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    ForEach(items) { item in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: item.id, for: "sticker")
                        UnifiedLibraryCardItemView(
                            title: item.name,
                            isFavorite: isFav,
                            isSelected: selectedItemID == item.id,
                            dragPayload: .sticker(item),
                            onSelect: { selectedItemID = item.id },
                            onAdd: { viewModel.addStickerToTimeline(item) },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: item.id, for: "sticker")
                            }
                        ) {
                            stickerThumbnail(for: item)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func stickerThumbnail(for item: StickerLibraryItem) -> some View {
        ZStack {
            if item.format == .audiogram {
                AudiogramStickerThumbnailView(
                    config: item.config.audiogram ?? StickerAudiogramConfiguration()
                )
            } else if let svg = item.config.svgMarkup, !svg.isEmpty {
                SVGStickerThumbnailView(
                    svgMarkup: svg,
                    fallbackSymbol: item.systemSymbolFallback
                )
                .padding(DSSpacing.xs)
            } else {
                Image(systemName: item.systemSymbolFallback)
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
