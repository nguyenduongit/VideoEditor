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
            TextField(String(localized: "Text..."), text: contentBinding, onCommit: {
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
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Typography")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            fontAndFormatRow
            caseAndAlignmentRow
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
        DSSliderWithInput(
            title: "Font Size",
            value: Binding(
                get: { currentConfig.fontSize },
                set: { var cfg = currentConfig; cfg.fontSize = $0; updateConfig(cfg, commit: false) }
            ),
            range: 12.0...160.0, step: 1.0, defaultValue: 48.0, unit: "pt",
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var characterSpacingSlider: some View {
        DSSliderWithInput(
            title: "Character Spacing",
            value: Binding(
                get: { currentConfig.characterSpacing },
                set: { var cfg = currentConfig; cfg.characterSpacing = $0; updateConfig(cfg, commit: false) }
            ),
            range: -5.0...30.0, step: 0.5, defaultValue: 0.0, unit: "pt",
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var fontAndFormatRow: some View {
        HStack(spacing: DSSpacing.sm) {
            HStack(spacing: 4) {
                formatToggleButton(title: "B", isActive: currentConfig.isBold, isBold: true) {
                    var cfg = currentConfig; cfg.isBold.toggle(); commitConfig(cfg)
                }
                formatToggleButton(title: "I", isActive: currentConfig.isItalic, isItalic: true) {
                    var cfg = currentConfig; cfg.isItalic.toggle(); commitConfig(cfg)
                }
                formatToggleButton(title: "U", isActive: currentConfig.isUnderlined, isUnderlined: true) {
                    var cfg = currentConfig; cfg.isUnderlined.toggle(); commitConfig(cfg)
                }
            }
            Spacer(minLength: 4)
            fontPickerButton
        }
    }

    private var caseAndAlignmentRow: some View {
        let text = currentConfig.content
        let isUpper = !text.isEmpty && text == text.uppercased() && text != text.lowercased()
        let isLower = !text.isEmpty && text == text.lowercased() && text != text.uppercased()
        let isTitle = !text.isEmpty && !isUpper && !isLower && text == text.localizedCapitalized
        return HStack(spacing: DSSpacing.sm) {
            HStack(spacing: 4) {
                formatToggleButton(title: "AA", isActive: isUpper) {
                    var cfg = currentConfig; cfg.content = cfg.content.uppercased(); commitConfig(cfg)
                }
                formatToggleButton(title: "Aa", isActive: isTitle) {
                    var cfg = currentConfig; cfg.content = cfg.content.localizedCapitalized; commitConfig(cfg)
                }
                formatToggleButton(title: "aa", isActive: isLower) {
                    var cfg = currentConfig; cfg.content = cfg.content.lowercased(); commitConfig(cfg)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                alignmentButton(icon: "text.alignleft", type: .left)
                alignmentButton(icon: "text.aligncenter", type: .center)
                alignmentButton(icon: "text.alignright", type: .right)
            }
        }
    }

    private func alignmentButton(icon: String, type: TextAlignmentType) -> some View {
        let isActive = currentConfig.alignment == type
        return Button {
            var cfg = currentConfig
            cfg.alignment = type
            commitConfig(cfg)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? Color.white : DSColors.textSecondary)
                .frame(width: 28, height: 24)
                .background(isActive ? DSColors.accent : DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var fontPickerButton: some View {
        HStack(spacing: 2) {
            Button(action: { isFontPickerPresented.toggle() }) {
                HStack(spacing: 5) {
                    if viewModel.fontManager.isFavorite(fontID: currentConfig.fontName) {
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
        .frame(maxWidth: 175)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(DSColors.blockBorder, lineWidth: 1))
        .popover(isPresented: $isFontPickerPresented, arrowEdge: .bottom) {
            FontPickerPopoverView(
                selectedFont: currentConfig.fontName,
                fontManager: viewModel.fontManager,
                onSelect: { chosenFont in
                    var cfg = currentConfig; cfg.fontName = chosenFont; commitConfig(cfg)
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
        let newIndex = (currentIndex + (forward ? 1 : -1) + allFonts.count) % allFonts.count
        var cfg = currentConfig
        cfg.fontName = allFonts[newIndex].id
        commitConfig(cfg)
    }

    private func formatToggleButton(
        title: String,
        isActive: Bool,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isBold ? .bold : .medium))
                .italic(isItalic)
                .underline(isUnderlined)
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

