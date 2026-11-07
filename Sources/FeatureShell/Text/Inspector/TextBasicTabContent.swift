import SwiftUI
import Domain
import DesignSystem

/// Tab `"Text"` hợp nhất cho cả người dùng và Template, chia thành 4 Subtab chuyên biệt:
/// `Basic` (Nội dung 1 dòng, Typography, Tô màu, Transform) · `Stroke` (2 Viền độc lập) ·
/// `Style` (Glow & Shadow độc lập) · `Curved` (Uốn cong CoreText `Arc` / `Wave`).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubtab: Subtab = .basic

    public enum Subtab: String, CaseIterable, Identifiable {
        case basic = "Basic"
        case stroke = "Stroke"
        case style = "Style"
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
                basicSubtabContent
            case .stroke:
                TextDualStrokeControlsView(viewModel: viewModel)
            case .style:
                TextStyleSubtabView(viewModel: viewModel)
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

    private var basicSubtabContent: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TextContentAndTypographySection(viewModel: viewModel)
            colorFillCard
            TextTransformSectionView(viewModel: viewModel)
        }
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
        case .basic:
            return false
        case .stroke:
            return currentConfig.innerStroke.isActive || currentConfig.outerStroke.isActive
        case .style:
            return currentConfig.glow.isActive || currentConfig.shadow.isActive
        case .curved:
            return currentConfig.curve.isActive
        }
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ updated: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(updated, commit: commit)
    }
}
