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
                        if opt.title == selectedTitle || opt.id == selectedTitle {
                            Label(opt.title, systemImage: "checkmark")
                        } else {
                            if let icon = opt.iconName {
                                Label(opt.title, systemImage: icon)
                            } else {
                                Text(opt.title)
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
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
        }
    }
}

/// Nhãn hiển thị của Dropdown Box với phong cách thị giác thống nhất theo thiết kế editor (Image 2 style).
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
        HStack(spacing: 7) {
            if let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(leadingIconColor ?? DSColors.accent)
            }

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 6)

            // Khối badge màu xanh bo góc với chevron.down trắng chuẩn theo ảnh mẫu
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DSColors.accent)
                    .frame(width: 18, height: 18)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? DSColors.accent.opacity(0.8) : DSColors.inputBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}


