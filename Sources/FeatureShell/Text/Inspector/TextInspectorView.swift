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
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.effectiveTab {
        case "Appearance", "Color":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextColorTabContent(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        case "Animation":
            TextAnimationTabContent(viewModel: viewModel)
        case "Background":
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBackgroundTabContent(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        default:
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TextBasicTabContent(viewModel: viewModel)
                    .padding(.horizontal, DSSize.inspectorContentPadding)
                    .padding(.vertical, DSSize.inspectorContentPadding)
            }
        }
    }
}
