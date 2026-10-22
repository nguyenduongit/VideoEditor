import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

private struct MockThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        nil
    }
}

struct MediaLibraryViewModelTests {
    @Test @MainActor func testImportValidAndInvalidFiles() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let urls = [
            URL(fileURLWithPath: "/tmp/clip.mp4"),
            URL(fileURLWithPath: "/tmp/song.mp3"),
            URL(fileURLWithPath: "/tmp/cover.png"),
            URL(fileURLWithPath: "/tmp/notes.pdf")
        ]

        vm.importURLs(urls)

        #expect(vm.assets.count == 3)
        #expect(vm.assets[0].type == .video)
        #expect(vm.assets[1].type == .audio)
        #expect(vm.assets[2].type == .image)
    }

    @Test @MainActor func testSingleAndMultiSelection() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        vm.assets = [
            MediaAsset(id: id1, url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video),
            MediaAsset(id: id2, url: URL(fileURLWithPath: "/tmp/2.mp4"), type: .video),
            MediaAsset(id: id3, url: URL(fileURLWithPath: "/tmp/3.mp4"), type: .video)
        ]

        // Single select without Cmd
        vm.toggleSelection(for: id1, isCmdPressed: false)
        #expect(vm.selectedAssetIDs == [id1])

        // Single select another item without Cmd clears previous
        vm.toggleSelection(for: id2, isCmdPressed: false)
        #expect(vm.selectedAssetIDs == [id2])

        // Cmd + Click adds to selection
        vm.toggleSelection(for: id3, isCmdPressed: true)
        #expect(vm.selectedAssetIDs == [id2, id3])

        // Cmd + Click on selected item removes it
        vm.toggleSelection(for: id2, isCmdPressed: true)
        #expect(vm.selectedAssetIDs == [id3])
    }

    @Test @MainActor func testDeleteSelected() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let id1 = UUID()
        let id2 = UUID()
        vm.assets = [
            MediaAsset(id: id1, url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video),
            MediaAsset(id: id2, url: URL(fileURLWithPath: "/tmp/2.mp4"), type: .video)
        ]

        var deleted: [MediaAsset] = []
        vm.onAssetsDeleted = { assets in
            deleted = assets
        }

        vm.toggleSelection(for: id1, isCmdPressed: false)
        vm.deleteSelected()

        #expect(vm.assets.count == 1)
        #expect(vm.assets[0].id == id2)
        #expect(vm.selectedAssetIDs.isEmpty)
        #expect(deleted.count == 1)
        #expect(deleted.first?.id == id1)
    }

    @Test @MainActor func testDragSelection() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let id1 = UUID()
        let id2 = UUID()
        vm.assets = [
            MediaAsset(id: id1, url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video),
            MediaAsset(id: id2, url: URL(fileURLWithPath: "/tmp/2.mp4"), type: .video)
        ]

        let frames: [UUID: CGRect] = [
            id1: CGRect(x: 10, y: 10, width: 100, height: 100),
            id2: CGRect(x: 150, y: 10, width: 100, height: 100)
        ]

        // Drag rectangle covering only item 1
        let rect1 = CGRect(x: 0, y: 0, width: 120, height: 120)
        vm.updateDragSelection(rect: rect1, itemFrames: frames)
        #expect(vm.selectedAssetIDs == [id1])

        // Drag rectangle covering both items
        let rectBoth = CGRect(x: 0, y: 0, width: 300, height: 120)
        vm.updateDragSelection(rect: rectBoth, itemFrames: frames)
        #expect(vm.selectedAssetIDs == [id1, id2])
    }

    @Test @MainActor func testDeleteSelectedAndUndoRedo() {
        let vm = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let id1 = UUID()
        let asset1 = MediaAsset(id: id1, url: URL(fileURLWithPath: "/tmp/1.mp4"), type: .video)
        vm.assets = [asset1]

        vm.toggleSelection(for: id1, isCmdPressed: false)
        vm.deleteSelected()
        #expect(vm.assets.isEmpty)
        #expect(vm.canUndo)

        // Undo restores asset
        let didUndo = vm.undo()
        #expect(didUndo)
        #expect(vm.assets.count == 1)
        #expect(vm.assets.first?.id == id1)
        #expect(vm.canRedo)

        // Redo removes asset again
        let didRedo = vm.redo()
        #expect(didRedo)
        #expect(vm.assets.isEmpty)
    }

    @Test @MainActor func testDeleteAssetWithTimelineClipsFullUndoRedo() {
        let mediaVM = MediaLibraryViewModel(thumbnailService: MockThumbnailService())
        let timelineVM = TimelineViewModel()
        let assetID = UUID()
        let asset = MediaAsset(id: assetID, url: URL(fileURLWithPath: "/tmp/clip.mp4"), type: .video)
        mediaVM.assets = [asset]

        // Wire undo/redo and callbacks like AppMain
        mediaVM.onAssetsDeleted = { deleted in
            let ids = Set(deleted.map(\.id))
            let urls = Set(deleted.map(\.url))
            timelineVM.removeClips(forAssetIDs: ids, urls: urls)
        }
        mediaVM.onUndoRequested = { [weak timelineVM] in
            timelineVM?.undo() ?? false
        }
        timelineVM.onClipsRestored = { [weak mediaVM] restoredClips in
            mediaVM?.restoreAssetsForClips(restoredClips)
        }

        // Add clip to timeline
        let clip = TimelineClip(
            assetID: asset.id,
            name: "Test",
            kind: .video,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            mediaURL: asset.url
        )
        timelineVM.addClip(clip)
        #expect(timelineVM.layers.first?.clips.count == 1)

        // Delete asset in media library
        mediaVM.toggleSelection(for: assetID, isCmdPressed: false)
        mediaVM.deleteSelected()

        #expect(mediaVM.assets.isEmpty)
        #expect(timelineVM.layers.first?.clips.isEmpty ?? true)

        // Undo restores clip in timeline AND restores asset in media library
        let undoResult = mediaVM.undo()
        #expect(undoResult)
        #expect(timelineVM.layers.first?.clips.count == 1)
        #expect(mediaVM.assets.count == 1)
        #expect(mediaVM.assets.first?.id == assetID)
    }
}

