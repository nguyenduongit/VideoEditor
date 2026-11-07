import SwiftUI
import Domain
import DesignSystem

public struct TransitionTabDescriptor: TabDescriptor {
    public let id: TabID = .transition
    public let title: String = "Transition"
    public let iconName: String = "arrow.left.arrow.right"
    public let isSoon: Bool = false
    public let order: Int = 60

    private let timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(
            TransitionLibraryView(
                viewModel: TransitionLibraryViewModel(timelineViewModel: timelineViewModel)
            )
        )
    }
}

