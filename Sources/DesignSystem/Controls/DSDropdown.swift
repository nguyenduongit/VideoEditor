import SwiftUI

/// Option item passed to `DSDropdown`.
public struct DSDropdownOption: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let iconName: String?

    public init(id: String, title: String, iconName: String? = nil) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

/// Control Dropdown Box chuẩn DesignSystem, thống nhất 1 kiểu giao diện toàn ứng dụng.
/// Thiết kế chuẩn dark editor: chiều cao 24pt, nền windowBackground, viền blockBorder,
/// text 12pt, icon chevron.up.chevron.down đôi bên phải, có hiệu ứng hover mượt mà.
/// Tuân thủ AGENTS.md R2.4 (DesignSystem độc lập, chỉ nhận primitives và closures) và R3.1 (File <= 300 dòng).
public struct DSDropdown: View {
    private let title: String?
    private let selectedTitle: String
    private let leadingIcon: String?
    private let leadingIconColor: Color?
    private let options: [DSDropdownOption]
    private let width: CGFloat?
    private let onSelect: (String) -> Void

    @State private var isHovered: Bool = false

    public init(
        title: String? = nil,
        selectedTitle: String,
        leadingIcon: String? = nil,
        leadingIconColor: Color? = nil,
        options: [DSDropdownOption],
        width: CGFloat? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.selectedTitle = selectedTitle
        self.leadingIcon = leadingIcon
        self.leadingIconColor = leadingIconColor
        self.options = options
        self.width = width
        self.onSelect = onSelect
    }

    public init(
        title: String? = nil,
        selection: Binding<String>,
        options: [DSDropdownOption],
        leadingIcon: String? = nil,
        leadingIconColor: Color? = nil,
        width: CGFloat? = nil
    ) {
        let currentID = selection.wrappedValue
        let currentTitle = options.first(where: { $0.id == currentID })?.title ?? currentID
        self.init(
            title: title,
            selectedTitle: currentTitle,
            leadingIcon: leadingIcon,
            leadingIconColor: leadingIconColor,
            options: options,
            width: width,
            onSelect: { selection.wrappedValue = $0 }
        )
    }

    public init<T: CaseIterable & Hashable>(
        title: String? = nil,
        selection: Binding<T>,
        titleKeyPath: KeyPath<T, String>,
        leadingIcon: String? = nil,
        leadingIconColor: Color? = nil,
        width: CGFloat? = nil
    ) where T.AllCases: RandomAccessCollection {
        let all = Array(T.allCases)
        let current = selection.wrappedValue
        let opts = all.map { DSDropdownOption(id: "\($0.hashValue)", title: $0[keyPath: titleKeyPath]) }
        let currentTitle = current[keyPath: titleKeyPath]
        self.init(
            title: title,
            selectedTitle: currentTitle,
            leadingIcon: leadingIcon,
            leadingIconColor: leadingIconColor,
            options: opts,
            width: width,
            onSelect: { selectedHash in
                if let matched = all.first(where: { "\($0.hashValue)" == selectedHash }) {
                    selection.wrappedValue = matched
                }
            }
        )
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }

            Menu {
                ForEach(options) { opt in
                    Button(action: { onSelect(opt.id) }) {
                        HStack {
                            if let icon = opt.iconName {
                                Image(systemName: icon)
                            }
                            Text(opt.title)
                            if opt.title == selectedTitle || opt.id == selectedTitle {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                DSDropdownBoxLabel(
                    title: selectedTitle,
                    leadingIcon: leadingIcon,
                    leadingIconColor: leadingIconColor,
                    isHovered: isHovered
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .frame(width: width)
            .fixedSize(horizontal: width != nil, vertical: true)
        }
    }
}

/// Nhãn hiển thị của Dropdown Box với phong cách thị giác thống nhất theo thiết kế editor.
public struct DSDropdownBoxLabel: View {
    private let title: String
    private let leadingIcon: String?
    private let leadingIconColor: Color?
    private let isHovered: Bool

    public init(
        title: String,
        leadingIcon: String? = nil,
        leadingIconColor: Color? = nil,
        isHovered: Bool = false
    ) {
        self.title = title
        self.leadingIcon = leadingIcon
        self.leadingIconColor = leadingIconColor
        self.isHovered = isHovered
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(leadingIconColor ?? DSColors.textSecondary)
            }

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            dropdownIndicator
        }
        .padding(.leading, 8)
        .padding(.trailing, 2)
        .frame(height: 24)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(isHovered ? DSColors.textSecondary.opacity(0.6) : DSColors.blockBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var dropdownIndicator: some View {
        VStack(spacing: 1) {
            Image(systemName: "chevron.up")
                .font(.system(size: 7, weight: .bold))
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(isHovered ? DSColors.textPrimary : DSColors.textSecondary)
        .frame(width: 18, height: 20)
        .background(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3.5))
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

