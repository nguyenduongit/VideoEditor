import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct LibraryTabDescriptor: TabDescriptor {
    public let id: TabID = .library
    public let title: String = "Thư viện"
    public let order: Int = 15

    private let timelineViewModel: TimelineViewModel?
    private let mediaViewModel: MediaLibraryViewModel?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        mediaViewModel: MediaLibraryViewModel? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        self.mediaViewModel = mediaViewModel
    }

    public func makeSidebarView() -> AnyView {
        let viewModel = StockLibraryViewModel()
        viewModel.onAddStockItem = { [weak timelineViewModel] item in
            guard let timelineViewModel else { return }
            let durationSeconds = item.duration ?? 5.0
            let duration = CMTime(
                value: Int64(durationSeconds * Double(TimeRational.defaultFPS)),
                timescale: TimeRational.defaultFPS
            )
            let isProceduralSolid = item.mediaType == "solid_color" || item.id == "stock_black_screen"
            var properties = BuiltInClipPropertyDefaults.properties(for: .video)
            let mediaURL: URL?

            if isProceduralSolid {
                properties["isProcedural"] = .bool(true)
                properties["isSolidColor"] = .bool(true)
                properties["solidColorHex"] = .string("#000000")
                mediaURL = ProceduralAssetProvider.shared.blackVideoURL()
            } else {
                mediaURL = item.previewURL.flatMap { URL(string: $0) }
            }

            let clip = TimelineClip(
                name: item.title,
                kind: item.mediaType == "audio" ? .audio : .video,
                timeRange: CMTimeRange(start: timelineViewModel.currentTime, duration: duration),
                maxDuration: nil,
                mediaURL: mediaURL,
                properties: properties
            )
            timelineViewModel.addClip(clip)
        }
        return AnyView(StockLibraryView(viewModel: viewModel))
    }
}
