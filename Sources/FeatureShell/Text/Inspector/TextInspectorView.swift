import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector hợp nhất cho Module `Text` (1 Lõi Đơn Dòng · 4 Tab: `Text`, `Color`, `Background`, `Animation`).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.none) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(DSColors.blockBorder)

            TextPresetActionSectionView(
                viewModel: viewModel,
                currentConfig: viewModel.textConfiguration
            )
            .padding(.leading, DSSize.inspectorContentPadding)
            .padding(.trailing, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(DSColors.blockBackground)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.effectiveTab {
        case "Color":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextColorTabContent(viewModel: viewModel)
                    .padding(.leading, DSSize.inspectorContentPadding)
                    .padding(.trailing, DSSpacing.md)
                    .padding(.vertical, DSSpacing.md)
            }
        case "Animation":
            TextAnimationTabContent(viewModel: viewModel)
        case "Background":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBackgroundTabContent(viewModel: viewModel)
                    .padding(.leading, DSSize.inspectorContentPadding)
                    .padding(.trailing, DSSpacing.md)
                    .padding(.vertical, DSSpacing.md)
            }
        default:
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBasicTabContent(viewModel: viewModel)
                    .padding(.leading, DSSize.inspectorContentPadding)
                    .padding(.trailing, DSSpacing.md)
                    .padding(.vertical, DSSpacing.md)
            }
        }
    }
}
