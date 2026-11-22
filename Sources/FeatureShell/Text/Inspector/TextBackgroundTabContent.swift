import SwiftUI
import Domain
import DesignSystem

/// Tab `"Background"` chuyên nghiệp cho Module `Text` với 3 Subtab: `Source` · `Layout` · `Style`.
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Ubiquitous Language, Hàm <= 50 dòng).
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

// MARK: - Subtab 2: Layout (Size & Offset) - Gắn kết nội bộ

public struct TextBackgroundLayoutSection: View {
    public let config: TextConfiguration
    public let onUpdate: (TextConfiguration, Bool) -> Void

    public init(
        config: TextConfiguration,
        onUpdate: @escaping (TextConfiguration, Bool) -> Void
    ) {
        self.config = config
        self.onUpdate = onUpdate
    }

    public var body: some View {
        let bg = config.background
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Size & Offset")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Size Mode", selection: Binding(
                get: { bg.fitToTextBounds },
                set: { fit in
                    var u = config
                    u.background.fitToTextBounds = fit
                    onUpdate(u, true)
                }
            )) {
                Text("Fit to Text").tag(true)
                Text("Custom Size").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if bg.fitToTextBounds {
                DSSliderWithInput(
                    title: "Padding X",
                    value: Binding(
                        get: { bg.paddingX },
                        set: { var u = config; u.background.paddingX = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...140.0, step: 1.0, defaultValue: 24.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Padding Y",
                    value: Binding(
                        get: { bg.paddingY },
                        set: { var u = config; u.background.paddingY = $0; onUpdate(u, false) }
                    ),
                    range: 0.0...90.0, step: 1.0, defaultValue: 12.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            } else {
                DSSliderWithInput(
                    title: "Width",
                    value: Binding(
                        get: { bg.customWidth },
                        set: { var u = config; u.background.customWidth = $0; onUpdate(u, false) }
                    ),
                    range: 40.0...1920.0, step: 4.0, defaultValue: 360.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
                DSSliderWithInput(
                    title: "Height",
                    value: Binding(
                        get: { bg.customHeight },
                        set: { var u = config; u.background.customHeight = $0; onUpdate(u, false) }
                    ),
                    range: 24.0...1080.0, step: 2.0, defaultValue: 110.0, unit: "px",
                    onEditingChanged: { if !$0 { onUpdate(config, true) } }
                )
            }

            Divider().background(DSColors.blockBorder)

            DSPositionControl(
                title: "Offset",
                xValue: Binding(
                    get: { bg.offsetX },
                    set: { var u = config; u.background.offsetX = $0; onUpdate(u, false) }
                ),
                yValue: Binding(
                    get: { bg.offsetY },
                    set: { var u = config; u.background.offsetY = $0; onUpdate(u, false) }
                ),
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }
}

// MARK: - Subtab 3: Style (Corner, Feather, Border & Shadow) - Gắn kết nội bộ

public struct TextBackgroundStyleSection: View {
    public let config: TextConfiguration
    public let onUpdate: (TextConfiguration, Bool) -> Void

    public init(
        config: TextConfiguration,
        onUpdate: @escaping (TextConfiguration, Bool) -> Void
    ) {
        self.config = config
        self.onUpdate = onUpdate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            cornerAndFeatherControls
            Divider().background(DSColors.blockBorder)
            borderControls
            Divider().background(DSColors.blockBorder)
            shadowControls
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var cornerAndFeatherControls: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Corner Radius",
                value: Binding(
                    get: { bg.cornerRadius },
                    set: { var u = config; u.background.cornerRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...100.0, step: 1.0, defaultValue: 14.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Feather",
                value: Binding(
                    get: { bg.featherRadius },
                    set: { var u = config; u.background.featherRadius = $0; onUpdate(u, false) }
                ),
                range: 0.0...40.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }

    private var borderControls: some View {
        let bg = config.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            TextColorSwatchesRow(
                title: "Border Color",
                selectedHex: bg.borderColorHex,
                allowNone: true
            ) { hex in
                var u = config
                if hex.uppercased() == "NONE" {
                    u.background.borderColorHex = "NONE"
                } else {
                    u.background.borderColorHex = hex
                    if u.background.borderWidth <= 0.1 {
                        u.background.borderWidth = 2.0
                    }
                }
                onUpdate(u, true)
            }

            DSSliderWithInput(
                title: "Border Width",
                value: Binding(
                    get: { bg.borderWidth },
                    set: { var u = config; u.background.borderWidth = $0; onUpdate(u, false) }
                ),
                range: 0.0...20.0, step: 0.5, defaultValue: 0.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }

    private var shadowControls: some View {
        let bg = config.background
        let hasShadow = bg.hasShadow && bg.shadowColorHex.uppercased() != "NONE"
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            TextColorSwatchesRow(
                title: "Shadow Color",
                selectedHex: hasShadow ? bg.shadowColorHex : "NONE",
                allowNone: true
            ) { hex in
                var u = config
                u.background.hasShadow = true
                if hex.uppercased() == "NONE" {
                    u.background.shadowColorHex = "NONE"
                } else {
                    u.background.shadowColorHex = hex
                    if u.background.shadowBlur <= 0.1 && u.background.shadowDistance <= 0.1 {
                        u.background.shadowBlur = 8.0
                        u.background.shadowDistance = 4.0
                    }
                }
                onUpdate(u, true)
            }

            DSSliderWithInput(
                title: "Shadow Blur",
                value: Binding(
                    get: { bg.shadowBlur },
                    set: { val in
                        var u = config
                        u.background.hasShadow = true
                        u.background.shadowBlur = val
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 8.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Shadow Distance",
                value: Binding(
                    get: { bg.shadowDistance },
                    set: { val in
                        var u = config
                        u.background.hasShadow = true
                        u.background.shadowDistance = val
                        onUpdate(u, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 4.0, unit: "px",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )

            DSSliderWithInput(
                title: "Shadow Angle",
                value: Binding(
                    get: { bg.shadowAngleDegrees },
                    set: { var u = config; u.background.hasShadow = true; u.background.shadowAngleDegrees = $0; onUpdate(u, false) }
                ),
                range: -180.0...180.0, step: 1.0, defaultValue: -45.0, unit: "°",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
    }
}
