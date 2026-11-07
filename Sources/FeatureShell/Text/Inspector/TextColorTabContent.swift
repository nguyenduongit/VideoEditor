import SwiftUI
import Domain
import DesignSystem

/// Tab `"Color"` chuyên sâu cho Module Text:
/// Gồm 4 Subtab: `Fill` (Tô mặt chữ) · `Stroke` (Viền kép) · `Glow` (Hào quang) · `Shadow` (Đổ bóng).
/// Hỗ trợ chấm xanh chỉ báo trạng thái đang hoạt động (Active Dot Indicator).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct TextColorTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubtab: Subtab = .fill

    public enum Subtab: String, CaseIterable, Identifiable {
        case fill = "Fill"
        case stroke = "Stroke"
        case glow = "Glow"
        case shadow = "Shadow"

        public var id: String { rawValue }
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            colorSubtabBar

            switch selectedSubtab {
            case .fill:
                colorFillCard
            case .stroke:
                TextDualStrokeControlsView(viewModel: viewModel)
            case .glow:
                TextGlowSectionView(viewModel: viewModel)
            case .shadow:
                TextShadowSectionView(viewModel: viewModel)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var colorSubtabBar: some View {
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

    private var colorFillCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Color"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            TextFillModeControlsView(viewModel: viewModel)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private func hasActiveIndicator(for tab: Subtab) -> Bool {
        switch tab {
        case .fill:
            return false
        case .stroke:
            return currentConfig.innerStroke.isActive || currentConfig.outerStroke.isActive
        case .glow:
            return currentConfig.glow.isActive
        case .shadow:
            return currentConfig.shadow.isActive
        }
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }
}
