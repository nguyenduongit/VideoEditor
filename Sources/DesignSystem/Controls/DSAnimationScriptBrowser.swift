import SwiftUI

/// Shared full-height Inspector layout for Script-Driven Animations (used by Text and Sticker):
/// - Left category filter sidebar (`All` + per-category counts)
/// - 3-column scrollable preview grid (leading `None` card when `All` is active)
/// - Optional pinned bottom panel for domain-specific timing and parameter customization
public struct DSAnimationScriptBrowser<Item: Identifiable, CardPreview: View, BottomPanel: View>: View where Item.ID == String {
    @Binding private var selectedCategoryId: String?
    private let totalCount: Int
    private let categories: [DSAnimationBrowserCategory]
    private let items: [Item]
    private let selectedItemId: String
    private let showBottomPanel: Bool
    private let onClearSelection: () -> Void
    private let onSelectItem: (Item) -> Void
    private let itemTitle: (Item) -> String
    private let itemTooltip: (Item) -> String
    private let itemPreview: (Item, Bool, Bool) -> CardPreview
    private let bottomPanel: BottomPanel

    @State private var hoveredItemId: String?

    private let gridColumns = [
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs)
    ]

    public init(
        selectedCategoryId: Binding<String?>,
        totalCount: Int,
        categories: [DSAnimationBrowserCategory],
        items: [Item],
        selectedItemId: String,
        showBottomPanel: Bool,
        onClearSelection: @escaping () -> Void,
        onSelectItem: @escaping (Item) -> Void,
        itemTitle: @escaping (Item) -> String,
        itemTooltip: @escaping (Item) -> String = { _ in "" },
        @ViewBuilder itemPreview: @escaping (Item, _ isSelected: Bool, _ isHovered: Bool) -> CardPreview,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self._selectedCategoryId = selectedCategoryId
        self.totalCount = totalCount
        self.categories = categories
        self.items = items
        self.selectedItemId = selectedItemId
        self.showBottomPanel = showBottomPanel
        self.onClearSelection = onClearSelection
        self.onSelectItem = onSelectItem
        self.itemTitle = itemTitle
        self.itemTooltip = itemTooltip
        self.itemPreview = itemPreview
        self.bottomPanel = bottomPanel()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.none) {
            HStack(spacing: DSSpacing.none) {
                categorySidebar
                    .frame(width: 82)
                    .background(DSColors.windowBackground.opacity(0.45))

                Divider()
                    .background(DSColors.blockBorder)

                cardsScrollView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showBottomPanel {
                Divider().background(DSColors.blockBorder)
                bottomPanel
                    .frame(maxWidth: .infinity)
                    .background(DSColors.blockBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    private var categorySidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sidebarButton(
                    title: "All",
                    count: totalCount,
                    isSelected: selectedCategoryId == nil
                ) {
                    selectedCategoryId = nil
                }

                ForEach(categories) { category in
                    sidebarButton(
                        title: category.title,
                        count: category.count,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        selectedCategoryId = category.id
                    }
                }
            }
        }
    }

    private func sidebarButton(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary.opacity(0.8))
                }
            }
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? DSColors.toggleCyan.opacity(0.18) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? DSColors.toggleCyan.opacity(0.85) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardsScrollView: some View {
        let isNoneSelected = selectedItemId.isEmpty || selectedItemId.lowercased() == "none"
        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: DSSpacing.xs) {
                if selectedCategoryId == nil {
                    noneCard(isSelected: isNoneSelected)
                }

                ForEach(items) { item in
                    let isSelected = selectedItemId == item.id
                    let isHovered = hoveredItemId == item.id
                    itemCard(item: item, isSelected: isSelected, isHovered: isHovered)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private func noneCard(isSelected: Bool) -> some View {
        Button(action: onClearSelection) {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: "slash.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                    .frame(height: 42)
                Text("None")
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? DSColors.windowBackground : DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isSelected ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func itemCard(item: Item, isSelected: Bool, isHovered: Bool) -> some View {
        let tooltip = itemTooltip(item)
        return Button(action: { onSelectItem(item) }) {
            VStack(spacing: 3) {
                itemPreview(item, isSelected, isHovered)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .clipped()

                Text(itemTitle(item))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? DSColors.windowBackground : (isHovered ? DSColors.tabHoverBackground : DSColors.blockBackground))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(
                        isSelected ? DSColors.toggleCyan : (isHovered ? DSColors.toggleCyan.opacity(0.45) : DSColors.blockBorder),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredItemId = item.id
            } else if hoveredItemId == item.id {
                hoveredItemId = nil
            }
        }
        .help(tooltip)
    }
}
