import SwiftUI
import AppKit
import OSLog
import UniformTypeIdentifiers
import Domain
import DesignSystem

private let bgLogger = Logger(subsystem: "VideoEditor", category: "TextBackgroundTabContent")

/// Tab `"Background"` chuyên nghiệp cho Module `Text` (1 lõi thống nhất).
public struct TextBackgroundTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            masterHeaderCard
            sourceConfigurationCard
            TextBackgroundAppearanceSection(config: currentConfig, onUpdate: updateConfig)
        }
        .padding(.vertical, DSSpacing.xs)
    }

    // MARK: - Master Switch

    private var masterHeaderCard: some View {
        let bg = currentConfig.background
        return HStack {
            Text(String(localized: "Khung nền văn bản (Text Background)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { bg.isEnabled },
                set: { enabled in
                    var cfg = currentConfig
                    cfg.background.isEnabled = enabled
                    updateConfig(cfg, true)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    // MARK: - Source Configuration Card

    private var sourceConfigurationCard: some View {
        let bg = currentConfig.background
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Nguồn nền (Background Source)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Nguồn nền", selection: Binding(
                get: { bg.sourceKind },
                set: { kind in
                    var cfg = currentConfig
                    cfg.background.sourceKind = kind
                    if kind == .inlineSVG && cfg.background.svgMarkup.isEmpty {
                        cfg.background.svgMarkup = Self.defaultBadgeSVG
                    }
                    updateConfig(cfg, true)
                }
            )) {
                ForEach(TextBackgroundSourceKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            switch bg.sourceKind {
            case .solid:
                TextColorSwatchesRow(title: "Màu khung nền", selectedHex: bg.solidColorHex) { hex in
                    var cfg = currentConfig
                    cfg.background.solidColorHex = hex
                    updateConfig(cfg, true)
                }
            case .linearGradient, .radialGradient:
                gradientSourceControls(bg: bg)
            case .inlineSVG:
                svgSourceControls(bg: bg)
            case .animatedAsset:
                animatedAssetControls(bg: bg)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func gradientSourceControls(bg: TextBackgroundStyle) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            let start = bg.gradientColorsHex.first ?? "#0F172A"
            let end = bg.gradientColorsHex.count > 1 ? bg.gradientColorsHex[1] : "#3B82F6"

            TextColorSwatchesRow(title: "Màu đầu nền", selectedHex: start) { hex in
                var cfg = currentConfig
                cfg.background.gradientColorsHex = [hex, end]
                updateConfig(cfg, true)
            }
            TextColorSwatchesRow(title: "Màu cuối nền", selectedHex: end) { hex in
                var cfg = currentConfig
                cfg.background.gradientColorsHex = [start, hex]
                updateConfig(cfg, true)
            }
            if bg.sourceKind == .linearGradient {
                DSSliderWithInput(
                    title: "Góc Gradient nền",
                    value: Binding(
                        get: { bg.gradientAngleDegrees },
                        set: { val in
                            var cfg = currentConfig
                            cfg.background.gradientAngleDegrees = val
                            updateConfig(cfg, false)
                        }
                    ),
                    range: 0.0...360.0,
                    step: 1.0,
                    defaultValue: 90.0,
                    unit: "°",
                    onEditingChanged: { if !$0 { updateConfig(currentConfig, true) } }
                )
            }
        }
    }

    private func svgSourceControls(bg: TextBackgroundStyle) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Button(String(localized: "Nhập tệp SVG...")) {
                    pickSVGFile()
                }
                .font(.system(size: 11, weight: .medium))

                Button(String(localized: "Mẫu Ribbon")) {
                    var cfg = currentConfig
                    cfg.background.svgMarkup = Self.defaultBadgeSVG
                    updateConfig(cfg, true)
                }
                .font(.system(size: 11))
            }

            DSTextField(
                title: "Mã SVG nội tuyến",
                text: Binding(
                    get: { bg.svgMarkup },
                    set: { val in
                        var cfg = currentConfig
                        cfg.background.svgMarkup = val
                        updateConfig(cfg, false)
                    }
                ),
                onCommit: { updateConfig(currentConfig, true) }
            )
        }
    }

    private func animatedAssetControls(bg: TextBackgroundStyle) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Button(String(localized: "Chọn ảnh / GIF / APNG...")) {
                    pickAnimatedImageFile()
                }
                .font(.system(size: 11, weight: .medium))
                Spacer()
            }

            DSTextField(
                title: "Đường dẫn hoặc URL Supabase",
                text: Binding(
                    get: { bg.assetPathOrURL },
                    set: { val in
                        var cfg = currentConfig
                        cfg.background.assetPathOrURL = val
                        updateConfig(cfg, false)
                    }
                ),
                onCommit: { updateConfig(currentConfig, true) }
            )

            Picker("Chế độ phủ ảnh", selection: Binding(
                get: { bg.contentFitMode },
                set: { mode in
                    var cfg = currentConfig
                    cfg.background.contentFitMode = mode
                    updateConfig(cfg, true)
                }
            )) {
                ForEach(TextBackgroundContentFitMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            DSToggleRow(
                title: "Lặp vô tận ảnh động (Loop)",
                isOn: Binding(
                    get: { bg.loopAsset },
                    set: { val in
                        var cfg = currentConfig
                        cfg.background.loopAsset = val
                        updateConfig(cfg, true)
                    }
                )
            )

            DSSliderWithInput(
                title: "Tốc độ phát ảnh động",
                value: Binding(
                    get: { bg.assetSpeed },
                    set: { val in
                        var cfg = currentConfig
                        cfg.background.assetSpeed = val
                        updateConfig(cfg, false)
                    }
                ),
                range: 0.25...4.0,
                step: 0.05,
                defaultValue: 1.0,
                unit: "x",
                onEditingChanged: { if !$0 { updateConfig(currentConfig, true) } }
            )
        }
    }

    private func pickSVGFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.svg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let markup = try String(contentsOf: url, encoding: .utf8)
            var cfg = currentConfig
            cfg.background.svgMarkup = markup
            updateConfig(cfg, true)
        } catch {
            bgLogger.error("Không thể đọc tệp SVG \(url.path): \(error.localizedDescription)")
        }
    }

    private func pickAnimatedImageFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .gif, .jpeg, .webP]
        if panel.runModal() == .OK, let url = panel.url {
            var cfg = currentConfig
            cfg.background.assetPathOrURL = url.path
            updateConfig(cfg, true)
        }
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ updated: TextConfiguration, _ commit: Bool) {
        viewModel.updateTextConfiguration(updated, commit: commit)
    }

    private static let defaultBadgeSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 96">
      <rect x="6" y="8" width="308" height="80" rx="22" fill="#EF4444" stroke="#FFFFFF" stroke-width="5"/>
    </svg>
    """
}
