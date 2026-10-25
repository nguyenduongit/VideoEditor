import SwiftUI
import Domain
import DesignSystem

/// Tab "Text" (Cơ bản) cho đối tượng Text Clip.
/// Tùy chỉnh nội dung, font chữ, cỡ chữ, định dạng B/I cùng dòng với font picker,
/// và bảng điều khiển 5 hiệu ứng màu tinh gọn với thanh màu dùng chung.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var isFontPickerPresented: Bool = false

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            contentSection
            typographySection
            TextColorStyleSubtabsView(viewModel: viewModel)
        }
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - Sections

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Content")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

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
                .frame(minHeight: 65, maxHeight: 95)
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.small)
                        .stroke(DSColors.blockBorder, lineWidth: 1)
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

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Typography")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            fontAndFormatRow

            let sizeBinding = Binding<Double>(
                get: { currentConfig.fontSize },
                set: { newSize in
                    var cfg = currentConfig
                    cfg.fontSize = newSize
                    updateConfig(cfg, commit: false)
                }
            )
            DSSliderWithInput(
                title: "Font Size",
                value: sizeBinding,
                range: 12.0...160.0,
                step: 1.0,
                defaultValue: 48.0,
                unit: "pt",
                onEditingChanged: onSliderEditingEnded
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

    /// Định dạng chữ (Bold, Italic) đặt bên trái, cùng dòng với ô chọn phông chữ.
    private var fontAndFormatRow: some View {
        HStack(spacing: DSSpacing.sm) {
            HStack(spacing: 4) {
                boldButton
                italicButton
            }

            Spacer(minLength: 4)

            fontPickerButton
        }
    }

    private var fontPickerButton: some View {
        Button(action: { isFontPickerPresented.toggle() }) {
            HStack(spacing: 5) {
                let isFav = CustomFontManager.shared.isFavorite(fontID: currentConfig.fontName)
                if isFav {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.yellow)
                }

                Text(CustomFontManager.shared.displayName(for: currentConfig.fontName))
                    .font(.system(size: 12))
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .frame(maxWidth: 175)
            .background(DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isFontPickerPresented, arrowEdge: .bottom) {
            FontPickerPopoverView(
                selectedFont: currentConfig.fontName,
                onSelect: { chosenFont in
                    var cfg = currentConfig
                    cfg.fontName = chosenFont
                    commitConfig(cfg)
                },
                onDismiss: { isFontPickerPresented = false }
            )
        }
    }

    private var boldButton: some View {
        formatToggleButton(title: "B", isActive: currentConfig.isBold, isBold: true) {
            var cfg = currentConfig
            cfg.isBold.toggle()
            commitConfig(cfg)
        }
    }

    private var italicButton: some View {
        formatToggleButton(title: "I", isActive: currentConfig.isItalic, isItalic: true) {
            var cfg = currentConfig
            cfg.isItalic.toggle()
            commitConfig(cfg)
        }
    }

    private func formatToggleButton(
        title: String,
        isActive: Bool,
        isBold: Bool = false,
        isItalic: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isBold ? .bold : .medium))
                .italic(isItalic)
                .foregroundStyle(isActive ? Color.white : DSColors.textSecondary)
                .frame(width: 26, height: 24)
                .background(isActive ? DSColors.accent : DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
