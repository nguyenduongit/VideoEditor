import SwiftUI
import Domain
import DesignSystem

/// Subtab `"Effects"` trong Tab Appearance:
/// Gồm Blur (Làm mờ), Distortion (Uốn cong / Sóng), Glitch (Lệch dải màu RGB) và Noise (Hạt nhiễu).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextEffectsSubtabView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            blurAndGlitchCard
            TextCurvedSectionView(viewModel: viewModel)
        }
    }

    private var blurAndGlitchCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "Visual Filters"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Blur",
                value: Binding(
                    get: { currentConfig.blurRadius },
                    set: { val in
                        var cfg = currentConfig
                        cfg.blurRadius = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: 0.0...40.0,
                step: 0.5,
                defaultValue: 0.0,
                unit: "px",
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Glitch (RGB Split)",
                value: Binding(
                    get: { currentConfig.glitchIntensity },
                    set: { val in
                        var cfg = currentConfig
                        cfg.glitchIntensity = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: 0.0...100.0,
                step: 1.0,
                defaultValue: 0.0,
                unit: "%",
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Noise (Grain)",
                value: Binding(
                    get: { currentConfig.noiseIntensity },
                    set: { val in
                        var cfg = currentConfig
                        cfg.noiseIntensity = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: 0.0...100.0,
                step: 1.0,
                defaultValue: 0.0,
                unit: "%",
                onEditingChanged: onSliderEditingEnded
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ config: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(config, commit: commit)
    }

    private func onSliderEditingEnded(isEditing: Bool) {
        if !isEditing {
            viewModel.updateTextConfiguration(currentConfig, commit: true)
        }
    }
}

