import SwiftUI

/// Thanh điều hướng Sub-tab chuẩn (Sub-tab Bar) cho Inspector.
/// Chiều cao tổng thể đúng 26pt, các nút chia đều chiều rộng (frame maxWidth: .infinity).
/// Thiết kế tối giản, đồng bộ với dark mode và AAS design standards.
/// Tuân thủ quy tắc R3.1 (<= 300 dòng, View body <= 80 dòng) và R8.1/R8.2 của AGENTS.md.
public struct DSSubTabBar: View {
    private let tabs: [String]
    @Binding private var selectedTab: String
    private let onSelect: ((String) -> Void)?

    public init(
        tabs: [String],
        selectedTab: Binding<String>,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab.caseInsensitiveCompare(tab) == .orderedSame
                tabButton(title: tab, isSelected: isSelected)
            }
        }
        .padding(2)
        .frame(height: 26)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private func tabButton(title: String, isSelected: Bool) -> some View {
        Button {
            selectedTab = title
            onSelect?(title)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(isSelected ? DSColors.windowBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

