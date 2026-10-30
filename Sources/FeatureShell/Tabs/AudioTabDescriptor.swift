import SwiftUI
import Domain
import DesignSystem

public struct AudioTabDescriptor: TabDescriptor {
    public let id: TabID = .audio
    public let title: String = "Audio"
    public let order: Int = 20

    public init() {}

    public func makeSidebarView() -> AnyView {
        AnyView(
            LibraryScaffoldView(
                searchPlaceholder: "Tìm kiếm âm thanh, SFX..."
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text(String(localized: "Audio Library"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DSColors.textPrimary)
                    Text(String(localized: "Nội dung tab Audio: Danh sách hiệu ứng âm thanh, nhạc nền và voiceover."))
                        .font(.system(size: 12))
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer()
                }
                .padding(DSSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        )
    }
}
