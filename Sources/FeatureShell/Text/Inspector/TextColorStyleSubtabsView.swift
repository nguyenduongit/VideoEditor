import SwiftUI
import Domain
import DesignSystem

/// 5 danh mục thuộc tính màu & hiệu ứng của Text Layer (Text, Stroke, Glow, Shadow, Background).
public enum TextColorSubtab: String, CaseIterable, Identifiable {
    case text = "Text"
    case stroke = "Stroke"
    case glow = "Glow"
    case shadow = "Shadow"
    case background = "Background"

    public var id: String { rawValue }
    public var title: String { rawValue }
}

/// Clean flat controls for 5 text effect styles with a shared responsive color bar.
/// Uses "None" swatch to toggle on/off without accordion clutter.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextColorStyleSubtabsView: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var activeSubtab: TextColorSubtab = .text

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            headerRow
            subtabsBar
            sharedColorRow
            if activeSubtab != .text {
                Divider().opacity(0.15)
                TextColorEffectSliders(
                    subtab: activeSubtab,
                    config: currentConfig,
                    onUpdate: { cfg, commit in
                        updateConfig(cfg, commit: commit)
                    }
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

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text(String(localized: "Color & Effects"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
        }
    }

    private var subtabsBar: some View {
        HStack(spacing: 4) {
            ForEach(TextColorSubtab.allCases) { tab in
                let isSelected = activeSubtab == tab
                Button(action: { activeSubtab = tab }) {
                    HStack(spacing: 5) {
                        colorDot(for: tab)
                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                    .background(isSelected ? DSColors.accent : DSColors.windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isSelected ? Color.clear : DSColors.blockBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func colorDot(for tab: TextColorSubtab) -> some View {
        if isTabNone(tab) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    .frame(width: 8, height: 8)
                Path { p in
                    p.move(to: CGPoint(x: 1.5, y: 6.5))
                    p.addLine(to: CGPoint(x: 6.5, y: 1.5))
                }
                .stroke(Color.red, lineWidth: 1)
                .frame(width: 8, height: 8)
            }
            .frame(width: 8, height: 8)
        } else {
            Circle()
                .fill(Color(hex: colorHex(for: tab)))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
        }
    }

    private var sharedColorRow: some View {
        TextColorSwatchesRow(
            selectedHex: colorHex(for: activeSubtab),
            allowNone: true,
            onSelect: { newHex in
                applyColor(newHex, to: activeSubtab)
            }
        )
    }

    // MARK: - Helpers

    private func isTabNone(_ tab: TextColorSubtab) -> Bool {
        switch tab {
        case .text:
            return currentConfig.textColorHex.uppercased() == "NONE"
        case .stroke:
            return (!currentConfig.hasStroke || currentConfig.strokeColorHex.uppercased() == "NONE")
                && (!currentConfig.hasOuterStroke || currentConfig.outerStrokeColorHex.uppercased() == "NONE")
        case .glow:
            return !currentConfig.hasGlow || currentConfig.glowColorHex.uppercased() == "NONE"
        case .shadow:
            return !currentConfig.hasShadow || currentConfig.shadowColorHex.uppercased() == "NONE"
        case .background:
            return !currentConfig.hasBackground || currentConfig.backgroundColorHex.uppercased() == "NONE"
        }
    }

    private func colorHex(for tab: TextColorSubtab) -> String {
        switch tab {
        case .text:
            return currentConfig.textColorHex
        case .stroke:
            return currentConfig.hasStroke ? currentConfig.strokeColorHex : (currentConfig.hasOuterStroke ? currentConfig.outerStrokeColorHex : "NONE")
        case .glow:
            return currentConfig.hasGlow ? currentConfig.glowColorHex : "NONE"
        case .shadow:
            return currentConfig.hasShadow ? currentConfig.shadowColorHex : "NONE"
        case .background:
            return currentConfig.hasBackground ? currentConfig.backgroundColorHex : "NONE"
        }
    }

    private func applyColor(_ hex: String, to tab: TextColorSubtab) {
        var cfg = currentConfig
        let isNone = hex.uppercased() == "NONE"
        switch tab {
        case .text:
            cfg.textColorHex = hex
            cfg.colorFillMode = .solid
            cfg.isGradient = false
        case .stroke:
            cfg.hasStroke = !isNone
            if !isNone { cfg.strokeColorHex = hex }
        case .glow:
            cfg.hasGlow = !isNone
            if !isNone {
                cfg.glowColorHex = hex
                if cfg.glowRadius <= 0 { cfg.glowRadius = 8.0 }
            }
        case .shadow:
            cfg.shadowColorHex = hex
            cfg.hasShadow = !isNone
            if !isNone && cfg.shadowRadius <= 0 && cfg.shadowOffsetX == 0 && cfg.shadowOffsetY == 0 {
                cfg.shadowRadius = 6.0
                cfg.shadowOffsetX = 2.0
                cfg.shadowOffsetY = 2.0
            }
        case .background:
            cfg.backgroundColorHex = hex
            cfg.hasBackground = !isNone
            cfg.backgroundLayer.isEnabled = !isNone
            cfg.backgroundLayer.sourceKind = .solid
            cfg.backgroundLayer.solidColorHex = hex
            if !isNone {
                if cfg.backgroundPaddingX <= 0 { cfg.backgroundPaddingX = 16.0; cfg.backgroundLayer.paddingX = 16.0 }
                if cfg.backgroundPaddingY <= 0 { cfg.backgroundPaddingY = 10.0; cfg.backgroundLayer.paddingY = 10.0 }
                if cfg.backgroundCornerRadius <= 0 { cfg.backgroundCornerRadius = 8.0; cfg.backgroundLayer.cornerRadius = 8.0 }
            }
        }
        commitConfig(cfg)
    }

    private var currentConfig: TextConfiguration {
        viewModel.activeTextLayerConfiguration
    }

    private func updateConfig(_ config: TextConfiguration, commit: Bool) {
        viewModel.updateActiveTextLayer(config, commit: commit)
    }

    private func commitConfig(_ config: TextConfiguration) {
        updateConfig(config, commit: true)
    }
}
