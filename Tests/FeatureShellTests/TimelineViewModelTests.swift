import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

struct TimelineViewModelTests {
    @Test @MainActor func testLayerToggles() {
        let vm = TimelineViewModel()
        let layer = vm.createLayer(for: .video)
        let layerID = layer.id

        vm.toggleLock(for: layerID)
        #expect(vm.layers[0].isLocked == true)

        vm.toggleHide(for: layerID)
        #expect(vm.layers[0].isHidden == true)

        vm.toggleMute(for: layerID)
        #expect(vm.layers[0].isMuted == true)
    }

    @Test @MainActor func testMoveClipAutoCreatesLayerWhenDroppedBetween() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer0 = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        vm.addClip(clip, to: layer0.id)
        #expect(vm.layers.count == 1)

        vm.moveClip(
            clipID: clip.id,
            from: layer0.id,
            to: nil,
            insertAtIndex: 1,
            newStartTime: CMTime(value: 2, timescale: 1)
        )

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].timeRange.start == CMTime(value: 2, timescale: 1))
    }

    @Test @MainActor func testMoveClipRetainsNonEmptySourceLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer0 = vm.createLayer(for: .video)
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 6, timescale: 1), duration: CMTime(value: 3, timescale: 1))
        )
        vm.addClip(clip1, to: layer0.id)
        vm.addClip(clip2, to: layer0.id)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 2)

        vm.moveClip(
            clipID: clip1.id,
            from: layer0.id,
            to: nil,
            insertAtIndex: 0,
            newStartTime: CMTime(value: 1, timescale: 1)
        )

        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].id == clip1.id)
        #expect(vm.layers[1].clips.count == 1)
        #expect(vm.layers[1].clips[0].id == clip2.id)
    }

    @Test @MainActor func testLayerHeights() {
        let vm = TimelineViewModel()
        #expect(vm.layerHeight(for: .video) == 80.0)
        #expect(vm.layerHeight(for: .audio) == 60.0)
        #expect(vm.layerHeight(for: .image) == 60.0)
        #expect(vm.layerHeight(for: .text) == 30.0)
        #expect(vm.layerHeight(for: .adjustment) == 30.0)
    }

    @Test @MainActor func testBottomUpLayerOrdering() {
        let vm = TimelineViewModel(initialLayers: [])
        let bottomLayer = vm.createLayer(for: .audio)
        let topLayer = vm.createLayer(for: .video)

        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].id == topLayer.id)
        #expect(vm.layers[1].id == bottomLayer.id)
    }

    @Test @MainActor func testTrimClip() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Test",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 8, timescale: 1)),
            maxDuration: CMTime(value: 12, timescale: 1)
        )
        vm.addClip(clip, to: layer.id)

        let newStart = CMTime(value: 2, timescale: 1)
        let newDuration = CMTime(value: 5, timescale: 1)
        vm.trimClip(clipID: clip.id, in: layer.id, newStart: newStart, newDuration: newDuration)

        #expect(vm.layers[0].clips[0].timeRange.start == newStart)
        #expect(vm.layers[0].clips[0].timeRange.duration == newDuration)
    }

    @Test @MainActor func testContentWidthCalculation() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Wide",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 30, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)

        #expect(vm.contentWidth == 1900.0)
    }

    @Test @MainActor func testClipSelection() {
        let vm = TimelineViewModel()
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(name: "C1", kind: .video, timeRange: .zero)
        vm.addClip(clip, to: layer.id)
        let clipID = clip.id

        #expect(vm.selectedClipID == nil)
        vm.selectClip(clipID)
        #expect(vm.selectedClipID == clipID)
        vm.selectClip(nil)
        #expect(vm.selectedClipID == nil)
    }

    @Test @MainActor func testUpdateDropTarget() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer0 = vm.createLayer(for: .video)
        _ = vm.createLayer(for: .video)
        #expect(vm.layers.count == 2)

        vm.updateDropTarget(sourceIndex: 1, movingClipKind: .video, dragY: 0)
        #expect(vm.hoverLayerID == layer0.id)
        #expect(vm.dropBetweenIndex == nil)

        vm.updateDropTarget(sourceIndex: 1, movingClipKind: .video, dragY: 45)
        #expect(vm.hoverLayerID == nil)
        #expect(vm.dropBetweenIndex != nil)
    }

    @Test @MainActor func testAddAssetDefaultTierOrdering() {
        let vm = TimelineViewModel()
        #expect(vm.layers.isEmpty)

        // Add audio asset
        let audioAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sound.mp3"), type: .audio)
        vm.addAsset(audioAsset)

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].kind == .audio)

        // Add video asset -> video MUST be above audio
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/movie.mp4"), type: .video)
        vm.addAsset(videoAsset)

        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].kind == .video)
        #expect(vm.layers[1].kind == .audio)

        // Add image asset -> image must be above video
        let imageAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/banner.png"), type: .image)
        vm.addAsset(imageAsset)

        #expect(vm.layers.count == 3)
        #expect(vm.layers[0].kind == .image)
        #expect(vm.layers[1].kind == .video)
        #expect(vm.layers[2].kind == .audio)
    }

    @Test @MainActor func testAddAssetPlacesInSameLayerWhenNoOverlap() {
        let vm = TimelineViewModel()
        let videoAsset1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v1.mp4"), type: .video)
        let videoAsset2 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v2.mp4"), type: .video)

        vm.addAsset(videoAsset1, at: .zero)
        #expect(vm.layers.count == 1)

        let t10 = CMTime(value: 10 * 30, timescale: 30)
        vm.addAsset(videoAsset2, at: t10)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 2)
    }

    @Test @MainActor func testAddAssetCreatesNewLayerWhenOverlapping() {
        let vm = TimelineViewModel()
        let videoAsset1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v1.mp4"), type: .video)
        let videoAsset2 = MediaAsset(url: URL(fileURLWithPath: "/tmp/v2.mp4"), type: .video)

        vm.addAsset(videoAsset1, at: .zero)
        vm.addAsset(videoAsset2, at: .zero)

        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].kind == .video)
        #expect(vm.layers[1].kind == .video)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[1].clips.count == 1)
    }

    @Test @MainActor func testRemoveClipsForAssetIDsAndUrls() {
        let vm = TimelineViewModel()
        let assetID1 = UUID()
        let assetID2 = UUID()
        let url1 = URL(fileURLWithPath: "/tmp/a1.mp3")
        let url2 = URL(fileURLWithPath: "/tmp/v1.mp4")

        let asset1 = MediaAsset(id: assetID1, url: url1, type: .audio)
        let asset2 = MediaAsset(id: assetID2, url: url2, type: .video)

        vm.addAsset(asset1)
        vm.addAsset(asset2)
        #expect(vm.layers.count == 2)

        let clip1ID = vm.layers.first(where: { $0.kind == .audio })?.clips.first?.id
        vm.selectClip(clip1ID)
        #expect(vm.selectedClipID == clip1ID)

        // Remove audio asset by ID
        vm.removeClips(forAssetIDs: [assetID1], urls: [url1])

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].kind == .video)
        #expect(vm.selectedClipID == nil)

        // Remove video asset by url fallback
        vm.removeClips(forAssetIDs: [], urls: [url2])
        #expect(vm.layers.isEmpty)
    }

    @Test @MainActor func testTrimClipAfterUnsortedInsertionDoesNotBlock() {
        let vm = TimelineViewModel()
        let clip10s = TimelineClip(
            name: "Clip10",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 10.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600))
        )
        let clip2s = TimelineClip(
            name: "Clip2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600))
        )

        let layer = TimelineLayer(kind: .video, clips: [clip10s, clip2s])
        vm.layers = [layer]

        let newStart = CMTime(seconds: 1.0, preferredTimescale: 600)
        let newDuration = CMTime(seconds: 5.0, preferredTimescale: 600)

        vm.trimClip(
            clipID: clip2s.id,
            in: layer.id,
            newStart: newStart,
            newDuration: newDuration
        )

        let updatedClips = vm.layers[0].clips
        #expect(updatedClips.count == 2)
        #expect(updatedClips[0].id == clip2s.id)
        #expect(updatedClips[0].timeRange.start == newStart)
        #expect(updatedClips[1].id == clip10s.id)
    }
}

