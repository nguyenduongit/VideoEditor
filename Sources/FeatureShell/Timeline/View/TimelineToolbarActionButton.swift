import SwiftUI
import DesignSystem

struct TimelineToolbarActionButton: View {
    let icon: String
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var isActive: Bool = false
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    private static let beatCyan = Color(red: 0.0, green: 0.85, blue: 0.95)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.65)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .onHover { isHovered = $0 }
        .help(help)
    }

    private var foregroundColor: Color {
        if isDisabled { return DSColors.textSecondary.opacity(0.6) }
        if isActive { return Self.beatCyan }
        return DSColors.textPrimary
    }

    private var backgroundColor: Color {
        if isActive { return Self.beatCyan.opacity(0.16) }
        if isHovered && !isDisabled { return Color.white.opacity(0.10) }
        return DSColors.layerTrackBackground
    }

    private var borderColor: Color {
        if isActive { return Self.beatCyan.opacity(0.55) }
        if isHovered && !isDisabled { return Color.white.opacity(0.20) }
        return DSColors.blockBorder
    }
}

