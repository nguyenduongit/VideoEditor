import SwiftUI

/// Dữ liệu cho 1 nút trong DSSegmentGroup.
public struct DSSegmentItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String?
    public let iconName: String?
    public let isBold: Bool
    public let isItalic: Bool
    public let isUnderlined: Bool
    public let help: String?

    public init(
        id: String,
        title: String? = nil,
        iconName: String? = nil,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        help: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.help = help
    }
}

/// Cụm nút bấm chọn chuẩn (Segmented Button Group) kích thước tiêu chuẩn 28x26pt, bo góc 4pt.
/// Phục vụ cho cả Single-choice (chọn 1) lẫn Multi-toggle (chọn nhiều / bật tắt).
/// Khớp hoàn hảo với giao diện trong Hình 1: Nút vuông bo góc 4pt, active màu xanh Accent.
/// Tuân thủ quy tắc R3.1 (<= 300 dòng, View body <= 80 dòng) và R8.1/R8.2 của AGENTS.md.
public struct DSSegmentGroup: View {
    private let items: [DSSegmentItem]
    private let isSelected: (String) -> Bool
    private let onSelect: (String) -> Void
    private let buttonWidth: CGFloat?
    private let buttonHeight: CGFloat

    public init(
        items: [DSSegmentItem],
        isSelected: @escaping (String) -> Bool,
        onSelect: @escaping (String) -> Void,
        buttonWidth: CGFloat? = 28,
        buttonHeight: CGFloat = 26
    ) {
        self.items = items
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.buttonWidth = buttonWidth
        self.buttonHeight = buttonHeight
    }

    /// Khởi tạo tiện lợi cho Single Selection dùng Binding<String>
    public init(
        items: [DSSegmentItem],
        selectedID: Binding<String>,
        buttonWidth: CGFloat? = 28,
        buttonHeight: CGFloat = 26,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.items = items
        self.isSelected = { $0 == selectedID.wrappedValue }
        self.onSelect = { id in
            selectedID.wrappedValue = id
            onSelect?(id)
        }
        self.buttonWidth = buttonWidth
        self.buttonHeight = buttonHeight
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                buttonView(for: item)
            }
        }
    }

    private func buttonView(for item: DSSegmentItem) -> some View {
        let active = isSelected(item.id)

        return Button(action: { onSelect(item.id) }) {
            ZStack {
                if let icon = item.iconName {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                } else if let title = item.title {
                    Text(title)
                        .font(.system(size: 11, weight: item.isBold ? .bold : .medium))
                        .italic(item.isItalic)
                        .underline(item.isUnderlined)
                }
            }
            .foregroundStyle(active ? Color.white : DSColors.textSecondary)
            .frame(width: buttonWidth, height: buttonHeight)
            .background(active ? DSColors.accent : DSColors.windowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DSColors.blockBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.help ?? (item.title ?? ""))
    }
}

