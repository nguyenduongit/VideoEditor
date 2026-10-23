import SwiftUI
import Domain
import DesignSystem

/// Tab "Văn bản" (Basic) cho đối tượng Text Clip.
/// Tùy chỉnh nội dung, font chữ, cỡ chữ, định dạng, màu sắc và khoảng cách.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    private let availableFonts = [
        "System", "Helvetica", "Arial", "Impact", "Times New Roman",
        "Courier New", "Georgia", "Trebuchet MS", "Avenir Next", "Futura"
    ]

    private let colorSwatches = [
        "#FFFFFF", "#000000", "#FDE047", "#EF4444",
        "#3B82F6", "#22C55E", "#F97316", "#A855F7"
    ]

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            contentSection
            typographySection
            formatAndColorSection
            spacingSection
        }
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - Sections

    private var contentSection: some View {
        DSCollapsibleSection(title: "Nội dung văn bản", defaultExpanded: true) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                let contentBinding = Binding<String>(
                    get: { currentConfig.content },
                    set: { newText in
                        var cfg = currentConfig
                        cfg.content = newText
                        updateConfig(cfg, commit: false)
                    }
                )
                TextEditor(text: contentBinding)
                    .font(.system(size: 12))
                    .foregroundStyle(DSColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(DSSpacing.sm)
                    .frame(minHeight: 70, maxHeight: 110)
                    .background(DSColors.windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.small)
                            .stroke(DSColors.blockBorder, lineWidth: 1)
                    )
            }
        }
    }

    private var typographySection: some View {
        DSCollapsibleSection(title: "Phông chữ & Cỡ chữ", defaultExpanded: true) {
            VStack(spacing: DSSpacing.md) {
                fontPickerRow

                let sizeBinding = Binding<Double>(
                    get: { currentConfig.fontSize },
                    set: { newSize in
                        var cfg = currentConfig
                        cfg.fontSize = newSize
                        updateConfig(cfg, commit: false)
                    }
                )
                DSSliderWithInput(
                    title: "Cỡ chữ",
                    value: sizeBinding,
                    range: 12.0...160.0,
                    step: 1.0,
                    defaultValue: 48.0,
                    unit: "pt",
                    onEditingChanged: onSliderEditingEnded
                )
            }
        }
    }

    private var fontPickerRow: some View {
        HStack {
            Text("Phông chữ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            Picker("", selection: Binding<String>(
                get: { currentConfig.fontName },
                set: { newFont in
                    var cfg = currentConfig
                    cfg.fontName = newFont
                    commitConfig(cfg)
                }
            )) {
                ForEach(availableFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
        }
    }

    private var formatAndColorSection: some View {
        DSCollapsibleSection(title: "Định dạng & Màu sắc", defaultExpanded: true) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(spacing: DSSpacing.sm) {
                    boldButton
                    italicButton
                    Divider().frame(height: 18)
                    alignmentButtons
                }

                Text("Màu chữ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)

                colorSwatchesRow
            }
        }
    }

    private var boldButton: some View {
        Button(action: {
            var cfg = currentConfig
            cfg.isBold.toggle()
            commitConfig(cfg)
        }) {
            Text("B")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(currentConfig.isBold ? Color.white : DSColors.textSecondary)
                .frame(width: 28, height: 26)
                .background(currentConfig.isBold ? DSColors.accent : DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var italicButton: some View {
        Button(action: {
            var cfg = currentConfig
            cfg.isItalic.toggle()
            commitConfig(cfg)
        }) {
            Text("I")
                .font(.system(size: 12, weight: .medium).italic())
                .foregroundStyle(currentConfig.isItalic ? Color.white : DSColors.textSecondary)
                .frame(width: 28, height: 26)
                .background(currentConfig.isItalic ? DSColors.accent : DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var alignmentButtons: some View {
        HStack(spacing: 2) {
            alignButton(type: .left, icon: "text.alignleft")
            alignButton(type: .center, icon: "text.aligncenter")
            alignButton(type: .right, icon: "text.alignright")
        }
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func alignButton(type: TextAlignmentType, icon: String) -> some View {
        let isSelected = currentConfig.alignment == type
        return Button(action: {
            var cfg = currentConfig
            cfg.alignment = type
            commitConfig(cfg)
        }) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                .frame(width: 26, height: 24)
                .background(isSelected ? DSColors.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    private var colorSwatchesRow: some View {
        TextColorSwatchesRow(selectedHex: currentConfig.textColorHex, swatches: colorSwatches) { hex in
            var cfg = currentConfig
            cfg.textColorHex = hex
            commitConfig(cfg)
        }
    }

    private var spacingSection: some View {
        DSCollapsibleSection(title: "Khoảng cách", defaultExpanded: false) {
            VStack(spacing: DSSpacing.md) {
                let charBinding = Binding<Double>(
                    get: { currentConfig.characterSpacing },
                    set: { newSpacing in
                        var cfg = currentConfig
                        cfg.characterSpacing = newSpacing
                        updateConfig(cfg, commit: false)
                    }
                )
                DSSliderWithInput(
                    title: "Khoảng cách ký tự",
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
                    title: "Khoảng cách dòng",
                    value: lineBinding,
                    range: 0.0...40.0,
                    step: 1.0,
                    defaultValue: 4.0,
                    unit: "pt",
                    onEditingChanged: onSliderEditingEnded
                )
            }
        }
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
            viewModel.updateLiveText(key: "textContent", text: config.content)
            viewModel.updateLiveValue(key: "fontSize", value: config.fontSize)
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
