import SwiftUI
import Domain
import DesignSystem

/// Tab "Style" (hoặc Layout/Transform) cho đối tượng Text Clip.
/// Tùy chỉnh khoảng cách ký tự, khoảng cách dòng, và biến đổi vị trí/thu phóng/xoay/độ mờ.
/// Thiết kế phẳng, trực quan theo card, không lạm dụng accordion.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextEffectsTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            spacingSection
            transformSection
        }
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - Sections

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "Spacing"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            let charBinding = Binding<Double>(
                get: { currentConfig.characterSpacing },
                set: { newSpacing in
                    var cfg = currentConfig
                    cfg.characterSpacing = newSpacing
                    updateConfig(cfg, commit: false)
                }
            )
            DSSliderWithInput(
                title: "Character Spacing",
                value: charBinding,
                range: -5.0...30.0,
                step: 0.5,
                defaultValue: 0.0,
                unit: "pt",
                onEditingChanged: onSliderEditingEnded
            )

            let lineBinding = Binding<Double>(
                get: { currentConfig.lineSpacing },
                set: { newLine in
                    var cfg = currentConfig
                    cfg.lineSpacing = newLine
                    updateConfig(cfg, commit: false)
                }
            )
            DSSliderWithInput(
                title: "Line Spacing",
                value: lineBinding,
                range: 0.0...40.0,
                step: 1.0,
                defaultValue: 4.0,
                unit: "pt",
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

    private var transformSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "Transform"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSPositionControl(
                title: "Position",
                xValue: Binding(get: { currentConfig.positionX }, set: { val in
                    var cfg = currentConfig
                    cfg.positionX = val
                    updateConfig(cfg, commit: false)
                    viewModel.updateLiveValue(key: "positionX", value: val)
                }),
                yValue: Binding(get: { currentConfig.positionY }, set: { val in
                    var cfg = currentConfig
                    cfg.positionY = val
                    updateConfig(cfg, commit: false)
                    viewModel.updateLiveValue(key: "positionY", value: val)
                }),
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Scale",
                value: Binding(get: { currentConfig.scale }, set: { val in
                    var cfg = currentConfig
                    cfg.scale = val
                    updateConfig(cfg, commit: false)
                    viewModel.updateLiveValue(key: "scale", value: val)
                }),
                range: 0.1...5.0, step: 0.05, defaultValue: 1.0,
                onEditingChanged: onSliderEditingEnded
            )

            DSRotationControl(
                title: "Rotation",
                angle: Binding(get: { currentConfig.rotation }, set: { val in
                    var cfg = currentConfig
                    cfg.rotation = val
                    updateConfig(cfg, commit: false)
                    viewModel.updateLiveValue(key: "rotation", value: val)
                }),
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Opacity",
                value: Binding(get: { currentConfig.opacity }, set: { val in
                    var cfg = currentConfig
                    cfg.opacity = val
                    updateConfig(cfg, commit: false)
                    viewModel.updateLiveValue(key: "opacity", value: val)
                }),
                range: 0.0...1.0, step: 0.01, defaultValue: 1.0, unit: "%",
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

    // MARK: - Helpers

    private var currentConfig: TextConfiguration {
        let str = viewModel.liveProperties["textConfig"]?.asString
            ?? viewModel.selectedClip?.properties["textConfig"]?.asString ?? ""
        return TextConfiguration.decode(from: str) ?? TextConfiguration()
    }

    private func updateConfig(_ config: TextConfiguration, commit: Bool) {
        if let json = config.encodeToJSON() {
            if commit {
                viewModel.commitTextProperty(key: "textConfig", text: json)
            } else {
                viewModel.updateLiveText(key: "textConfig", text: json)
            }
        }
    }

    private func commitConfig(_ config: TextConfiguration) {
        updateConfig(config, commit: true)
    }

    private func onSliderEditingEnded(isEditing: Bool) {
        if !isEditing {
            commitConfig(currentConfig)
        }
    }
}
