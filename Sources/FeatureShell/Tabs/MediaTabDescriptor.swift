import SwiftUI
import Domain
import DesignSystem

public struct MediaTabDescriptor: TabDescriptor {
    public let id: TabID = .media
    public let title: String = "Media"
    public let iconName: String = "photo.on.rectangle"
    public let order: Int = 10

    private let mediaViewModel: MediaLibraryViewModel
    private let dependencies: EditorDependencies?

    public init(mediaViewModel: MediaLibraryViewModel, dependencies: EditorDependencies? = nil) {
        self.mediaViewModel = mediaViewModel
        self.dependencies = dependencies
    }

    public func makeSidebarView() -> AnyView {
        AnyView(MediaLibraryView(viewModel: mediaViewModel, dependencies: dependencies))
    }

    public func makeSidebarTrailingAccessory() -> AnyView? {
        nil
    }
}
