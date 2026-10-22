import SwiftUI

public struct DSActionButton: View {
    private let title: String
    private let action: () -> Void

    public init(
        title: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, DSSpacing.xl)
                .frame(minWidth: DSSize.exportButtonMinWidth, minHeight: DSSize.exportButtonHeight)
                .background(DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
                .contentShape(RoundedRectangle(cornerRadius: DSRadius.control))
        }
        .buttonStyle(.plain)
    }
}
