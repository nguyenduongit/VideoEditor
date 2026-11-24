import SwiftUI
import Domain
import DesignSystem

/// Left Sidebar view for the Dev-Authored Effects System Library (`EffectLibrary`).
/// Read-only to end users per AGENTS.md Article 15 (local Favorites via `UserDefaults`, no delete/save preset actions).
public struct EffectLibraryView: View {
    @Bindable private var viewModel: EffectLibraryViewModel
    @State private var selectedCategory: String = EffectCategory.assignableCases.first(where: { cat in
        EffectLibraryItem.systemItems.contains(where: { $0.category == cat })
    })?.displayName ?? EffectCategory.basic.displayName
    @State private var selectedItemID: String?

    private let categories = EffectCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: EffectLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedItems: [EffectLibraryItem] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [EffectLibraryItem]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "effect")
            base = viewModel.items.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = viewModel.items
        } else if let cat = EffectCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
            base = viewModel.items.filter { $0.category == cat }
        } else {
            base = viewModel.items
        }
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.description.localizedCaseInsensitiveContains(trimmed)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    public var body: some View {
        LibraryScaffoldView(
            searchQuery: $viewModel.searchQuery,
            searchPlaceholder: "Search effects, tags...",
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
                emptyLibraryView
            } else {
                LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                    ForEach(items) { item in
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: item.id, for: "effect")
                        UnifiedLibraryCardItemView(
                            title: item.name,
                            isFavorite: isFav,
                            isSelected: selectedItemID == item.id,
                            showsDeleteButton: false,
                            dragPayload: .effect(item),
                            onSelect: { selectedItemID = item.id },
                            onAdd: { viewModel.addToTimeline(item) },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: item.id, for: "effect")
                            }
                        ) { isCardHovered in
                            EffectAnimatedThumbnailView(item: item, isHovered: isCardHovered)
                        }
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    private var emptyLibraryView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No effects available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}
