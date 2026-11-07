import SwiftUI
import Domain
import DesignSystem

public struct TextTabDescriptor: TabDescriptor {
    public let id: TabID = .text
    public let title: String = "Text"
    public let iconName: String = "textformat"
    public let order: Int = 40

    private let timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(
            TextLibraryView(
                viewModel: TextLibraryViewModel(timelineViewModel: timelineViewModel)
            )
        )
    }
}
