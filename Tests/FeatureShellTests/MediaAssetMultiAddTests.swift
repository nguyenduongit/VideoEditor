import Foundation
import CoreMedia
import AppKit
import Testing
import Domain
@testable import FeatureShell

private struct MockThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        nil
    }
}

@Suite("MediaAssetMultiAddTests")
@MainActor
struct MediaAssetMultiAddTests {

    @Test func testMediaLibraryViewModelMultiItemAddCallback() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let a1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v1.mp4"), type: .video)
        let a2 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v2.mp4"), type: .video)
        let a3 = MediaAsset(url: URL(fileURLWithPath: "/tmp/a1.mp3"), type: .audio)
        vm.assets = [a1, a2, a3]

        var batchAdded: [MediaAsset] = []
        vm.onAddAssetsToTimeline = { assets in
            batchAdded = assets
        }

        // Single item click without multi-selection
        var singleAdded: MediaAsset?
        vm.onAddAssetToTimeline = { singleAdded = $0 }
        vm.addAssetToTimeline(a1)
        #expect(singleAdded?.id == a1.id)
        #expect(batchAdded.isEmpty)

        // Select a1 and a3
        vm.selectedAssetIDs = [a1.id, a3.id]
        vm.addAssetToTimeline(a1)
        #expect(batchAdded.count == 2)
        #expect(batchAdded.map(\.id) == [a1.id, a3.id])
    }

    @Test func testTimelineViewModelAddAssetsAutoLayersAndUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let v1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/video1.mp4"), type: .video)
        let v2 = MediaAsset(url: URL(fileURLWithPath: "/tmp/video2.mp4"), type: .video)
        let a1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/audio1.mp3"), type: .audio)

        // Add all 3 assets at time = 0
        vm.addAssets([v1, v2, a1], at: .zero)

        // There should be 2 video layers (v1 and v2 cannot share layer 0 at time 0) and 1 audio layer
        let videoLayers = vm.layers.filter { $0.kind == .video }
        let audioLayers = vm.layers.filter { $0.kind == .audio }

        #expect(videoLayers.count == 2)
        #expect(audioLayers.count == 1)

        #expect(videoLayers[0].clips.count == 1)
        #expect(videoLayers[1].clips.count == 1)
        #expect(audioLayers[0].clips.count == 1)

        // All 3 added clips are selected
        #expect(vm.selectedClipIDs.count == 3)
        #expect(vm.canUndo)

        // Undo removes all 3 clips
        vm.undo()
        let totalClipsAfterUndo = vm.layers.reduce(0) { $0 + $1.clips.count }
        #expect(totalClipsAfterUndo == 0)
        #expect(vm.canRedo)

        // Redo restores all 3 clips
        vm.redo()
        let totalClipsAfterRedo = vm.layers.reduce(0) { $0 + $1.clips.count }
        #expect(totalClipsAfterRedo == 3)
    }

    @Test func testMediaAssetDragSourceNSViewHoverCallbacks() {
        let view = MediaAssetDragSourceNSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        var hoverState: Bool?
        view.onHover = { hoverState = $0 }

        let dummyEvent = NSEvent()
        view.mouseEntered(with: dummyEvent)
        #expect(hoverState == true)

        view.mouseExited(with: dummyEvent)
        #expect(hoverState == false)
    }
}
