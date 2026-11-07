import SwiftUI
import Domain
import DesignSystem

public struct AudioTabDescriptor: TabDescriptor {
    public let id: TabID = .audio
    public let title: String = "Audio"
    public let iconName: String = "waveform"
    public let order: Int = 20
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(AudioSidebarView(timelineViewModel: timelineViewModel))
    }
}
