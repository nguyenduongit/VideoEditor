import SwiftUI

/// A dropdown menu control for selecting options (such as aspect ratio).
/// Conforms to R2.4 & R8.1 of AGENTS.md: receives only primitives and closures, uses tokens.
public struct DSRatioSelector: View {
    private let selectedTitle: String
    private let options: [String]
    private let onSelect: (String) -> Void

    public init(
        selectedTitle: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) {
        self.selectedTitle = selectedTitle
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { onSelect(option) }) {
                    if option == selectedTitle {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DSColors.textSecondary)
                Text(selectedTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.inputBorder, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
