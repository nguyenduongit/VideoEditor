import SwiftUI
import Domain
import DesignSystem

/// Tab `"Text"` kết hợp toàn diện Nội dung, Typography và Transform (Không gian & Bố cục).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct TextBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TextContentAndTypographySection(viewModel: viewModel)
            TextTransformSectionView(viewModel: viewModel)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
