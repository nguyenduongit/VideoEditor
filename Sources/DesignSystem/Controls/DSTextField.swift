import SwiftUI

/// Standard DesignSystem text field with dark theme styling.
/// Complies with R6.3 and R8.2 of AGENTS.md.
public struct DSTextField: View {
    private let title: String
    @Binding private var text: String
    private let onCommit: (() -> Void)?

    public init(
        title: String,
        text: Binding<String>,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self._text = text
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            TextField("", text: $text, onCommit: {
                onCommit?()
            })
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(DSColors.textPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
        }
    }
}
