import SwiftUI
import Domain
import DesignSystem

/// Left Sidebar view for the Dev-Authored Transitions System Library (`TransitionLibrary`).
/// Read-only to end users per AGENTS.md Article 15 (local Favorites via `UserDefaults`, no Supabase sync).
public struct TransitionLibraryView: View {
    @Bindable private var viewModel: TransitionLibraryViewModel
    @State private var selectedCategory: String = TransitionCategory.basic.displayName
    @State private var selectedItemID: String?

    private let categories = TransitionCategory.assignableCases.map(\.displayName)

    private let columns = [
        GridItem(.flexible(), spacing: DSSpacing.sm),
        GridItem(.flexible(), spacing: DSSpacing.sm)
    ]

    public init(viewModel: TransitionLibraryViewModel) {
        self.viewModel = viewModel
    }

    private var displayedItems: [TransitionLibraryItem] {
        let trimmed = viewModel.searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [TransitionLibraryItem]
        if selectedCategory == SidebarFavoriteManager.favoritesCategory {
            let favs = SidebarFavoriteManager.shared.favorites(for: "transition")
            base = viewModel.items.filter { favs.contains($0.id) }
        } else if !trimmed.isEmpty {
            base = viewModel.items
        } else if let cat = TransitionCategory.assignableCases.first(where: { $0.displayName == selectedCategory }) {
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
            searchPlaceholder: "Search transitions...",
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
                        let isFav = SidebarFavoriteManager.shared.isFavorite(id: item.id, for: "transition")
                        UnifiedLibraryCardItemView(
                            title: item.name,
                            isFavorite: isFav,
                            isSelected: selectedItemID == item.id,
                            dragPayload: .transition(item),
                            onSelect: { selectedItemID = item.id },
                            onAdd: { viewModel.applyTransitionToTimeline(item) },
                            onToggleFavorite: {
                                SidebarFavoriteManager.shared.toggleFavorite(id: item.id, for: "transition")
                            }
                        ) { isCardHovered in
                            TransitionAnimatedThumbnailView(item: item, isHovered: isCardHovered)
                        }
                        .help("\(item.name) — \(item.description)")
                    }
                }
                .padding(DSSpacing.sm)
            }
        }
    }

    private var emptyLibraryView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 28))
                .foregroundStyle(DSColors.textSecondary.opacity(0.6))
            Text("No transitions available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, DSSpacing.md)
    }
}
