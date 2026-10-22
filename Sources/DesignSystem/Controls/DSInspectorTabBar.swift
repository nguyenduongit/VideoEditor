import SwiftUI

/// Topbar tab bar for switching functional tabs in the Inspector (e.g. Video, Audio, Speed).
/// Acts as the header bar for the Inspector sidebar to maximize vertical screen space.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSInspectorTabBar: View {
    private let tabs: [String]
    @Binding private var selectedTab: String
    private let fallbackTitle: String

    public init(
        tabs: [String],
        selectedTab: Binding<String>,
        fallbackTitle: String = "Thuộc tính"
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.fallbackTitle = fallbackTitle
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            if tabs.isEmpty {
                Text(fallbackTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
            } else {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(title: tab)
                }
            }
            Spacer()
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(height: DSSize.sidebarHeaderHeight)
        .background(DSColors.blockBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
    }

    private func tabButton(title: String) -> some View {
        let isSelected = selectedTab.caseInsensitiveCompare(title) == .orderedSame

        return Button {
            selectedTab = title
        } label: {
            VStack(spacing: DSSpacing.none) {
                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.sm)

                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
