import SwiftUI

public enum DSTopbarButtonStyle: Sendable, Equatable {
    case primary
    case secondary
}

public struct DSTopbarButton: View {
    private let title: String
    private let icon: String
    private let style: DSTopbarButtonStyle
    private let action: () -> Void
    @State private var isHovered: Bool = false

    public init(
        title: String,
        icon: String,
        style: DSTopbarButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 9)
            .frame(height: DSSize.topbarButtonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.control)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.control))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return isHovered ? DSColors.textPrimary : DSColors.textPrimary.opacity(0.85)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? DSColors.accent.opacity(0.88) : DSColors.accent
        case .secondary:
            return isHovered ? DSColors.blockBackground.opacity(0.9) : DSColors.blockBackground
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.clear
        case .secondary:
            return DSColors.blockBorder
        }
    }
}

