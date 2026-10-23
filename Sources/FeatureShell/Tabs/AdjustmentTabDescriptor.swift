import SwiftUI
import Domain
import DesignSystem

public struct AdjustmentTabDescriptor: TabDescriptor {
    public let id: TabID = .adjustment
    public let title: String = "Adjustment"
    public let order: Int = 40

    private let timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(
            AdjustmentLibraryView(
                viewModel: AdjustmentLibraryViewModel(timelineViewModel: timelineViewModel)
            )
        )
    }
}
