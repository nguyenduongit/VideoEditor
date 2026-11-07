import SwiftUI
import Domain
import DesignSystem

/// Thẻ xem trước hoạt ảnh trực tiếp (Live Animated "Text" Preview Card) chuẩn CapCut Pro.
/// Tự động kết xuất hoạt ảnh chân thực 1:1 qua `TextRendererEngine` khi người dùng di chuột (Hover).
/// Khi không hover, hiển thị chữ mẫu "Text" tĩnh rõ nét kèm biểu tượng mô tả.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng).
public struct TextAnimationPreviewCardView: View {
    public let title: String
    public let iconName: String
    public let isSelected: Bool
    public let preset: AnimationPreset?
    public let action: () -> Void

    @State private var isHovered: Bool = false

    public init(
        title: String,
        iconName: String,
        isSelected: Bool,
        preset: AnimationPreset?,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = iconName
        self.isSelected = isSelected
        self.preset = preset
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                previewStage
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .clipped()

                Text(title)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(cardBackground)
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.8)
            )
            .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var previewStage: some View {
        if preset == nil {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let preset, isHovered {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let cycle = cycleDuration(for: preset.phase)
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                animatedThumbnailStage(preset: preset, localTime: t, duration: cycle)
            }
        } else if let preset {
            staticThumbnailStage(preset: preset)
        }
    }

    private func staticThumbnailStage(preset: AnimationPreset) -> some View {
        ZStack(alignment: .topTrailing) {
            Text("Text")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Image(systemName: iconName)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary.opacity(0.8))
                .padding(3)
        }
    }

    private func animatedThumbnailStage(preset: AnimationPreset, localTime: Double, duration: Double) -> some View {
        let frame = TextThumbnailRenderer.renderAnimationPreviewFrame(
            preset: preset,
            localTime: localTime,
            duration: duration,
            targetSize: CGSize(width: 320, height: 160)
        )

        return ZStack {
            if let frame {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Text")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
            }
        }
    }

    private func cycleDuration(for phase: AnimationPhaseCategory) -> Double {
        switch phase {
        case .inAnimation: return 1.4
        case .loopAnimation: return 2.0
        case .outAnimation: return 1.5
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
