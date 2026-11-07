import SwiftUI
import Domain
import DesignSystem

/// Các thanh trượt điều chỉnh cho 4 hiệu ứng Text Layer (Text, Stroke, Glow, Shadow).
/// Tự động kích hoạt hiệu ứng khi người dùng tương tác.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextColorEffectSliders: View {
    public let subtab: TextColorSubtab
    public let config: TextConfiguration
    public let onUpdate: (TextConfiguration, Bool) -> Void

    public init(
        subtab: TextColorSubtab,
        config: TextConfiguration,
        onUpdate: @escaping (TextConfiguration, Bool) -> Void
    ) {
        self.subtab = subtab
        self.config = config
        self.onUpdate = onUpdate
    }

    public var body: some View {
        switch subtab {
        case .text:
            EmptyView()
        case .stroke:
            TextDualStrokeControlsView(config: config, onUpdate: onUpdate)
        case .glow:
            glowControls
        case .shadow:
            shadowControls
        case .background:
            backgroundControls
        }
    }

    // MARK: - Glow & Shadow Controls

    private var glowControls: some View {
        let isOff = !config.hasGlow
        return DSSliderWithInput(
            title: "Glow Radius",
            value: Binding(
                get: { config.glowRadius },
                set: { val in
                    var cfg = config
                    if isOff { cfg.hasGlow = true; cfg.glowColorHex = "#FDE047" }
                    cfg.glowRadius = val
                    onUpdate(cfg, false)
                }
            ),
            range: 1.0...30.0, step: 0.5, defaultValue: 8.0, unit: "pt",
            onEditingChanged: { if !$0 { onUpdate(config, true) } }
        )
        .opacity(isOff ? 0.45 : 1.0)
    }

    private var shadowControls: some View {
        let isOff = !config.hasShadow
        return VStack(spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Blur",
                value: Binding(
                    get: { config.shadowRadius },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasShadow = true; cfg.shadowColorHex = "#000000" }
                        cfg.shadowRadius = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...30.0, step: 0.5, defaultValue: 6.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Offset X",
                value: Binding(
                    get: { config.shadowOffsetX },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasShadow = true; cfg.shadowColorHex = "#000000" }
                        cfg.shadowOffsetX = val
                        onUpdate(cfg, false)
                    }
                ),
                range: -30.0...30.0, step: 0.5, defaultValue: 2.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Offset Y",
                value: Binding(
                    get: { config.shadowOffsetY },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasShadow = true; cfg.shadowColorHex = "#000000" }
                        cfg.shadowOffsetY = val
                        onUpdate(cfg, false)
                    }
                ),
                range: -30.0...30.0, step: 0.5, defaultValue: 2.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .opacity(isOff ? 0.45 : 1.0)
    }

    // MARK: - Background Controls

    private var backgroundControls: some View {
        let isOff = !config.hasBackground
        return VStack(spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Corner Radius",
                value: Binding(
                    get: { config.backgroundCornerRadius },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasBackground = true; cfg.backgroundColorHex = "#000000B2" }
                        cfg.backgroundCornerRadius = val
                        cfg.backgroundLayer.cornerRadius = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...50.0, step: 1.0, defaultValue: 8.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Padding X",
                value: Binding(
                    get: { config.backgroundPaddingX },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasBackground = true; cfg.backgroundColorHex = "#000000B2" }
                        cfg.backgroundPaddingX = val
                        cfg.backgroundLayer.paddingX = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...60.0, step: 1.0, defaultValue: 16.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Padding Y",
                value: Binding(
                    get: { config.backgroundPaddingY },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasBackground = true; cfg.backgroundColorHex = "#000000B2" }
                        cfg.backgroundPaddingY = val
                        cfg.backgroundLayer.paddingY = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 10.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Feather",
                value: Binding(
                    get: { config.backgroundFeather },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasBackground = true; cfg.backgroundColorHex = "#000000B2" }
                        cfg.backgroundFeather = val
                        cfg.backgroundLayer.featherRadius = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...30.0, step: 1.0, defaultValue: 0.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .opacity(isOff ? 0.45 : 1.0)
    }
}
