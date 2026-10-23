import SwiftUI

/// A dropdown menu control for selecting options (such as aspect ratio).
/// Conforms to R2.4 & R8.1 of AGENTS.md: receives only primitives and closures, uses tokens.
public struct DSRatioSelector: View {
    private let selectedTitle: String
    private let options: [String]
    private let onSelect: (String) -> Void
    @State private var isHovered = false

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
            HStack(spacing: 6) {
                Image(systemName: "aspectratio")
                    .renderingMode(.template)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                Text(selectedTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                Image(systemName: "chevron.down")
                    .renderingMode(.template)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .preferredColorScheme(.dark)
        .fixedSize()
    }
}
