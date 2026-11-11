import SwiftUI
import Domain
import DesignSystem

public struct StickerTabDescriptor: TabDescriptor {
    public let id: TabID = .sticker
    public let title: String = "Sticker"
    public let iconName: String = "face.smiling"
    public let isSoon: Bool = false
    public let order: Int = 70

    private let viewModel: StickerLibraryViewModel

    @MainActor
    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.viewModel = StickerLibraryViewModel(timelineViewModel: timelineViewModel)
    }

    @MainActor
    public func makeSidebarView() -> AnyView {
        AnyView(
            StickerLibraryView(
                viewModel: viewModel
            )
        )
    }
}

