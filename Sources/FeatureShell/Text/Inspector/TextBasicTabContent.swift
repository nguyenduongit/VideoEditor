import SwiftUI
import Domain
import DesignSystem

/// Tab `"Text"` (Hình thể & Bố cục), chia thành 3 Subtab chuyên biệt:
/// `Basic` (Nội dung 1 dòng, Typography) · `Transform` (Tọa độ, Scale, Góc xoay, Độ mờ) · `Curved` (Uốn cong CoreText).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct TextBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubtab: Subtab = .basic

    public enum Subtab: String, CaseIterable, Identifiable {
        case basic = "Basic"
        case transform = "Transform"
        case curved = "Curved"

        public var id: String { rawValue }
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            subtabBar

            switch selectedSubtab {
            case .basic:
                TextContentAndTypographySection(viewModel: viewModel)
            case .transform:
                TextTransformSectionView(viewModel: viewModel)
            case .curved:
                TextCurvedSectionView(viewModel: viewModel)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var subtabBar: some View {
        HStack(spacing: 2) {
            ForEach(Subtab.allCases) { tab in
                let isSelected = selectedSubtab == tab
                Button(action: { selectedSubtab = tab }) {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                        if hasActiveIndicator(for: tab) {
                            Circle()
                                .fill(DSColors.toggleCyan)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(isSelected ? DSColors.windowBackground : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func hasActiveIndicator(for tab: Subtab) -> Bool {
        switch tab {
        case .basic, .transform:
            return false
        case .curved:
            return currentConfig.curve.isActive
        }
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }
}
