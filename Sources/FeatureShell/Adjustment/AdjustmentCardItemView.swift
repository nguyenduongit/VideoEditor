import SwiftUI
import Domain
import DesignSystem

/// Card hình vuông hiển thị mẫu Adjustment Layer, đồng bộ phong cách với MediaAssetItemView.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentCardItemView: View {
    private let preset: AdjustmentPreset
    private let onAdd: () -> Void
    @State private var isHovered = false

    public init(preset: AdjustmentPreset, onAdd: @escaping () -> Void) {
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
            centerIconOrBadge
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
    private var centerIconOrBadge: some View {
        if preset.id == "default" {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
        } else {
            VStack {
                Spacer()
                HStack {
                    Text(preset.description)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(DSSpacing.xs)
                .background(Color.black.opacity(0.45))
            }
        }
    }

    @ViewBuilder
    private var presetBackground: some View {
        switch preset.id {
        case "cinematic":
            LinearGradient(colors: [Color(red: 0.1, green: 0.5, blue: 0.6), Color(red: 0.85, green: 0.45, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "sunset":
            LinearGradient(colors: [Color(red: 0.9, green: 0.3, blue: 0.2), Color(red: 0.95, green: 0.7, blue: 0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "cold_blue":
            LinearGradient(colors: [Color(red: 0.2, green: 0.3, blue: 0.6), Color(red: 0.4, green: 0.75, blue: 0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "korean_glow":
            LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.75), Color(red: 0.98, green: 0.88, blue: 0.85)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "vintage":
            LinearGradient(colors: [Color(red: 0.45, green: 0.38, blue: 0.28), Color(red: 0.72, green: 0.62, blue: 0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "cyberpunk":
            LinearGradient(colors: [Color(red: 0.75, green: 0.1, blue: 0.8), Color(red: 0.0, green: 0.85, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "vivid":
            LinearGradient(colors: [Color(red: 0.95, green: 0.2, blue: 0.3), Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.5, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case "monochrome":
            LinearGradient(colors: [Color(white: 0.15), Color(white: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            DSColors.windowBackground
        }
    }
}
