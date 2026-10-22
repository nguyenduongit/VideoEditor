import SwiftUI

public struct DSTabButton: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.xl)
                .frame(maxHeight: .infinity)
                .background(isSelected ? DSColors.activeTabBackground : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
