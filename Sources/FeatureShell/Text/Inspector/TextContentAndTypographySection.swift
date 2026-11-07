import SwiftUI
import Domain
import DesignSystem

/// Khối điều khiển Nội dung & Kiểu chữ (Content & Typography) cho Text Clip.
/// Gồm ô nhập văn bản, chọn phông chữ, định dạng B/I, cỡ chữ (kèm Keyframe),
/// và khoảng cách ký tự (Character Spacing). Line Spacing đã được loại bỏ.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextContentAndTypographySection: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var isFontPickerPresented: Bool = false

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            contentSection
            typographySection
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(String(localized: "Content"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            let contentBinding = Binding<String>(
                get: { currentConfig.content },
                set: { newText in
                    var cfg = currentConfig
                    cfg.content = TextConfiguration.sanitizeSingleLine(newText)
                    updateConfig(cfg, commit: false)
                }
            )
            TextField(String(localized: "Văn bản..."), text: contentBinding, onCommit: {
                commitConfig(currentConfig)
            })
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(DSColors.textPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .frame(height: 28)
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

    // MARK: - Typography Section

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "Typography"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            fontAndFormatRow

            fontSizeSlider

            characterSpacingSlider
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var fontSizeSlider: some View {
        let sizeBinding = Binding<Double>(
            get: { currentConfig.fontSize },
            set: { newSize in
                var cfg = currentConfig
                cfg.fontSize = newSize
                updateConfig(cfg, commit: false)
            }
        )
        return DSSliderWithInput(
            title: "Font Size",
            value: sizeBinding,
            range: 12.0...160.0,
            step: 1.0,
            defaultValue: 48.0,
            unit: "pt",
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var characterSpacingSlider: some View {
        let spacingBinding = Binding<Double>(
            get: { currentConfig.characterSpacing },
            set: { newSpacing in
                var cfg = currentConfig
                cfg.characterSpacing = newSpacing
                updateConfig(cfg, commit: false)
            }
        )
        return DSSliderWithInput(
            title: "Character Spacing",
            value: spacingBinding,
            range: -5.0...30.0,
            step: 0.5,
            defaultValue: 0.0,
            unit: "pt",
            onEditingChanged: onSliderEditingEnded
        )
    }

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
        HStack(spacing: 2) {
            Button(action: { isFontPickerPresented.toggle() }) {
                HStack(spacing: 5) {
                    let isFav = viewModel.fontManager.isFavorite(fontID: currentConfig.fontName)
                    if isFav {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.yellow)
                    }

                    Text(viewModel.fontManager.displayName(for: currentConfig.fontName))
                        .font(.system(size: 12))
                        .foregroundStyle(DSColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 2)
                }
                .padding(.leading, 8)
                .padding(.trailing, 2)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DSStepperButton(
                onIncrement: { cycleFont(forward: false) },
                onDecrement: { cycleFont(forward: true) }
            )
            .padding(.trailing, 2)
        }
        .frame(height: 24)
        .frame(maxWidth: 185)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
        .popover(isPresented: $isFontPickerPresented, arrowEdge: .bottom) {
            FontPickerPopoverView(
                selectedFont: currentConfig.fontName,
                fontManager: viewModel.fontManager,
                onSelect: { chosenFont in
                    var cfg = currentConfig
                    cfg.fontName = chosenFont
                    commitConfig(cfg)
                },
                onDismiss: { isFontPickerPresented = false }
            )
        }
    }

    private func cycleFont(forward: Bool) {
        let allFonts = viewModel.fontManager.fonts
        guard !allFonts.isEmpty else { return }

        let currentName = currentConfig.fontName
        let currentIndex = allFonts.firstIndex(where: {
            $0.id.caseInsensitiveCompare(currentName) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(currentName) == .orderedSame
        }) ?? 0

        let delta = forward ? 1 : -1
        let newIndex = (currentIndex + delta + allFonts.count) % allFonts.count
        let nextFont = allFonts[newIndex]

        var cfg = currentConfig
        cfg.fontName = nextFont.id
        commitConfig(cfg)
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
        viewModel.activeTextLayerConfiguration
    }

    private func updateConfig(_ config: TextConfiguration, commit: Bool) {
        viewModel.updateActiveTextLayer(config, commit: commit)
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

