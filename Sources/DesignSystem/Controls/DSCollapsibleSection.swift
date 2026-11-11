import SwiftUI

/// Section Card cho thuộc tính Inspector, tương thích ngược với DSCollapsibleSection.
/// Đã được chuyển đổi hoàn toàn sang kiến trúc Section Card phẳng không gập mở theo yêu cầu AAS.
/// Tuân thủ quy tắc R3.1 (<= 300 dòng, View body <= 80 dòng) và R8.1/R8.2 của AGENTS.md.
public struct DSCollapsibleSection<Content: View>: View {
    private let title: String
    private let trailingAccessory: AnyView?
    private let onReset: (() -> Void)?
    private let content: () -> Content

    public init(
        title: String,
        defaultExpanded: Bool = true,
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
        DSSectionCard(
            title: title,
            trailingAccessory: trailingAccessory,
            onReset: onReset,
            content: content
        )
    }
}
