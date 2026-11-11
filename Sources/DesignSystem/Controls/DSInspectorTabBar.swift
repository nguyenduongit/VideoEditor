import SwiftUI

/// Topbar tab bar for switching functional tabs in the Inspector (e.g. Video, Audio, Speed).
/// Acts as the header bar for the Inspector sidebar to maximize vertical screen space.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSInspectorTabBar<Trailing: View>: View {
    private let tabs: [String]
    @Binding private var selectedTab: String
    private let fallbackTitle: String
    private let trailing: Trailing

    public init(
        tabs: [String],
        selectedTab: Binding<String>,
        fallbackTitle: String = "Thuộc tính",
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.fallbackTitle = fallbackTitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: tabSpacing) {
            if tabs.isEmpty {
                Text(fallbackTitle)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
            } else {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(title: tab)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, outerPadding)
        .frame(height: DSSize.sidebarHeaderHeight)
        .background(DSColors.blockBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
    }

    private var fontSize: CGFloat {
        if tabs.count >= 5 {
            return 11.0
        } else if tabs.count >= 4 {
            return 12.0
        } else {
            return 12.5
        }
    }

    private var tabSpacing: CGFloat {
        tabs.count >= 4 ? DSSpacing.xs : DSSpacing.md
    }

    private var tabHorizontalPadding: CGFloat {
        tabs.count >= 4 ? 6 : DSSpacing.sm
    }

    private var outerPadding: CGFloat {
        tabs.count >= 4 ? DSSpacing.md : DSSpacing.lg
    }

    private func tabButton(title: String) -> some View {
        let isSelected = selectedTab.caseInsensitiveCompare(title) == .orderedSame

        return Button {
            selectedTab = title
        } label: {
            ZStack(alignment: .bottom) {
                Text(title)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, tabHorizontalPadding)
                    .frame(maxHeight: .infinity, alignment: .center)

                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : Color.clear)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension DSInspectorTabBar where Trailing == EmptyView {
    public init(
        tabs: [String],
        selectedTab: Binding<String>,
        fallbackTitle: String = "Thuộc tính"
    ) {
        self.init(tabs: tabs, selectedTab: selectedTab, fallbackTitle: fallbackTitle) {
            EmptyView()
        }
    }
}
