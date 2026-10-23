import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector chuyên dụng cho Adjustment Layer.
/// Hiển thị trực tiếp nội dung theo 2 tab chính ở thanh tabbar trên cùng (Basic và HSL), không dùng sub-tab.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if viewModel.effectiveTab == "HSL" {
            AdjustmentHSLTabContent(viewModel: viewModel)
        } else {
            AdjustmentBasicTabContent(viewModel: viewModel)
        }
    }
}
