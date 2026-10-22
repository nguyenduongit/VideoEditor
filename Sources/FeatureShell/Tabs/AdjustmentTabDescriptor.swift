import SwiftUI
import Domain
import DesignSystem

public struct AdjustmentTabDescriptor: TabDescriptor {
    public let id: TabID = .adjustment
    public let title: String = "Adjustment"
    public let order: Int = 40

    public init() {}

    public func makeSidebarView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text("Adjustment Layers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text("Nội dung tab Adjustment: Lớp hiệu chỉnh màu sắc, bộ lọc và hiệu ứng toàn cục.")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }
}
