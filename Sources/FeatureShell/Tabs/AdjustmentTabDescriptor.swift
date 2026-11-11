import SwiftUI
import Domain
import DesignSystem

public struct AdjustmentTabDescriptor: TabDescriptor {
    public let id: TabID = .adjustment
    public let title: String = "Adjustment"
    public let iconName: String = "slider.horizontal.3"
    public let order: Int = 30

    private let viewModel: AdjustmentLibraryViewModel

    @MainActor
    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.viewModel = AdjustmentLibraryViewModel(timelineViewModel: timelineViewModel)
    }

    @MainActor
    public func makeSidebarView() -> AnyView {
        AnyView(
            AdjustmentLibraryView(
                viewModel: viewModel
            )
        )
    }
}
