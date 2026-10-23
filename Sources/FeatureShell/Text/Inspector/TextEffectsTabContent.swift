import SwiftUI
import Domain
import DesignSystem

/// Tab "Hiệu ứng" (Effects/Style) cho đối tượng Text Clip.
/// Tùy chỉnh viền (stroke), đổ bóng (shadow), hộp nền (background box), và biến đổi (transform).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextEffectsTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    private let swatches = [
        "#000000", "#FFFFFF", "#FDE047", "#EF4444",
        "#3B82F6", "#22C55E", "#F97316", "#A855F7"
    ]

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            strokeSection
            shadowSection
            backgroundSection
            transformSection
        }
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - Sections

    private var strokeSection: some View {
        DSCollapsibleSection(title: "Viền chữ (Stroke)", defaultExpanded: currentConfig.hasStroke) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                DSToggleRow(title: "Bật viền chữ", isOn: Binding(
                    get: { currentConfig.hasStroke },
                    set: { val in
                        var cfg = currentConfig
                        cfg.hasStroke = val
                        commitConfig(cfg)
                    }
                ))

                if currentConfig.hasStroke {
                    colorRow(title: "Màu viền", selectedHex: currentConfig.strokeColorHex) { hex in
                        var cfg = currentConfig
                        cfg.strokeColorHex = hex
                        commitConfig(cfg)
                    }

                    DSSliderWithInput(
                        title: "Độ dày viền",
                        value: Binding(get: { currentConfig.strokeWidth }, set: { val in
                            var cfg = currentConfig
                            cfg.strokeWidth = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: 0.5...20.0, step: 0.5, defaultValue: 2.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )
                }
            }
        }
    }

    private var shadowSection: some View {
        DSCollapsibleSection(title: "Đổ bóng (Shadow)", defaultExpanded: currentConfig.hasShadow) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                DSToggleRow(title: "Bật đổ bóng", isOn: Binding(
                    get: { currentConfig.hasShadow },
                    set: { val in
                        var cfg = currentConfig
                        cfg.hasShadow = val
                        commitConfig(cfg)
                    }
                ))

                if currentConfig.hasShadow {
                    colorRow(title: "Màu bóng", selectedHex: currentConfig.shadowColorHex) { hex in
                        var cfg = currentConfig
                        cfg.shadowColorHex = hex
                        commitConfig(cfg)
                    }

                    DSSliderWithInput(
                        title: "Độ mờ bóng",
                        value: Binding(get: { currentConfig.shadowRadius }, set: { val in
                            var cfg = currentConfig
                            cfg.shadowRadius = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: 0.0...30.0, step: 0.5, defaultValue: 6.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )

                    DSSliderWithInput(
                        title: "Độ lệch X",
                        value: Binding(get: { currentConfig.shadowOffsetX }, set: { val in
                            var cfg = currentConfig
                            cfg.shadowOffsetX = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: -30.0...30.0, step: 0.5, defaultValue: 2.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )

                    DSSliderWithInput(
                        title: "Độ lệch Y",
                        value: Binding(get: { currentConfig.shadowOffsetY }, set: { val in
                            var cfg = currentConfig
                            cfg.shadowOffsetY = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: -30.0...30.0, step: 0.5, defaultValue: 2.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )
                }
            }
        }
    }

    private var backgroundSection: some View {
        DSCollapsibleSection(title: "Hộp nền (Background)", defaultExpanded: currentConfig.hasBackground) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                DSToggleRow(title: "Bật hộp nền", isOn: Binding(
                    get: { currentConfig.hasBackground },
                    set: { val in
                        var cfg = currentConfig
                        cfg.hasBackground = val
                        commitConfig(cfg)
                    }
                ))

                if currentConfig.hasBackground {
                    colorRow(title: "Màu nền", selectedHex: currentConfig.backgroundColorHex) { hex in
                        var cfg = currentConfig
                        cfg.backgroundColorHex = hex + "B2"
                        commitConfig(cfg)
                    }

                    DSSliderWithInput(
                        title: "Bo góc",
                        value: Binding(get: { currentConfig.backgroundCornerRadius }, set: { val in
                            var cfg = currentConfig
                            cfg.backgroundCornerRadius = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: 0.0...40.0, step: 1.0, defaultValue: 8.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )

                    DSSliderWithInput(
                        title: "Đệm lề (Padding)",
                        value: Binding(get: { currentConfig.backgroundPadding }, set: { val in
                            var cfg = currentConfig
                            cfg.backgroundPadding = val
                            updateConfig(cfg, commit: false)
                        }),
                        range: 0.0...50.0, step: 1.0, defaultValue: 12.0, unit: "pt",
                        onEditingChanged: onSliderEditingEnded
                    )
                }
            }
        }
    }

    private var transformSection: some View {
        DSCollapsibleSection(title: "Biến đổi (Transform)", defaultExpanded: true) {
            VStack(spacing: DSSpacing.md) {
                DSPositionControl(
                    title: "Vị trí (X, Y)",
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
                    title: "Thu phóng (Scale)",
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
                    title: "Góc xoay",
                    angle: Binding(get: { currentConfig.rotation }, set: { val in
                        var cfg = currentConfig
                        cfg.rotation = val
                        updateConfig(cfg, commit: false)
                        viewModel.updateLiveValue(key: "rotation", value: val)
                    }),
                    onEditingChanged: onSliderEditingEnded
                )

                DSSliderWithInput(
                    title: "Độ mờ (Opacity)",
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
        }
    }

    // MARK: - Helpers

    private func colorRow(title: String, selectedHex: String, onSelect: @escaping (String) -> Void) -> some View {
        TextColorSwatchesRow(title: title, selectedHex: selectedHex, swatches: swatches, onSelect: onSelect)
    }

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
