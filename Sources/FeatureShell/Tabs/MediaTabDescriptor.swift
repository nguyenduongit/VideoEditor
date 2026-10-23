import SwiftUI
import Domain
import DesignSystem

public struct MediaTabDescriptor: TabDescriptor {
    public let id: TabID = .media
    public let title: String = "Media"
    public let order: Int = 10

    private let mediaViewModel: MediaLibraryViewModel

    public init(mediaViewModel: MediaLibraryViewModel) {
        self.mediaViewModel = mediaViewModel
    }

    public func makeSidebarView() -> AnyView {
        AnyView(MediaLibraryView(viewModel: mediaViewModel))
    }

    public func makeSidebarTrailingAccessory() -> AnyView? {
        AnyView(
            Button(action: {
                mediaViewModel.importFiles()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Import (⌘I)")
        )
    }
}
