import SwiftUI
import Domain
import DesignSystem

public struct TextTabDescriptor: TabDescriptor {
    public let id: TabID = .text
    public let title: String = "Text"
    public let iconName: String = "textformat"
    public let order: Int = 40

    private let viewModel: TextLibraryViewModel

    @MainActor
    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.viewModel = TextLibraryViewModel(timelineViewModel: timelineViewModel)
    }

    @MainActor
    public func makeSidebarView() -> AnyView {
        AnyView(
            TextLibraryView(
                viewModel: viewModel
            )
        )
    }
}
