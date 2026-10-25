import SwiftUI
import Domain
import DesignSystem

/// Các thanh trượt điều chỉnh cho 5 hiệu ứng Text Layer (Text, Stroke, Glow, Shadow, Background).
/// Tự động kích hoạt hiệu ứng khi người dùng kéo trượt từ trạng thái tắt (None).
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
            Text(config.textColorHex.uppercased() == "NONE" ? "Hollow text (outline only)." : "Primary text fill color.")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                .padding(.vertical, 2)
        case .stroke:
            strokeControls
        case .glow:
            glowControls
        case .shadow:
            shadowControls
        case .background:
            backgroundControls
        }
    }

    // MARK: - Specific Controls

    private var strokeControls: some View {
        let isOff = !config.hasStroke
        return DSSliderWithInput(
            title: "Stroke Width",
            value: Binding(
                get: { config.strokeWidth },
                set: { val in
                    var cfg = config
                    if isOff { cfg.hasStroke = true; cfg.strokeColorHex = "#000000" }
                    cfg.strokeWidth = val
                    onUpdate(cfg, false)
                }
            ),
            range: 0.5...20.0, step: 0.5, defaultValue: 2.0, unit: "pt",
            onEditingChanged: { if !$0 { onUpdate(config, true) } }
        )
        .opacity(isOff ? 0.45 : 1.0)
    }

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
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...40.0, step: 1.0, defaultValue: 8.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Padding",
                value: Binding(
                    get: { config.backgroundPadding },
                    set: { val in
                        var cfg = config
                        if isOff { cfg.hasBackground = true; cfg.backgroundColorHex = "#000000B2" }
                        cfg.backgroundPadding = val
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...50.0, step: 1.0, defaultValue: 12.0, unit: "pt",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
            DSSliderWithInput(
                title: "Opacity",
                value: Binding(
                    get: { currentBackgroundOpacity },
                    set: { val in
                        var cfg = applyBackgroundOpacity(val, to: config)
                        if isOff { cfg.hasBackground = true }
                        onUpdate(cfg, false)
                    }
                ),
                range: 0.0...1.0, step: 0.01, defaultValue: 0.70, unit: "%",
                onEditingChanged: { if !$0 { onUpdate(config, true) } }
            )
        }
        .opacity(isOff ? 0.45 : 1.0)
    }

    private var currentBackgroundOpacity: Double {
        let clean = config.backgroundColorHex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 8, let num = UInt64(clean, radix: 16) {
            let alphaByte = num & 0xFF
            return Double(alphaByte) / 255.0
        }
        return 1.0
    }

    private func applyBackgroundOpacity(_ opacity: Double, to config: TextConfiguration) -> TextConfiguration {
        var cfg = config
        let clean = cfg.backgroundColorHex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        let rgbPrefix: String
        if clean.count >= 6 {
            rgbPrefix = String(clean.prefix(6))
        } else {
            rgbPrefix = "000000"
        }
        let alphaByte = Int(round(max(0.0, min(1.0, opacity)) * 255.0))
        cfg.backgroundColorHex = String(format: "#%@%02X", rgbPrefix.uppercased(), alphaByte)
        return cfg
    }
}
