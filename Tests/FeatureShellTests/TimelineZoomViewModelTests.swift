import Foundation
import CoreMedia
import Testing
@testable import FeatureShell
@testable import Domain

@MainActor
struct TimelineZoomViewModelTests {
    @Test func testInitialZoom() {
        let viewModel = TimelineViewModel()
        #expect(viewModel.pixelsPerSecond == 60.0)
        #expect(viewModel.zoomPercentageText == "100%")
    }

    @Test func testZoomInAndZoomOut() {
        let viewModel = TimelineViewModel()

        viewModel.zoomIn()
        #expect(viewModel.pixelsPerSecond == 69.0)
        #expect(viewModel.zoomPercentageText == "115%")

        viewModel.zoomOut()
        #expect(viewModel.pixelsPerSecond == 60.0)
        #expect(viewModel.zoomPercentageText == "100%")
    }

    @Test func testResetZoom() {
        let viewModel = TimelineViewModel()
        viewModel.setZoomPixelsPerSecond(300.0)
        #expect(viewModel.pixelsPerSecond == 300.0)
        #expect(viewModel.zoomPercentageText == "500%")

        viewModel.resetZoom()
        #expect(viewModel.pixelsPerSecond == 60.0)
        #expect(viewModel.zoomPercentageText == "100%")
    }

    @Test func testApplyZoomDelta() {
        let viewModel = TimelineViewModel()
        let initial = viewModel.pixelsPerSecond

        viewModel.applyZoomDelta(10.0)
        #expect(viewModel.pixelsPerSecond > initial)

        viewModel.applyZoomDelta(-15.0)
        #expect(viewModel.pixelsPerSecond < 100.0)
    }

    @Test func testSetZoomPixelsPerSecondClamping() {
        let viewModel = TimelineViewModel()

        viewModel.setZoomPixelsPerSecond(150.0)
        #expect(viewModel.pixelsPerSecond == 150.0)

        viewModel.setZoomPixelsPerSecond(9999.0)
        #expect(viewModel.pixelsPerSecond == 960.0)

        viewModel.setZoomPixelsPerSecond(-50.0)
        #expect(viewModel.pixelsPerSecond == 15.0)
    }

    @Test func testResetZoomWithClipsFitsTimelineWithPadding() {
        let clip = TimelineClip(
            name: "Video Clip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 20, timescale: 1))
        )
        let layer = TimelineLayer(name: "Layer 1", kind: .video, clips: [clip])
        let viewModel = TimelineViewModel(initialLayers: [layer])
        viewModel.updateViewportWidth(1100.0)

        viewModel.resetZoom()

        // 1100 - 100 padding = 1000pt / 20s = 50 px/s
        #expect(viewModel.pixelsPerSecond == 50.0)
        #expect(viewModel.zoomPercentageText == "100%")
        #expect(viewModel.contentWidth == 1100.0)
    }

    @Test func testLongVideoFitsWithout25PercentBlock() {
        // Video is 140s (> 2 minutes). Viewport is 1100pt.
        let clip = TimelineClip(
            name: "Long Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 140, timescale: 1))
        )
        let layer = TimelineLayer(name: "Layer 1", kind: .video, clips: [clip])
        let viewModel = TimelineViewModel(initialLayers: [layer])
        viewModel.updateViewportWidth(1100.0)

        viewModel.resetZoom()

        // Available width = 1000pt / 140s ≈ 7.14 px/s
        #expect(viewModel.pixelsPerSecond < 10.0)
        #expect(viewModel.zoomPercentageText == "100%")
        #expect(abs(viewModel.contentWidth - 1100.0) < 1.0)

        // 25% minimum limit is 25% of the 100% base
        #expect(viewModel.minPixelsPerSecond == viewModel.basePixelsPerSecond * 0.25)
        viewModel.setZoomPixelsPerSecond(viewModel.minPixelsPerSecond)
        #expect(viewModel.zoomPercentageText == "25%")
    }

    @Test func testAddAssetDefaultsTo100Percent() {
        let viewModel = TimelineViewModel()
        viewModel.updateViewportWidth(1100.0)

        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let asset = MediaAsset(url: url, name: "Test Video", type: .video)
        viewModel.addAsset(asset)

        #expect(viewModel.zoomPercentageText == "100%")
        #expect(viewModel.pixelsPerSecond == viewModel.basePixelsPerSecond)
    }
}
