import SwiftUI
import Domain
import DesignSystem

public struct SidebarView: View {
    private let title: String
    private let tabs: [any TabDescriptor]
    private let selectedTabID: TabID?
    private let onSelectTab: ((TabID) -> Void)?
    private let customContent: AnyView?
    private let trailingAccessory: AnyView?

    public init(
        title: String = "",
        tabs: [any TabDescriptor] = [],
        selectedTabID: TabID? = nil,
        onSelectTab: ((TabID) -> Void)? = nil,
        customContent: AnyView? = nil,
        trailingAccessory: AnyView? = nil
    ) {
        self.title = title
        self.tabs = tabs
        self.selectedTabID = selectedTabID
        self.onSelectTab = onSelectTab
        self.customContent = customContent
        self.trailingAccessory = trailingAccessory
    }

    public var body: some View {
        DSBlockContainer {
            VStack(alignment: .leading, spacing: DSSpacing.none) {
                headerBar
                contentArea
            }
            .frame(width: DSSize.sidebarWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(width: DSSize.sidebarWidth)
    }

    @ViewBuilder
    private var headerBar: some View {
        if !tabs.isEmpty, let selectedTabID, let onSelectTab {
            let items = tabs.map { tab in
                DSSidebarTabItem(
                    id: tab.id.rawValue,
                    title: tab.title,
                    iconName: tab.iconName,
                    isSoon: tab.isSoon
                )
            }
            DSSidebarTabBar(
                items: items,
                selectedID: selectedTabID.rawValue,
                onSelect: { onSelectTab(TabID(rawValue: $0)) }
            )
        } else {
            fallbackHeader
        }
    }

    private var fallbackHeader: some View {
        HStack(spacing: DSSpacing.none) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
            if let trailingAccessory {
                trailingAccessory
            }
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

    @ViewBuilder
    private var contentArea: some View {
        if let customContent {
            customContent
        } else {
            Spacer()
        }
    }
}
