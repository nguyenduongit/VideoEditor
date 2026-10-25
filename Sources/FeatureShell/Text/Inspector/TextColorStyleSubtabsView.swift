import SwiftUI
import Domain
import DesignSystem

/// 5 danh mục thuộc tính màu & hiệu ứng của Text Layer.
public enum TextColorSubtab: String, CaseIterable, Identifiable {
    case text = "Text"
    case stroke = "Stroke"
    case glow = "Glow"
    case shadow = "Shadow"
    case background = "Background"

    public var id: String { rawValue }
    public var title: String { rawValue }
}

/// Giao diện chọn màu và tinh chỉnh 5 hiệu ứng Text Layer dùng chung 1 thanh màu gọn gàng.
/// Thiết kế phẳng, không accordion, không toggle switch, điều khiển bật/tắt bằng nút "None / Trong suốt".
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
            Divider().opacity(0.15)
            TextColorEffectSliders(
                subtab: activeSubtab,
                config: currentConfig,
                onUpdate: { cfg, commit in
                    updateConfig(cfg, commit: commit)
                }
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

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("Color & Effects")
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
            return !currentConfig.hasStroke || currentConfig.strokeColorHex.uppercased() == "NONE"
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
            return currentConfig.hasStroke ? currentConfig.strokeColorHex : "NONE"
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
        case .stroke:
            cfg.hasStroke = !isNone
            if !isNone { cfg.strokeColorHex = hex }
        case .glow:
            cfg.hasGlow = !isNone
            if !isNone { cfg.glowColorHex = hex }
        case .shadow:
            cfg.shadowColorHex = hex
            cfg.hasShadow = !isNone
        case .background:
            cfg.hasBackground = !isNone
            if !isNone {
                let cleanCurrent = currentConfig.backgroundColorHex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                let currentAlpha = cleanCurrent.count == 8 ? String(cleanCurrent.suffix(2)) : "B2"
                let cleanNew = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                let rgb = String(cleanNew.prefix(6))
                cfg.backgroundColorHex = "#" + rgb + currentAlpha
            }
        }
        commitConfig(cfg)
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
}
