import SwiftUI
import Domain
import DesignSystem

/// Subtab `"Style"`: điều chỉnh chuyên sâu 2 khối hiệu ứng thị giác độc lập `Glow` (Phát sáng) và `Shadow` (Đổ bóng).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng, Hàm <= 50 dòng) của AGENTS.md.
public struct TextStyleSubtabView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ updated: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(updated, commit: commit)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            glowSection
            shadowSection
        }
    }

    // MARK: - Glow Block

    private var glowSection: some View {
        let glow = currentConfig.glow
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(String(localized: "Glow (Phát sáng hào quang)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { currentConfig.glow.isEnabled },
                    set: { enabled in
                        var u = currentConfig
                        u.glow.isEnabled = enabled
                        if enabled && u.glow.range <= 0.5 { u.glow.range = 14.0 }
                        if enabled && u.glow.intensity <= 1.0 { u.glow.intensity = 80.0 }
                        updateConfig(u, commit: true)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TextColorSwatchesRow(
                    title: "Màu hào quang",
                    selectedHex: glow.colorHex
                ) { hex in
                    var u = currentConfig
                    u.glow.colorHex = hex
                    updateConfig(u, commit: true)
                }

                DSSliderWithInput(
                    title: "Cường độ (Intensity)",
                    value: Binding(
                        get: { currentConfig.glow.intensity },
                        set: { val in
                            var u = currentConfig
                            u.glow.intensity = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: 5.0...100.0,
                    step: 1.0,
                    defaultValue: 80.0,
                    unit: "%",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )

                DSSliderWithInput(
                    title: "Tầm lan (Range)",
                    value: Binding(
                        get: { currentConfig.glow.range },
                        set: { val in
                            var u = currentConfig
                            u.glow.range = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: 1.0...60.0,
                    step: 0.5,
                    defaultValue: 14.0,
                    unit: "pt",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )
            }
            .opacity(glow.isEnabled ? 1.0 : 0.65)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    // MARK: - Shadow Block

    private var shadowSection: some View {
        let shadow = currentConfig.shadow
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(String(localized: "Shadow (Đổ bóng chữ)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { currentConfig.shadow.isEnabled },
                    set: { enabled in
                        var u = currentConfig
                        u.shadow.isEnabled = enabled
                        if enabled && u.shadow.opacity <= 1.0 { u.shadow.opacity = 75.0 }
                        updateConfig(u, commit: true)
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TextColorSwatchesRow(
                    title: "Màu bóng đổ",
                    selectedHex: shadow.colorHex
                ) { hex in
                    var u = currentConfig
                    u.shadow.colorHex = hex
                    updateConfig(u, commit: true)
                }

                DSSliderWithInput(
                    title: "Độ đậm (Opacity)",
                    value: Binding(
                        get: { currentConfig.shadow.opacity },
                        set: { val in
                            var u = currentConfig
                            u.shadow.opacity = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: 5.0...100.0,
                    step: 1.0,
                    defaultValue: 75.0,
                    unit: "%",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )

                DSSliderWithInput(
                    title: "Độ nhòe (Blur)",
                    value: Binding(
                        get: { currentConfig.shadow.blur },
                        set: { val in
                            var u = currentConfig
                            u.shadow.blur = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: 0.0...50.0,
                    step: 0.5,
                    defaultValue: 8.0,
                    unit: "pt",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )

                DSSliderWithInput(
                    title: "Khoảng cách (Distance)",
                    value: Binding(
                        get: { currentConfig.shadow.distance },
                        set: { val in
                            var u = currentConfig
                            u.shadow.distance = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: 0.0...60.0,
                    step: 0.5,
                    defaultValue: 5.0,
                    unit: "pt",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )

                DSSliderWithInput(
                    title: "Góc đổ bóng (Angle)",
                    value: Binding(
                        get: { currentConfig.shadow.angleDegrees },
                        set: { val in
                            var u = currentConfig
                            u.shadow.angleDegrees = val
                            updateConfig(u, commit: false)
                        }
                    ),
                    range: -180.0...180.0,
                    step: 1.0,
                    defaultValue: 45.0,
                    unit: "°",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
                )
            }
            .opacity(shadow.isEnabled ? 1.0 : 0.65)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }
}
