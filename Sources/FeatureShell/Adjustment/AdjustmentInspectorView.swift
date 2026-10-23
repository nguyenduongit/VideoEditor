import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector chuyên dụng cho Adjustment Layer.
/// Gồm 2 tab: Cơ bản (Basic) và HSL.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentInspectorView: View {
    public enum Tab: String, CaseIterable, Sendable {
        case basic = "Cơ bản"
        case hsl = "HSL"
    }

    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedTab: Tab = .basic

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            tabBarHeader
            Divider()
                .background(DSColors.blockBorder)
            tabContent
        }
    }

    private var tabBarHeader: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .padding(.vertical, DSSpacing.xs)
                        .padding(.horizontal, DSSpacing.md)
                        .background(
                            selectedTab == tab ? DSColors.windowBackground : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .basic:
            AdjustmentBasicTabContent(viewModel: viewModel)
        case .hsl:
            AdjustmentHSLTabContent(viewModel: viewModel)
        }
    }
}
