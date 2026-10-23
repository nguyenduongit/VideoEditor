import SwiftUI
import Domain
import DesignSystem

/// View thư viện Adjustment Layer bên sidebar trái.
/// Gồm 2 tab: "Mặc định" (1 item trung tính) và "Templates" (nhiều preset có sẵn).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentLibraryView: View {
    @Bindable private var viewModel: AdjustmentLibraryViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 120), spacing: DSSpacing.md)
    ]

    public init(viewModel: AdjustmentLibraryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            subTabBar
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
            Divider()
                .background(DSColors.blockBorder)
            contentScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    private var subTabBar: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(AdjustmentLibraryViewModel.SubTab.allCases, id: \.self) { tab in
                Button(action: {
                    viewModel.selectedSubTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: viewModel.selectedSubTab == tab ? .semibold : .regular))
                        .foregroundStyle(viewModel.selectedSubTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .padding(.vertical, DSSpacing.xs)
                        .padding(.horizontal, DSSpacing.md)
                        .background(
                            viewModel.selectedSubTab == tab ? DSColors.windowBackground : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var contentScrollView: some View {
        DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                if viewModel.selectedSubTab == .default {
                    AdjustmentCardItemView(preset: viewModel.defaultPreset) {
                        viewModel.addPresetToTimeline(viewModel.defaultPreset)
                    }
                } else {
                    ForEach(viewModel.templatePresets) { preset in
                        AdjustmentCardItemView(preset: preset) {
                            viewModel.addPresetToTimeline(preset)
                        }
                    }
                }
            }
            .padding(DSSpacing.md)
        }
    }
}
