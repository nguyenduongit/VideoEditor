import SwiftUI

/// Container thẻ Section đồng bộ cho toàn bộ Right Sidebar (Inspector).
/// Thay thế hoàn toàn Accordion gấp mở, mang lại bố cục vững chãi, gọn gàng và phẳng.
/// Tuân thủ quy tắc R3.1 (<= 300 dòng, View body <= 80 dòng) và R8.1/R8.2 của AGENTS.md.
public struct DSSectionCard<Content: View>: View {
    private let title: String?
    private let trailingAccessory: AnyView?
    private let onReset: (() -> Void)?
    private let content: () -> Content

    @State private var isHoveredReset = false

    public init(
        title: String? = nil,
        trailingAccessory: AnyView? = nil,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailingAccessory = trailingAccessory
        self.onReset = onReset
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            if hasHeader {
                headerRow
            }
            content()
        }
        .padding(DSSpacing.sm)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var hasHeader: Bool {
        title != nil || onReset != nil || trailingAccessory != nil
    }

    private var headerRow: some View {
        HStack(spacing: DSSpacing.sm) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)
            }

            Spacer()

            if let onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isHoveredReset ? DSColors.textPrimary : DSColors.textSecondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isHoveredReset = $0 }
                .help(String(localized: "Khôi phục mặc định"))
            }

            if let trailingAccessory {
                trailingAccessory
            }
        }
        .frame(height: 18)
    }
}

