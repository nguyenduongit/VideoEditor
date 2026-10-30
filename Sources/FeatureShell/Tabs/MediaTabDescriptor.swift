import SwiftUI
import Domain
import DesignSystem

public struct MediaTabDescriptor: TabDescriptor {
    public let id: TabID = .media
    public let title: String = "Cục bộ"
    public let order: Int = 10

    private let mediaViewModel: MediaLibraryViewModel

    public init(mediaViewModel: MediaLibraryViewModel) {
        self.mediaViewModel = mediaViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(MediaLibraryView(viewModel: mediaViewModel))
    }

    public func makeSidebarTrailingAccessory() -> AnyView? {
        nil
    }
}
