import SwiftUI
import Domain
import DesignSystem

public struct EffectTabDescriptor: TabDescriptor {
    public let id: TabID = .effect
    public let title: String = "Effects"
    public let order: Int = 50

    private let timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(
            EffectLibraryView(
                viewModel: EffectLibraryViewModel(timelineViewModel: timelineViewModel)
            )
        )
    }
}
