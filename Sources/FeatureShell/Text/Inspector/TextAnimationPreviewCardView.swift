import SwiftUI
import Domain
import DesignSystem

/// Thẻ xem trước hoạt ảnh trực tiếp (Live Animated "Aa" Preview Card) chuẩn CapCut Pro.
/// Tự động chạy mô phỏng chuyển động thực khi người dùng di chuột (Hover) hoặc khi thẻ đang được chọn.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng).
public struct TextAnimationPreviewCardView: View {
    public let title: String
    public let iconName: String
    public let isSelected: Bool
    public let previewConfig: TextConfiguration
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public init(
        title: String,
        iconName: String,
        isSelected: Bool,
        previewConfig: TextConfiguration,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.isSelected = isSelected
        self.previewConfig = previewConfig
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                previewStage
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .clipped()

                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var previewStage: some View {
        if previewConfig.animation.isDefault {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
        } else if isHovered || isSelected {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let cycleDuration = 1.4
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
                animatedSampleText(localTime: t, duration: cycleDuration)
            }
        } else {
            ZStack(alignment: .topTrailing) {
                Text("Aa")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(DSColors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(systemName: iconName)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
                    .padding(3)
            }
        }
    }

    private func animatedSampleText(localTime: Double, duration: Double) -> some View {
        let stageSize = CGSize(width: 72, height: 34)
        let eval = TextAnimationEvaluator.evaluate(
            config: previewConfig,
            localTime: localTime,
            duration: duration,
            canvasSize: stageSize
        )
        let cfg = eval.config
        let ov = eval.overlay
        let isKaraoke = cfg.animation.comboType == .karaokeBox || cfg.animation.comboType == .karaokeGlow
        let sx = CGFloat(max(0.15, min(2.2, cfg.scale * ov.scaleX)))
        let sy = CGFloat(max(0.15, min(2.2, cfg.scale * ov.scaleY)))
        let dx = CGFloat(max(-26.0, min(26.0, cfg.positionX * 0.45)))
        let dy = CGFloat(max(-16.0, min(16.0, -cfg.positionY * 0.45)))

        return ZStack {
            if isKaraoke {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DSColors.trafficMinimize.opacity(0.85))
                    .frame(width: 26, height: 18)
                    .offset(x: sin(localTime * 4.5) * 8.0)
            }
            if eval.rgbSplitIntensity > 0.5 {
                Text(cfg.content)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(DSColors.trafficClose.opacity(0.75))
                    .offset(x: dx - 2.0, y: dy)
                Text(cfg.content)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(DSColors.toggleCyan.opacity(0.75))
                    .offset(x: dx + 2.0, y: dy)
            }
            Text(cfg.content)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
                .padding(.horizontal, 4)
                .scaleEffect(x: sx, y: sy)
                .rotationEffect(.degrees(cfg.rotation * 0.35))
                .rotation3DEffect(
                    .degrees(ov.perspectiveX * 55.0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(ov.perspectiveY * 55.0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .offset(x: dx, y: dy)
                .opacity(max(0.15, min(1.0, cfg.opacity)))
                .blur(radius: CGFloat(min(4.0, (eval.blurRadius + ov.motionBlurRadius) * 0.15)))
        }
    }

    private var cardBackground: Color {
        if isSelected {
            return DSColors.activeTabBackground
        }
        return isHovered ? DSColors.tabHoverBackground : DSColors.blockBackground
    }

    private var borderColor: Color {
        if isSelected {
            return DSColors.toggleCyan
        }
        return isHovered ? DSColors.toggleCyan.opacity(0.45) : DSColors.blockBorder
    }
}
