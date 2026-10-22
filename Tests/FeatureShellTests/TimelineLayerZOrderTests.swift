import Foundation
import Testing
import CoreMedia
@preconcurrency import AVFoundation
import Domain
@testable import FeatureShell

@Suite("TimelineLayerZOrderTests")
struct TimelineLayerZOrderTests {

    @Test @MainActor func testOverlappingVideoAssetCreatesLayerOnTop() {
        let vm = TimelineViewModel()
        #expect(vm.layers.isEmpty)

        // Add first video asset (e.g. base video from 0s)
        let baseAsset = MediaAsset(
            url: URL(fileURLWithPath: "/tmp/base.mp4"),
            name: "BaseVideo.mp4",
            type: .video
        )
        vm.addAsset(baseAsset, at: .zero)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].kind == .video)
        #expect(vm.layers[0].name == "Video 1")

        // Add overlapping video asset (e.g. overlay video at 2s)
        let overlayAsset = MediaAsset(
            url: URL(fileURLWithPath: "/tmp/overlay.mp4"),
            name: "OverlayVideo.mp4",
            type: .video
        )
        vm.addAsset(overlayAsset, at: CMTime(seconds: 2, preferredTimescale: 600))

        // New overlay video MUST be placed on TOP (layers[0])
        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].name == "Video 2")
        #expect(vm.layers[0].clips.first?.name == "OverlayVideo.mp4")
        #expect(vm.layers[1].name == "Video 1")
        #expect(vm.layers[1].clips.first?.name == "BaseVideo.mp4")
    }

    @Test @MainActor func testVisualLayerTierStackingWithTextAndVideos() {
        let vm = TimelineViewModel()

        let baseVideo = MediaAsset(
            url: URL(fileURLWithPath: "/tmp/base.mp4"),
            name: "Base.mp4",
            type: .video
        )
        vm.addAsset(baseVideo, at: .zero)

        // Create text layer (tier 0)
        let textLayer = vm.createLayer(for: .text)
        #expect(vm.layers.firstIndex(where: { $0.id == textLayer.id }) == 0)

        // Add overlay video (tier 3) overlapping base video at 2s
        let overlayVideo = MediaAsset(
            url: URL(fileURLWithPath: "/tmp/overlay.mp4"),
            name: "Overlay.mp4",
            type: .video
        )
        vm.addAsset(overlayVideo, at: CMTime(seconds: 2, preferredTimescale: 600))

        // Expected order: Text (tier 0) -> Overlay Video (top of tier 3) -> Base Video
        #expect(vm.layers.count == 3)
        #expect(vm.layers[0].kind == .text)
        #expect(vm.layers[1].kind == .video)
        #expect(vm.layers[1].clips.first?.name == "Overlay.mp4")
        #expect(vm.layers[2].kind == .video)
        #expect(vm.layers[2].clips.first?.name == "Base.mp4")
    }

    @Test @MainActor func testMoveClipNotifiesTrimmedAndUpdatesOrder() {
        let vm = TimelineViewModel()
        let layer0 = vm.createLayer(for: .video)
        let layer1 = vm.createLayer(for: .video)

        let clip = TimelineClip(
            name: "ClipA",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600))
        )
        vm.addClip(clip, to: layer0.id)

        var didNotifyTrimmed = false
        vm.onClipsTrimmed = {
            didNotifyTrimmed = true
        }

        // Move clip to layer1
        vm.moveClip(
            clipID: clip.id,
            from: layer0.id,
            to: layer1.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 5, preferredTimescale: 600)
        )

        #expect(didNotifyTrimmed)
        #expect(vm.layers.contains { $0.id == layer1.id && $0.clips.contains { $0.id == clip.id } })
    }

    @Test func testCompositionBuilderInstructionOrderMatchesTopmostLayer() async {
        let topLayer = TimelineLayer(
            name: "TopVideo",
            kind: .video,
            clips: [
                TimelineClip(
                    name: "TopClip",
                    kind: .video,
                    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
                    mediaURL: URL(fileURLWithPath: "/tmp/nonexistent.mp4")
                )
            ]
        )
        let bottomLayer = TimelineLayer(
            name: "BottomVideo",
            kind: .video,
            clips: [
                TimelineClip(
                    name: "BottomClip",
                    kind: .video,
                    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
                    mediaURL: URL(fileURLWithPath: "/tmp/nonexistent.mp4")
                )
            ]
        )

        let composition = AVMutableComposition()
        let (_, instructions, _) = await TimelineCompositionBuilder.buildTracks(
            for: composition,
            from: [topLayer, bottomLayer],
            aspectRatio: .ratio16x9
        )

        // instructions count must match video layers count
        #expect(instructions.count == 2)
        // First instruction represents the topmost layer in AVFoundation
        let firstInst = instructions[0]
        #expect(firstInst.trackID == composition.tracks(withMediaType: .video).first?.trackID)
    }
}
