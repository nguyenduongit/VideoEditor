import SwiftUI

/// Standard DesignSystem section header for dividing property groups.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSSectionHeader: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
        }
        .padding(.top, DSSpacing.sm)
        .padding(.bottom, DSSpacing.xs)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
    }
}
