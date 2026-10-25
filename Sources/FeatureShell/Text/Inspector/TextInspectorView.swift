import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector chuyên dụng cho Text Clip.
/// Điều phối hiển thị giữa 2 tab chính: "Văn bản" (Basic) và "Hiệu ứng" (Effects/Style).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        switch viewModel.effectiveTab {
        case "Style", "Hiệu ứng":
            TextEffectsTabContent(viewModel: viewModel)
        case "Animation":
            TextAnimationTabContent(viewModel: viewModel)
        default:
            TextBasicTabContent(viewModel: viewModel)
        }
    }
}
