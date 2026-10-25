import SwiftUI

public struct DSActionButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, DSSpacing.lg)
            .frame(minWidth: DSSize.exportButtonMinWidth, minHeight: DSSize.exportButtonHeight)
            .background(DSColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.control))
        }
        .buttonStyle(.plain)
    }
}
