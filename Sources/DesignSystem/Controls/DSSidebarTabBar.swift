import SwiftUI

public struct DSSidebarTabItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let iconName: String
    public let isSoon: Bool

    public init(id: String, title: String, iconName: String, isSoon: Bool = false) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isSoon = isSoon
    }
}

public struct DSSidebarTabBar: View {
    private let items: [DSSidebarTabItem]
    private let selectedID: String
    private let onSelect: (String) -> Void
    @State private var hoveredTabID: String?

    public init(
        items: [DSSidebarTabItem],
        selectedID: String,
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            ForEach(items) { item in
                tabButton(for: item)
            }
        }
        .frame(height: DSSize.sidebarHeaderHeight)
        .background(DSColors.blockBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
    }

    private func tabButton(for item: DSSidebarTabItem) -> some View {
        let isSelected = item.id == selectedID
        let isHovered = item.id == hoveredTabID

        return Button(action: { onSelect(item.id) }) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.iconName)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(iconColor(isSelected: isSelected, isHovered: isHovered))
                        .frame(width: 24, height: 16)

                    if item.isSoon {
                        Text("soon")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Capsule().fill(DSColors.toggleCyan))
                            .offset(x: 10, y: -4)
                    }
                }

                Text(item.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor(isSelected: isSelected, isHovered: isHovered))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(DSColors.toggleCyan)
                        .frame(height: 2)
                        .padding(.horizontal, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTabID = hovering ? item.id : (hoveredTabID == item.id ? nil : hoveredTabID)
        }
    }

    private func iconColor(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return DSColors.toggleCyan }
        if isHovered { return DSColors.textPrimary }
        return DSColors.textSecondary.opacity(0.85)
    }

    private func textColor(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return DSColors.textPrimary }
        if isHovered { return DSColors.textPrimary }
        return DSColors.textSecondary.opacity(0.8)
    }
}

