import SwiftUI

/// Collapsible property group section with disclosure chevron and reset button.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSCollapsibleSection<Content: View>: View {
    private let title: String
    private let onReset: (() -> Void)?
    private let content: () -> Content

    @State private var isExpanded: Bool = true
    @State private var isHoveredReset = false

    public init(
        title: String,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onReset = onReset
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            headerRow

            if isExpanded {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    content()
                }
                .padding(.top, DSSpacing.xxs)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: DSSpacing.sm) {
            titleToggleArea

            Spacer()

            if let onReset {
                resetButton(action: onReset)
            }
        }
        .frame(height: 24)
    }

    private var titleToggleArea: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: DSSpacing.xs) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DSColors.textPrimary)

                Image(systemName: isExpanded ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(DSColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func resetButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHoveredReset ? DSColors.textPrimary : DSColors.textSecondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHoveredReset = $0 }
    }
}
