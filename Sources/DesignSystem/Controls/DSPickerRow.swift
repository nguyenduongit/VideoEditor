import SwiftUI

/// Option item passed to `DSPickerRow`.
public struct DSPickerOption: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let iconName: String?

    public init(id: String, title: String, iconName: String? = nil) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

/// A segmented picker row for selecting one option among a group (e.g. mask type).
/// Complies with R2.4, R8.1, and R8.5 of AGENTS.md.
public struct DSPickerRow: View {
    private let title: String
    @Binding private var selectedID: String
    private let options: [DSPickerOption]
    private let onSelect: ((String) -> Void)?

    public init(
        title: String,
        selectedID: Binding<String>,
        options: [DSPickerOption],
        onSelect: ((String) -> Void)? = nil
    ) {
        self.title = title
        self._selectedID = selectedID
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)

            HStack(spacing: 2) {
                ForEach(options) { opt in
                    pickerButton(for: opt)
                }
            }
            .padding(2)
            .background(DSColors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColors.inputBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func pickerButton(for opt: DSPickerOption) -> some View {
        let isSelected = (opt.id == selectedID)
        Button {
            selectedID = opt.id
            onSelect?(opt.id)
        } label: {
            VStack(spacing: 2) {
                if let icon = opt.iconName {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                }
                Text(opt.title)
                    .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.small - 1)
                    .fill(isSelected ? DSColors.activeTabBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small - 1)
                    .stroke(isSelected ? DSColors.toggleCyan.opacity(0.8) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(opt.title)
    }
}
