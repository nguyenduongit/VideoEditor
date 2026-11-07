import SwiftUI
import AppKit
import OSLog
import UniformTypeIdentifiers
import Domain
import DesignSystem

private let stickerInspectorLogger = Logger(subsystem: "VideoEditor", category: "StickerAppearanceSection")

/// Phân vùng tùy biến Nguồn nhãn dán (`SVG` nội tuyến / `GIF` / `APNG` / URL Supabase),
/// Hòa trộn (`Blend Mode`), Đổ bóng (`Drop Shadow`) và Lưu mẫu Sticker lên kho chung.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
struct StickerAppearanceAndSourceSection: View {
    @Bindable var viewModel: InspectorViewModel
    @State private var presetNameDraft: String = ""
    @State private var presetCategoryDraft: StickerCategory = .badge
    @State private var showSavedFeedback = false

    private var currentConfig: StickerConfiguration {
        viewModel.stickerConfiguration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            sourceSection
            appearanceSection
            savePresetSection
        }
    }

    private var sourceSection: some View {
        let cfg = currentConfig
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "NGUỒN NHÃN DÁN (SVG / GIF / APNG)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            Picker("Định dạng", selection: Binding(
                get: { cfg.format },
                set: { fmt in
                    var updated = cfg
                    updated.format = fmt
                    viewModel.updateStickerConfiguration(updated, commit: true)
                }
            )) {
                ForEach(StickerFormat.allCases) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if cfg.format == .svg {
                Button(String(localized: "Nhập tệp Vector SVG...")) {
                    pickLocalSVGFile()
                }
                .font(.system(size: 11, weight: .medium))

                DSTextField(
                    title: "Mã SVG nội tuyến (Supabase JSON)",
                    text: Binding(
                        get: { cfg.svgMarkup ?? "" },
                        set: { val in
                            var updated = cfg
                            updated.svgMarkup = val
                            viewModel.updateStickerConfiguration(updated, commit: false)
                        }
                    ),
                    onCommit: { viewModel.updateStickerConfiguration(currentConfig, commit: true) }
                )
            } else {
                Button(String(localized: "Chọn tệp PNG / GIF / APNG...")) {
                    pickLocalRasterOrAnimatedFile()
                }
                .font(.system(size: 11, weight: .medium))

                DSTextField(
                    title: "Đường dẫn hoặc URL Supabase",
                    text: Binding(
                        get: { cfg.sourceURLString ?? "" },
                        set: { val in
                            var updated = cfg
                            updated.sourceURLString = val.isEmpty ? nil : val
                            viewModel.updateStickerConfiguration(updated, commit: false)
                        }
                    ),
                    onCommit: { viewModel.updateStickerConfiguration(currentConfig, commit: true) }
                )
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var appearanceSection: some View {
        let cfg = currentConfig
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(String(localized: "Hòa trộn (Blend Mode)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Picker("Blend", selection: Binding(
                    get: { cfg.blendMode },
                    set: { mode in
                        var updated = cfg
                        updated.blendMode = mode
                        viewModel.updateStickerConfiguration(updated, commit: true)
                    }
                )) {
                    ForEach(TextLayerBlendMode.allCases) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
            }

            DSToggleRow(
                title: "Đổ bóng nhãn dán (Drop Shadow)",
                isOn: Binding(
                    get: { cfg.hasShadow },
                    set: { val in
                        var updated = cfg
                        updated.hasShadow = val
                        viewModel.updateStickerConfiguration(updated, commit: true)
                    }
                )
            )

            if cfg.hasShadow {
                TextColorSwatchesRow(title: "Màu bóng", selectedHex: cfg.shadowColorHex) { hex in
                    var updated = cfg
                    updated.shadowColorHex = hex
                    viewModel.updateStickerConfiguration(updated, commit: true)
                }

                DSSliderWithInput(
                    title: "Độ nhòe bóng",
                    value: Binding(
                        get: { cfg.shadowBlur },
                        set: { val in
                            var updated = cfg
                            updated.shadowBlur = val
                            viewModel.updateStickerConfiguration(updated, commit: false)
                        }
                    ),
                    range: 0.0...40.0,
                    step: 0.5,
                    defaultValue: 8.0,
                    unit: "px",
                    onEditingChanged: { if !$0 { viewModel.updateStickerConfiguration(currentConfig, commit: true) } }
                )

                DSSliderWithInput(
                    title: "Khoảng cách bóng",
                    value: Binding(
                        get: { cfg.shadowDistance },
                        set: { val in
                            var updated = cfg
                            updated.shadowDistance = val
                            viewModel.updateStickerConfiguration(updated, commit: false)
                        }
                    ),
                    range: 0.0...40.0,
                    step: 0.5,
                    defaultValue: 4.0,
                    unit: "px",
                    onEditingChanged: { if !$0 { viewModel.updateStickerConfiguration(currentConfig, commit: true) } }
                )
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var savePresetSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(String(localized: "LƯU MẪU STICKER (SUPABASE)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            HStack(spacing: DSSpacing.xs) {
                TextField(String(localized: "Tên mẫu Sticker..."), text: $presetNameDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(DSColors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))

                Button(action: saveStickerAsPreset) {
                    Text(showSavedFeedback ? "Đã lưu" : "Lưu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DSColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func pickLocalSVGFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.svg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let xml = try String(contentsOf: url, encoding: .utf8)
            var updated = currentConfig
            updated.format = .svg
            updated.svgMarkup = xml
            viewModel.updateStickerConfiguration(updated, commit: true)
        } catch {
            stickerInspectorLogger.error("Không thể đọc tệp SVG \(url.path): \(error.localizedDescription)")
        }
    }

    private func pickLocalRasterOrAnimatedFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .gif]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var updated = currentConfig
        let ext = url.pathExtension.lowercased()
        if ext == "gif" { updated.format = .gif } else if updated.format == .svg { updated.format = .apng }
        updated.sourceURLString = url.path
        viewModel.updateStickerConfiguration(updated, commit: true)
    }

    private func saveStickerAsPreset() {
        let trimmed = presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? (viewModel.selectedClip?.name ?? "Sticker Mới") : trimmed
        let cfg = currentConfig
        let preset = StickerPreset(
            id: "user_sticker_\(UUID().uuidString.prefix(8).lowercased())",
            name: finalName,
            description: "Nhãn dán tùy chỉnh (\(cfg.format.displayName))",
            category: presetCategoryDraft,
            format: cfg.format,
            tags: [cfg.format.rawValue, "custom"],
            defaultDuration: viewModel.selectedClip?.timeRange.duration.seconds ?? 3.0,
            assetPath: cfg.sourceURLString,
            systemSymbolFallback: cfg.systemSymbolFallback ?? "sparkles",
            config: cfg,
            isSystem: false
        )
        viewModel.dependencies.stickerTemplates.updateInMemoryPreset(preset)
        NotificationCenter.default.post(name: .presetStoreDidUpdate, object: nil)
        showSavedFeedback = true
        if let repo = viewModel.dependencies.presetRepositories.stickerRepository {
            Task {
                do {
                    try await repo.savePreset(preset)
                } catch {
                    stickerInspectorLogger.error("Lưu StickerPreset lên Supabase thất bại: \(error.localizedDescription)")
                }
            }
        }
    }
}
