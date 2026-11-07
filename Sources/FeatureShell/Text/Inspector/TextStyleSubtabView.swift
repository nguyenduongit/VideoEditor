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

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            TextGlowSectionView(viewModel: viewModel)
            TextShadowSectionView(viewModel: viewModel)
        }
    }
}

/// Khối điều chỉnh hiệu ứng Hào quang (Glow) cho Module Text.
public struct TextGlowSectionView: View {
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
        let isGlowActive = currentConfig.glow.isEnabled && currentConfig.glow.colorHex.uppercased() != "NONE"
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Glow")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TextColorSwatchesRow(
                    title: "Color",
                    selectedHex: isGlowActive ? currentConfig.glow.colorHex : "NONE",
                    allowNone: true
                ) { hex in
                    var u = currentConfig
                    u.glow.isEnabled = true
                    if hex.uppercased() == "NONE" {
                        u.glow.colorHex = "NONE"
                    } else {
                        u.glow.colorHex = hex
                        if u.glow.range <= 0.5 { u.glow.range = 14.0 }
                        if u.glow.intensity <= 1.0 { u.glow.intensity = 80.0 }
                    }
                    updateConfig(u, commit: true)
                }

                DSSliderWithInput(
                    title: "Intensity",
                    value: Binding(
                        get: { currentConfig.glow.intensity },
                        set: { val in
                            var u = currentConfig
                            u.glow.isEnabled = true
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
                    title: "Range",
                    value: Binding(
                        get: { currentConfig.glow.range },
                        set: { val in
                            var u = currentConfig
                            u.glow.isEnabled = true
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

/// Khối điều chỉnh hiệu ứng Đổ bóng chữ (Shadow) cho Module Text.
public struct TextShadowSectionView: View {
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
        let isShadowActive = currentConfig.shadow.isEnabled && currentConfig.shadow.colorHex.uppercased() != "NONE"
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Shadow")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                TextColorSwatchesRow(
                    title: "Color",
                    selectedHex: isShadowActive ? currentConfig.shadow.colorHex : "NONE",
                    allowNone: true
                ) { hex in
                    var u = currentConfig
                    u.shadow.isEnabled = true
                    if hex.uppercased() == "NONE" {
                        u.shadow.colorHex = "NONE"
                    } else {
                        u.shadow.colorHex = hex
                        if u.shadow.opacity <= 1.0 { u.shadow.opacity = 75.0 }
                        if u.shadow.blur <= 0.5 { u.shadow.blur = 8.0 }
                        if u.shadow.distance <= 0.5 { u.shadow.distance = 5.0 }
                    }
                    updateConfig(u, commit: true)
                }

                DSSliderWithInput(
                    title: "Opacity",
                    value: Binding(
                        get: { currentConfig.shadow.opacity },
                        set: { val in
                            var u = currentConfig
                            u.shadow.isEnabled = true
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
                    title: "Blur",
                    value: Binding(
                        get: { currentConfig.shadow.blur },
                        set: { val in
                            var u = currentConfig
                            u.shadow.isEnabled = true
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
                    title: "Distance",
                    value: Binding(
                        get: { currentConfig.shadow.distance },
                        set: { val in
                            var u = currentConfig
                            u.shadow.isEnabled = true
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
                    title: "Angle",
                    value: Binding(
                        get: { currentConfig.shadow.angleDegrees },
                        set: { val in
                            var u = currentConfig
                            u.shadow.isEnabled = true
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
