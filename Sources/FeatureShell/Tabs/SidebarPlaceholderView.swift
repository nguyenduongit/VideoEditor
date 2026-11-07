import SwiftUI
import DesignSystem

public struct SidebarPlaceholderView: View {
    private let title: String
    private let iconName: String
    private let description: String

    public init(
        title: String,
        iconName: String,
        description: String
    ) {
        self.title = title
        self.iconName = iconName
        self.description = description
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DSColors.toggleCyan.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(DSColors.toggleCyan)
            }

            VStack(spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.xs) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DSColors.textPrimary)

                    Text("SOON")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DSColors.toggleCyan))
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

