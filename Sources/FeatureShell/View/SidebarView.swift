import SwiftUI
import DesignSystem

public struct SidebarView: View {
    private let title: String
    private let customContent: AnyView?
    private let trailingAccessory: AnyView?

    public init(
        title: String,
        customContent: AnyView? = nil,
        trailingAccessory: AnyView? = nil
    ) {
        self.title = title
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

    private var headerBar: some View {
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
