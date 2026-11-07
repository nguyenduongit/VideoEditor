import SwiftUI
import Domain
import DesignSystem

public struct AdjustmentTabDescriptor: TabDescriptor {
    public let id: TabID = .adjustment
    public let title: String = "Adjustment"
    public let iconName: String = "slider.horizontal.3"
    public let order: Int = 30

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
