import SwiftUI
import Domain
import DesignSystem

public struct EffectTabDescriptor: TabDescriptor {
    public let id: TabID = .effect
    public let title: String = "Effect"
    public let iconName: String = "sparkles"
    public let order: Int = 50

    private let viewModel: EffectLibraryViewModel

    @MainActor
    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.viewModel = EffectLibraryViewModel(timelineViewModel: timelineViewModel)
    }

    @MainActor
    public func makeSidebarView() -> AnyView {
        AnyView(
            EffectLibraryView(
                viewModel: viewModel
            )
        )
    }
}
