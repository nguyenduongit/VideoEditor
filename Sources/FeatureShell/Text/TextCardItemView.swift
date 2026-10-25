import SwiftUI
import Domain
import DesignSystem

/// Card hình vuông hiển thị mẫu chữ Text (có hỗ trợ Live Animated Preview khi Hover và huy hiệu JSON Script).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng) của AGENTS.md.
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
        .help(preset.description.isEmpty ? preset.name : preset.description)
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
                .stroke(isHovered ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isHovered ? 1.5 : 1)
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
                Color(hex: preset.previewBackgroundHex),
                DSColors.windowBackground
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
                    .fill(DSColors.trafficZoom)
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
        } else if isHovered && !preset.config.animation.isDefault {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let cycle = 1.8
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                animatedTemplateStage(localTime: t, duration: cycle)
            }
        } else {
            staticTemplateStage
        }
    }

    private var staticTemplateStage: some View {
        VStack(spacing: 4) {
            if let firstSub = preset.subLayers.first {
                Text(firstSub.config.content)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(hex: firstSub.config.textColorHex))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(hex: firstSub.config.backgroundColorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            styledSampleText(preset.config.content)
        }
        .padding(.horizontal, DSSpacing.xs)
    }

    private func animatedTemplateStage(localTime: Double, duration: Double) -> some View {
        let eval = TextAnimationEvaluator.evaluate(
            config: preset.config,
            localTime: localTime,
            duration: duration,
            canvasSize: CGSize(width: 110, height: 80)
        )
        let cfg = eval.config
        let ov = eval.overlay
        let isKaraoke = cfg.animation.comboType == .karaokeBox || cfg.animation.comboType == .karaokeGlow
        let sx = CGFloat(max(0.2, min(1.8, cfg.scale * ov.scaleX)))
        let sy = CGFloat(max(0.2, min(1.8, cfg.scale * ov.scaleY)))
        let dx = CGFloat(max(-28.0, min(28.0, cfg.positionX * 0.25)))
        let dy = CGFloat(max(-20.0, min(20.0, -(cfg.positionY - preset.config.positionY) * 0.25)))

        return VStack(spacing: 4) {
            ZStack {
                if isKaraoke {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: cfg.animation.highlightColorHex).opacity(0.85))
                        .frame(width: 42, height: 20)
                        .offset(x: sin(localTime * 4.0) * 18.0)
                }
                styledSampleText(cfg.content)
                    .scaleEffect(x: sx, y: sy)
                    .rotationEffect(.degrees(cfg.rotation * 0.35))
                    .rotation3DEffect(.degrees(ov.perspectiveX * 50.0), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(ov.perspectiveY * 50.0), axis: (x: 0, y: 1, z: 0))
                    .offset(x: dx, y: dy)
                    .opacity(max(0.15, min(1.0, cfg.opacity)))
            }
            Text(preset.description)
                .font(.system(size: 9))
                .foregroundStyle(DSColors.toggleCyan)
                .lineLimit(1)
        }
        .padding(.horizontal, DSSpacing.xs)
    }

    private func styledSampleText(_ text: String) -> some View {
        let isHollow = preset.config.textColorHex.uppercased() == "NONE"
        return Text(text)
            .font(previewFont)
            .foregroundStyle(isHollow ? Color(hex: preset.config.strokeColorHex) : previewTextColor)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, preset.config.hasBackground ? 6 : 2)
            .padding(.vertical, preset.config.hasBackground ? 3 : 0)
            .background(preset.config.hasBackground ? previewBackgroundColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: preset.config.hasBackground ? 4 : 0))
            .shadow(
                color: preset.config.hasGlow
                    ? Color(hex: preset.config.glowColorHex)
                    : (preset.config.hasShadow ? previewShadowColor : Color.clear),
                radius: CGFloat(min(preset.config.hasGlow ? preset.config.glowRadius : preset.config.shadowRadius, 8)),
                x: CGFloat(preset.config.hasGlow ? 0 : preset.config.shadowOffsetX * 0.5),
                y: CGFloat(preset.config.hasGlow ? 0 : preset.config.shadowOffsetY * 0.5)
            )
    }

    private var previewFont: Font {
        if preset.config.isItalic {
            return .system(size: 13, weight: preset.config.isBold ? .heavy : .regular).italic()
        }
        return .system(size: 13, weight: preset.config.isBold ? .heavy : .regular)
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
