import SwiftUI
import Domain
import DesignSystem

/// Khối điều khiển Nội dung & Kiểu chữ (Content & Typography) cho Text Clip.
/// Gồm ô nhập văn bản, chọn phông chữ, định dạng B/I/U, cỡ chữ (kèm Keyframe),
/// và khoảng cách ký tự (Character Spacing).
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
        DSSectionCard(title: String(localized: "Content")) {
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
            .frame(height: 26)
            .background(DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Typography Section

    private var typographySection: some View {
        DSSectionCard(title: "Typography") {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                fontPickerButton
                toolbarFormattingRow
                fontSizeSlider
                characterSpacingSlider
            }
        }
    }

    private var fontSizeSlider: some View {
        DSSliderWithInput(
            title: "Font Size",
            value: Binding(
                get: { currentConfig.fontSize },
                set: { var cfg = currentConfig; cfg.fontSize = $0; updateConfig(cfg, commit: false) }
            ),
            range: 12.0...160.0, step: 1.0, defaultValue: 60.0, unit: "pt",
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

    private var toolbarFormattingRow: some View {
        let text = currentConfig.content
        let isUpper = !text.isEmpty && text == text.uppercased() && text != text.lowercased()
        let isLower = !text.isEmpty && text == text.lowercased() && text != text.uppercased()
        let isTitle = !text.isEmpty && !isUpper && !isLower && text == text.localizedCapitalized

        return HStack(spacing: 0) {
            // Nhóm 1: B, I, U
            DSSegmentGroup(
                items: [
                    DSSegmentItem(id: "bold", title: "B", isBold: true, help: "Bold"),
                    DSSegmentItem(id: "italic", title: "/", isItalic: true, help: "Italic"),
                    DSSegmentItem(id: "underline", title: "U", isUnderlined: true, help: "Underline")
                ],
                isSelected: { id in
                    switch id {
                    case "bold": return currentConfig.isBold
                    case "italic": return currentConfig.isItalic
                    case "underline": return currentConfig.isUnderlined
                    default: return false
                    }
                },
                onSelect: { id in
                    var cfg = currentConfig
                    switch id {
                    case "bold": cfg.isBold.toggle()
                    case "italic": cfg.isItalic.toggle()
                    case "underline": cfg.isUnderlined.toggle()
                    default: break
                    }
                    commitConfig(cfg)
                }
            )

            Spacer(minLength: 4)
            clusterDivider
            Spacer(minLength: 4)

            // Nhóm 2: AA, Aa, aa
            DSSegmentGroup(
                items: [
                    DSSegmentItem(id: "upper", title: "AA", help: "Uppercase"),
                    DSSegmentItem(id: "title", title: "Aa", help: "Title Case"),
                    DSSegmentItem(id: "lower", title: "aa", help: "Lowercase")
                ],
                isSelected: { id in
                    switch id {
                    case "upper": return isUpper
                    case "title": return isTitle
                    case "lower": return isLower
                    default: return false
                    }
                },
                onSelect: { id in
                    var cfg = currentConfig
                    switch id {
                    case "upper": cfg.content = cfg.content.uppercased()
                    case "title": cfg.content = cfg.content.localizedCapitalized
                    case "lower": cfg.content = cfg.content.lowercased()
                    default: break
                    }
                    commitConfig(cfg)
                }
            )

            Spacer(minLength: 4)
            clusterDivider
            Spacer(minLength: 4)

            // Nhóm 3: left, center, right
            DSSegmentGroup(
                items: [
                    DSSegmentItem(id: "left", iconName: "text.alignleft", help: "Align Left"),
                    DSSegmentItem(id: "center", iconName: "text.aligncenter", help: "Align Center"),
                    DSSegmentItem(id: "right", iconName: "text.alignright", help: "Align Right")
                ],
                isSelected: { id in
                    switch id {
                    case "left": return currentConfig.alignment == .left
                    case "center": return currentConfig.alignment == .center
                    case "right": return currentConfig.alignment == .right
                    default: return false
                    }
                },
                onSelect: { id in
                    var cfg = currentConfig
                    switch id {
                    case "left": cfg.alignment = .left
                    case "center": cfg.alignment = .center
                    case "right": cfg.alignment = .right
                    default: break
                    }
                    commitConfig(cfg)
                }
            )
        }
    }

    private var clusterDivider: some View {
        Rectangle()
            .fill(DSColors.blockBorder)
            .frame(width: 1, height: 16)
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
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DSStepperButton(
                onIncrement: { cycleFont(forward: false) },
                onDecrement: { cycleFont(forward: true) }
            )
            .padding(.trailing, 2)
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity)
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
