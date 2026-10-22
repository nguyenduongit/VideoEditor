import SwiftUI
import Domain
import DesignSystem

public struct TextTabDescriptor: TabDescriptor {
    public let id: TabID = .text
    public let title: String = "Text"
    public let order: Int = 30

    public init() {}

    public func makeSidebarView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("Text Titles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text("Nội dung tab Text: Các mẫu phụ đề, tiêu đề đồ họa và kiểu chữ.")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }
}
