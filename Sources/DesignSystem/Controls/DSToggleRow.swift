import SwiftUI

/// Standard row with label in column 1 and modern cyan switch toggle in column 4.
/// Complies with R8.1 and R8.2 of AGENTS.md.
public struct DSToggleRow: View {
    private let title: String
    @Binding private var isOn: Bool
    private let onChange: ((Bool) -> Void)?

    public init(
        title: String,
        isOn: Binding<Bool>,
        onChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._isOn = isOn
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: DSSize.inspectorColumnSpacing) {
            // Label in Column 1
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .frame(width: DSSize.inspectorColumnWidth, alignment: .leading)

            Spacer()

            // Toggle switch aligned in Column 4
            toggleSwitch
                .frame(width: DSSize.inspectorColumnWidth, alignment: .trailing)
        }
        .frame(height: 28)
    }

    private var toggleSwitch: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                isOn.toggle()
                onChange?(isOn)
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? DSColors.toggleCyan : Color.white.opacity(0.16))
                    .frame(width: 36, height: 20)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
