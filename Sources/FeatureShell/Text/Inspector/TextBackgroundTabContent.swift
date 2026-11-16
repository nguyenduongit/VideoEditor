import SwiftUI
import Domain
import DesignSystem

/// Tab `"Background"` chuyên nghiệp cho Module `Text` với 3 Subtab: `Source` · `Layout` · `Style`.
public struct TextBackgroundTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubtab: Subtab = .source

    private static let supportedSources: [TextBackgroundSourceKind] = [.solid, .linearGradient, .radialGradient]

    public enum Subtab: String, CaseIterable, Identifiable {
        case source = "Source", layout = "Layout", style = "Style"
        public var id: String { rawValue }
    }

    public init(viewModel: InspectorViewModel) { self.viewModel = viewModel }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            backgroundSubtabBar
            switch selectedSubtab {
            case .source: sourceConfigurationCard
            case .layout: TextBackgroundLayoutSection(config: currentConfig, onUpdate: updateConfig)
            case .style: TextBackgroundStyleSection(config: currentConfig, onUpdate: updateConfig)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Subtab Bar

    private var backgroundSubtabBar: some View {
        HStack(spacing: 2) {
            ForEach(Subtab.allCases) { tab in
                let isSelected = selectedSubtab == tab
                Button(action: { selectedSubtab = tab }) {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                        if hasActiveIndicator(for: tab) {
                            Circle().fill(DSColors.toggleCyan).frame(width: 5, height: 5)
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
        let bg = currentConfig.background
        switch tab {
        case .source:
            switch bg.sourceKind {
            case .solid: return bg.solidColorHex.uppercased() != "NONE" && !bg.solidColorHex.isEmpty
            case .linearGradient, .radialGradient:
                return bg.gradientColorsHex.contains { $0.uppercased() != "NONE" && !$0.isEmpty }
            case .inlineSVG: return !bg.svgMarkup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .animatedAsset: return !bg.assetPathOrURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .layout: return !bg.fitToTextBounds || abs(bg.offsetX) > 0.5 || abs(bg.offsetY) > 0.5
        case .style:
            return (bg.borderWidth > 0.1 && bg.borderColorHex.uppercased() != "NONE")
                || (bg.hasShadow && bg.shadowColorHex.uppercased() != "NONE")
                || bg.featherRadius > 0.1
        }
    }

    // MARK: - Subtab 1: Source Configuration Card

    private var sourceConfigurationCard: some View {
        let bg = currentConfig.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Background Source")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Background Source", selection: Binding(
                get: { Self.supportedSources.contains(bg.sourceKind) ? bg.sourceKind : .solid },
                set: { kind in
                    var cfg = currentConfig
                    cfg.background.sourceKind = kind
                    updateConfig(cfg, true)
                }
            )) {
                ForEach(Self.supportedSources) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            switch bg.sourceKind {
            case .linearGradient, .radialGradient:
                gradientSourceControls(bg: bg)
            default:
                TextColorSwatchesRow(title: "Background Color", selectedHex: bg.solidColorHex, allowNone: true) { hex in
                    var cfg = currentConfig
                    cfg.background.sourceKind = .solid
                    cfg.background.solidColorHex = hex.uppercased() == "NONE" ? "NONE" : hex
                    updateConfig(cfg, true)
                }
            }

            Divider().background(DSColors.blockBorder)
            commonCompositingControls(bg: bg)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func commonCompositingControls(bg: TextBackgroundStyle) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Opacity",
                value: Binding(
                    get: { bg.opacity * 100.0 },
                    set: { var cfg = currentConfig; cfg.background.opacity = $0 / 100.0; updateConfig(cfg, false) }
                ),
                range: 0.0...100.0, step: 1.0, defaultValue: 85.0, unit: "%",
                onEditingChanged: { if !$0 { updateConfig(currentConfig, true) } }
            )
            HStack {
                Text("Blend Mode")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { bg.blendMode },
                    set: { var cfg = currentConfig; cfg.background.blendMode = $0; updateConfig(cfg, true) }
                )) {
                    ForEach(TextLayerBlendMode.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(width: 135)
            }
        }
    }

    private func gradientSourceControls(bg: TextBackgroundStyle) -> some View {
        let isRadial = bg.sourceKind == .radialGradient
        let start = bg.gradientColorsHex.first ?? "#0F172A"
        let end = bg.gradientColorsHex.count > 1 ? bg.gradientColorsHex[1] : "#3B82F6"
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            TextColorSwatchesRow(
                title: isRadial ? "Center Color" : "Gradient Start",
                selectedHex: start,
                allowNone: true
            ) { hex in
                var cfg = currentConfig
                cfg.background.isEnabled = true
                cfg.background.gradientColorsHex = [hex, end]
                updateConfig(cfg, true)
            }
            TextColorSwatchesRow(
                title: isRadial ? "Outer Color" : "Gradient End",
                selectedHex: end,
                allowNone: true
            ) { hex in
                var cfg = currentConfig
                cfg.background.isEnabled = true
                cfg.background.gradientColorsHex = [start, hex]
                updateConfig(cfg, true)
            }
            if !isRadial {
                DSSliderWithInput(
                    title: "Gradient Angle",
                    value: Binding(
                        get: { bg.gradientAngleDegrees },
                        set: { var cfg = currentConfig; cfg.background.gradientAngleDegrees = $0; updateConfig(cfg, false) }
                    ),
                    range: 0.0...360.0, step: 1.0, defaultValue: 90.0, unit: "°",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, true) } }
                )
            }
        }
    }

    private var currentConfig: TextConfiguration { viewModel.textConfiguration }
    private func updateConfig(_ updated: TextConfiguration, _ commit: Bool) {
        var u = updated
        u.background.isEnabled = true
        viewModel.updateTextConfiguration(u, commit: commit)
    }
}
