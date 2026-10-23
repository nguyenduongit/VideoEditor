import SwiftUI
import Domain
import DesignSystem

/// Card hình vuông hiển thị mẫu chữ Text, đồng bộ phong cách với MediaAssetItemView và AdjustmentCardItemView.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextCardItemView: View {
    private let preset: TextPreset
    private let onAdd: () -> Void
    @State private var isHovered = false

    public init(preset: TextPreset, onAdd: @escaping () -> Void) {
        self.preset = preset
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            squareThumbnailBox
            nameLabel
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onAdd()
        }
    }

    private var squareThumbnailBox: some View {
        ZStack {
            presetBackground
            centerTextPreview
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(isHovered ? DSColors.accent : DSColors.blockBorder, lineWidth: isHovered ? 1.5 : 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                plusButton
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var presetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.16, blue: 0.18),
                Color(red: 0.10, green: 0.10, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var nameLabel: some View {
        Text(preset.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DSColors.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var plusButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.16, green: 0.79, blue: 0.38))
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.xs)
        .help("Thêm vào Timeline")
    }

    @ViewBuilder
    private var centerTextPreview: some View {
        if preset.id == "default" {
            VStack(spacing: 4) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Text("Văn bản")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
            }
        } else {
            VStack(spacing: 2) {
                Text(previewSampleText)
                    .font(previewFont)
                    .foregroundStyle(previewTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.horizontal, preset.config.hasBackground ? 6 : 2)
                    .padding(.vertical, preset.config.hasBackground ? 3 : 0)
                    .background(
                        preset.config.hasBackground ? previewBackgroundColor : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: preset.config.hasBackground ? 4 : 0))
                    .shadow(
                        color: preset.config.hasShadow ? previewShadowColor : Color.clear,
                        radius: CGFloat(min(preset.config.shadowRadius, 8)),
                        x: CGFloat(preset.config.shadowOffsetX),
                        y: CGFloat(preset.config.shadowOffsetY)
                    )

                Text(preset.description)
                    .font(.system(size: 9))
                    .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, DSSpacing.xs)
        }
    }

    private var previewSampleText: String {
        preset.config.content
    }

    private var previewFont: Font {
        if preset.config.isItalic {
            return .system(size: 14, weight: preset.config.isBold ? .bold : .regular).italic()
        }
        return .system(size: 14, weight: preset.config.isBold ? .bold : .regular)
    }

    private var previewTextColor: Color {
        Color(hex: preset.config.textColorHex)
    }

    private var previewBackgroundColor: Color {
        Color(hex: preset.config.backgroundColorHex)
    }

    private var previewShadowColor: Color {
        Color(hex: preset.config.shadowColorHex)
    }
}
