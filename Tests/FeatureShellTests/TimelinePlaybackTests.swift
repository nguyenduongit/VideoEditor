import Foundation
import CoreMedia
import AVFoundation
import Testing
import Domain
@testable import FeatureShell

struct TimelinePlaybackTests {
    @Test @MainActor func testTimelineTotalDurationEmpty() {
        let timelineVM = TimelineViewModel()
        #expect(timelineVM.totalDuration == .zero)
    }

    @Test @MainActor func testTimelineTotalDurationWithClips() {
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .image,
            timeRange: CMTimeRange(start: CMTime(value: 3, timescale: 1), duration: CMTime(value: 7, timescale: 1))
        )

        let layer1 = TimelineLayer(name: "Video 1", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(name: "Image 1", kind: .image, clips: [clip2])

        let timelineVM = TimelineViewModel(initialLayers: [layer2, layer1])
        // Clip 2 ends at 3 + 7 = 10s. Clip 1 ends at 5s. Total duration should be 10s.
        #expect(CMTimeGetSeconds(timelineVM.totalDuration) == 10.0)
    }

    @Test @MainActor func testActiveVisualClipLayerPriority() {
        let topClip = TimelineClip(
            name: "Top Image",
            kind: .image,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1))
        )
        let bottomClip = TimelineClip(
            name: "Bottom Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 6, timescale: 1))
        )

        let topLayer = TimelineLayer(name: "Image Layer", kind: .image, clips: [topClip])
        let bottomLayer = TimelineLayer(name: "Video Layer", kind: .video, clips: [bottomClip])

        let timelineVM = TimelineViewModel(initialLayers: [topLayer, bottomLayer])

        // At 2s, both clips are active, top layer should win
        let activeAt2 = timelineVM.activeVisualClip(at: CMTime(value: 2, timescale: 1))
        #expect(activeAt2?.id == topClip.id)

        // At 5s, top clip ended, bottom video clip should be active
        let activeAt5 = timelineVM.activeVisualClip(at: CMTime(value: 5, timescale: 1))
        #expect(activeAt5?.id == bottomClip.id)

        // At 7s, neither is active
        let activeAt7 = timelineVM.activeVisualClip(at: CMTime(value: 7, timescale: 1))
        #expect(activeAt7 == nil)
    }

    @Test @MainActor func testActiveVisualClipIgnoresHiddenAndAudioLayers() {
        let audioClip = TimelineClip(
            name: "Audio",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let hiddenClip = TimelineClip(
            name: "Hidden Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let normalClip = TimelineClip(
            name: "Normal Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )

        var hiddenLayer = TimelineLayer(name: "Hidden", kind: .video, clips: [hiddenClip])
        hiddenLayer.isHidden = true
        let audioLayer = TimelineLayer(name: "Audio", kind: .audio, clips: [audioClip])
        let normalLayer = TimelineLayer(name: "Normal", kind: .video, clips: [normalClip])

        let timelineVM = TimelineViewModel(initialLayers: [hiddenLayer, audioLayer, normalLayer])

        let active = timelineVM.activeVisualClip(at: CMTime(value: 1, timescale: 1))
        #expect(active?.id == normalClip.id)
    }

    @Test @MainActor func testShellViewModelTimelinePlaybackToggle() {
        let registry = TabRegistry()
        let clip = TimelineClip(
            name: "Test",
            kind: .image,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let layer = TimelineLayer(name: "Layer 1", kind: .image, clips: [clip])
        let timelineVM = TimelineViewModel(initialLayers: [layer])

        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        #expect(shellVM.hasTimelineClips == true)
        #expect(shellVM.canPlayback == true)
        #expect(shellVM.isPlaying == false)

        shellVM.togglePlayPause()
        #expect(shellVM.isPlaying == true)
        #expect(shellVM.playheadState.isPlaying == true)

        shellVM.togglePlayPause()
        #expect(shellVM.isPlaying == false)
        #expect(shellVM.playheadState.isPlaying == false)
    }

    @Test @MainActor func testHasActiveVideoClipAndActiveImageClip() {
        let videoClip = TimelineClip(
            name: "Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1))
        )
        let imageClip = TimelineClip(
            name: "Image",
            kind: .image,
            timeRange: CMTimeRange(start: CMTime(value: 9, timescale: 1), duration: CMTime(value: 5, timescale: 1))
        )
        let audioClip = TimelineClip(
            name: "Audio",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 31, timescale: 1))
        )

        let imageLayer = TimelineLayer(name: "Image Layer", kind: .image, clips: [imageClip])
        let videoLayer = TimelineLayer(name: "Video Layer", kind: .video, clips: [videoClip])
        let audioLayer = TimelineLayer(name: "Audio Layer", kind: .audio, clips: [audioClip])

        let timelineVM = TimelineViewModel(initialLayers: [imageLayer, videoLayer, audioLayer])
        let shellVM = ShellViewModel(registry: TabRegistry(), timelineViewModel: timelineVM)

        // At 5s: only video is active
        shellVM.playheadState.seek(to: CMTime(value: 5, timescale: 1))
        #expect(shellVM.isTimelineVideoActive == true)
        #expect(shellVM.timelinePreviewImage == nil)

        // At 9.5s: video is active AND image is active (image overlay on video)
        shellVM.playheadState.seek(to: CMTime(seconds: 9.5, preferredTimescale: 600))
        #expect(shellVM.isTimelineVideoActive == true)
        #expect(timelineVM.activeImageClip(at: CMTime(seconds: 9.5, preferredTimescale: 600))?.id == imageClip.id)

        // At 12s: video has ended, only image is active
        shellVM.playheadState.seek(to: CMTime(value: 12, timescale: 1))
        #expect(shellVM.isTimelineVideoActive == false)
        #expect(timelineVM.activeImageClip(at: CMTime(value: 12, timescale: 1))?.id == imageClip.id)

        // At 15s: video and image both ended, only audio continues -> video must be inactive
        shellVM.playheadState.seek(to: CMTime(value: 15, timescale: 1))
        #expect(shellVM.isTimelineVideoActive == false)
        #expect(shellVM.timelinePreviewImage == nil)
    }

    @Test @MainActor func testMultiLayerVideoCompositionBuildsVideoComposition() async {
        let engine = TimelinePlaybackEngine()
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/fake1.mp4")
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 4, timescale: 1), duration: CMTime(value: 6, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/fake2.mp4")
        )

        let layerTop = TimelineLayer(name: "Top Layer", kind: .video, clips: [clip2])
        let layerBottom = TimelineLayer(name: "Bottom Layer", kind: .video, clips: [clip1])

        engine.syncTimeline(layers: [layerTop, layerBottom], totalDuration: CMTime(value: 10, timescale: 1))

        for _ in 0..<20 {
            if engine.player.currentItem != nil { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(engine.player.currentItem != nil)
        #expect(engine.player.currentItem?.videoComposition != nil)
        #expect(engine.player.currentItem?.videoComposition?.instructions.count == 1)
        if let inst = engine.player.currentItem?.videoComposition?.instructions.first as? AVVideoCompositionInstruction {
            #expect(inst.layerInstructions.count == 2)
        }
    }

    @Test @MainActor func testSeekWhilePlayingKeepsPlayingFromNewTime() {
        let registry = TabRegistry()
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 20, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/fake.mp4")
        )
        let layer = TimelineLayer(name: "Layer 1", kind: .video, clips: [clip])
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        shellVM.startPlayback()
        #expect(shellVM.isPlaying == true)

        let targetTime = CMTime(value: 8, timescale: 1)
        shellVM.playheadState.seek(to: targetTime)

        #expect(shellVM.playheadState.currentTime == targetTime)
        #expect(shellVM.isPlaying == true)
    }

    @Test @MainActor func testInitialTimelineSyncSetsValidTimeAndWaitsForRendering() async {
        let engine = TimelinePlaybackEngine()
        let clip = TimelineClip(
            name: "First Clip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            mediaURL: URL(fileURLWithPath: "/tmp/fake_first.mp4")
        )
        let layer = TimelineLayer(name: "Layer 1", kind: .video, clips: [clip])

        engine.syncTimeline(
            layers: [layer],
            totalDuration: CMTime(value: 5, timescale: 1),
            targetTime: .zero
        )

        for _ in 0..<20 {
            if engine.player.currentItem != nil { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(engine.player.currentItem != nil)
        #expect(engine.player.currentItem?.seekingWaitsForVideoCompositionRendering == true)
        let currentTime = engine.player.currentTime()
        #expect(currentTime.isValid)
        #expect(currentTime.isNumeric)
        #expect(currentTime == .zero)
    }

    @Test @MainActor func testAudioClipWithoutFadeMaintainsConstantVolume() {
        let engine = TimelinePlaybackEngine()
        let clip = TimelineClip(
            name: "Full Song",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 60, timescale: 1)),
            properties: ["volume": .number(1.0), "fadeIn": .number(0.0), "fadeOut": .number(0.0)]
        )
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "Audio Track", kind: .audio, clips: [clip])

        let comp = AVMutableComposition()
        let audioTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let trackID = audioTrack?.trackID ?? 101
        engine.layerAudioTrackIDs = [layerID: [trackID]]

        let item = AVPlayerItem(asset: comp)
        engine.applyAudioMix(layers: [layer], to: item)

        let params = item.audioMix?.inputParameters.first { $0.trackID == trackID }
        #expect(params != nil)

        var sVol: Float = -1
        var eVol: Float = -1
        var range = CMTimeRange()
        let midTime = CMTime(value: 30, timescale: 1)
        let ok = params?.getVolumeRamp(for: midTime, startVolume: &sVol, endVolume: &eVol, timeRange: &range) ?? false

        #expect(ok == true)
        #expect(sVol == 1.0)
        #expect(eVol == 1.0)
    }
}

