import SwiftUI
import DesignSystem

/// Shared layout scaffold for the Left Sidebar across all 7 tabs.
/// Provides a 100pt vertical category sidebar on the left with a dedicated "Favorites"
/// top header whose height strictly matches the search bar row (~40pt) for visual alignment.
/// Complies with AGENTS.md rules (File <= 300 lines, View body <= 40 lines).
public struct LibraryScaffoldView<Content: View>: View {
    public static var favoritesCategory: String { SidebarFavoriteManager.favoritesCategory }
    public static var divider: String { SidebarFavoriteManager.dividerCategory }
    public static var categoryColumnWidth: CGFloat { 100 }
    public static var headerRowHeight: CGFloat { 40 }
    public static var searchControlHeight: CGFloat { 26 }

    private let searchPlaceholder: String
    @Binding private var searchQuery: String
    private let hasSearch: Bool

    private let categories: [String]
    private let selectedCategory: Binding<String>?
    private let categoryCounts: [String: Int]
    private let favoritesCount: Int
    private let showFavorites: Bool

    private let trailingAction: AnyView?
    private let content: () -> Content

    public init(
        searchQuery: Binding<String>? = nil,
        searchPlaceholder: String = "Search...",
        categories: [String] = [],
        selectedCategory: Binding<String>? = nil,
        categoryCounts: [String: Int] = [:],
        favoritesCount: Int = 0,
        showFavorites: Bool = true,
        trailingAction: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        if let searchQuery {
            self._searchQuery = searchQuery
            self.hasSearch = true
        } else {
            self._searchQuery = .constant("")
            self.hasSearch = false
        }
        self.searchPlaceholder = searchPlaceholder
        self.categories = categories
        self.selectedCategory = selectedCategory
        self.categoryCounts = categoryCounts
        self.favoritesCount = favoritesCount
        self.showFavorites = showFavorites
        self.trailingAction = trailingAction
        self.content = content
    }

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            if !categories.isEmpty, let selectedCategory {
                categoryColumn(selected: selectedCategory)
                    .frame(width: Self.categoryColumnWidth)
                    .background(DSColors.windowBackground.opacity(0.45))

                Divider()
                    .background(DSColors.blockBorder)
            }

            VStack(spacing: DSSpacing.none) {
                if hasSearch || trailingAction != nil {
                    searchHeaderSection
                    Divider()
                        .background(DSColors.blockBorder)
                }

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    private func categoryColumn(selected: Binding<String>) -> some View {
        VStack(spacing: DSSpacing.none) {
            if showFavorites {
                favoritesHeaderButton(selected: selected)
                    .frame(height: Self.headerRowHeight)

                Divider()
                    .background(DSColors.blockBorder)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(categories, id: \.self) { category in
                        if category == Self.divider {
                            Divider()
                                .background(DSColors.blockBorder.opacity(0.6))
                                .padding(.vertical, 4)
                        } else {
                            let isSelected = selected.wrappedValue == category
                            let count = categoryCounts[category] ?? 0
                            sidebarButton(
                                title: category,
                                icon: nil,
                                count: count,
                                isSelected: isSelected
                            ) {
                                selected.wrappedValue = category
                            }
                        }
                    }
                }
                .padding(.vertical, DSSpacing.xs)
            }
        }
    }

    private func favoritesHeaderButton(selected: Binding<String>) -> some View {
        let isSelected = selected.wrappedValue == Self.favoritesCategory
        return Button(action: { selected.wrappedValue = Self.favoritesCategory }) {
            HStack(spacing: 6) {
                DSRoundedStarView(isFavorite: true, size: 14)

                Text("Favorites")
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if favoritesCount > 0 {
                    Text("\(favoritesCount)")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                }
            }
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? DSColors.toggleCyan.opacity(0.18) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? DSColors.toggleCyan : Color.clear)
                    .frame(width: 2.5),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarButton(
        title: String,
        icon: String?,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary.opacity(0.8))
                }
            }
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? DSColors.toggleCyan.opacity(0.18) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? DSColors.toggleCyan : Color.clear)
                    .frame(width: 2.5),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }

    private var searchHeaderSection: some View {
        HStack(spacing: DSSpacing.xs) {
            if hasSearch {
                searchBar
            }
            if let trailingAction {
                trailingAction
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .frame(height: Self.headerRowHeight)
    }

    private var searchBar: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)

            TextField(searchPlaceholder, text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textPrimary)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Self.searchControlHeight)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }
}
