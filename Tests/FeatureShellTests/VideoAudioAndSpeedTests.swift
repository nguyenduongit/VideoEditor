import Foundation
import CoreMedia
import AVFoundation
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("VideoAudioAndSpeedTests")
struct VideoAudioAndSpeedTests {

    @Test("ClipPropertyRegistry provides Audio and Speed descriptors for video clips")
    func testClipPropertyRegistryAudioAndSpeedDescriptors() {
        let tabs = ClipPropertyRegistry.shared.tabs(for: .video)
        #expect(tabs.contains("Video"))
        #expect(tabs.contains("Audio"))
        #expect(tabs.contains("Mask"))

        let audioDesc = ClipPropertyRegistry.shared.descriptors(for: .video, tab: "Audio")
        let audioIDs = Set(audioDesc.map(\.id))
        #expect(audioIDs.contains("volume"))
        #expect(audioIDs.contains("fadeIn"))
        #expect(audioIDs.contains("fadeOut"))

        let speedDesc = ClipPropertyRegistry.shared.descriptors(for: .video, tab: "Video").filter { $0.group == "Speed" }
        let speedIDs = Set(speedDesc.map(\.id))
        #expect(speedIDs.contains("speed"))
        #expect(speedIDs.contains("duration"))
        #expect(speedIDs.contains("pitchPreservation"))
    }

    @Test("InspectorViewModel calculates bidirectional duration when speed changes")
    @MainActor
    func testInspectorSpeedDurationBidirectionalCalculation() {
        let vm = TimelineViewModel(initialLayers: [])
        let clip = TimelineClip(
            name: "TestVideo",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            properties: ["speed": .number(1.0)]
        )
        vm.addClip(clip)
        vm.selectedClipIDs = [clip.id]

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        // Initial duration should match clip timeRange (10.0s)
        #expect(inspectorVM.liveNumber(for: "duration", default: 0) == 10.0)

        // Adjust speed to 2.0x -> duration should update live to 5.0s
        inspectorVM.updateLiveValue(key: "speed", value: 2.0)
        #expect(inspectorVM.liveProperties["speed"]?.asNumber == 2.0)
        #expect(inspectorVM.liveProperties["duration"]?.asNumber == 5.0)

        // Adjust duration to 20.0s -> speed should update live to 0.5x
        inspectorVM.updateLiveValue(key: "duration", value: 20.0)
        #expect(inspectorVM.liveProperties["duration"]?.asNumber == 20.0)
        #expect(inspectorVM.liveProperties["speed"]?.asNumber == 0.5)
    }

    @Test("applySpeedChange scales clip duration and ripples subsequent clips on the same layer")
    @MainActor
    func testApplySpeedChangeWithRipple() {
        let vm = TimelineViewModel(initialLayers: [])
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 6, timescale: 1)),
            properties: ["speed": .number(1.0)]
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 6, timescale: 1), duration: CMTime(value: 4, timescale: 1)),
            properties: ["speed": .number(1.0)]
        )
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [clip1, clip2])
        vm.layers = [layer]

        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        // Change Clip 1 speed to 2.0x (duration becomes 3s, delta is -3s)
        var newProps = clip1.properties
        newProps["speed"] = .number(2.0)
        vm.applySpeedChange(clipID: clip1.id, newProperties: newProps, oldProperties: clip1.properties)

        // Verify Clip 1 duration scaled to 3s
        guard let updated1 = vm.clip(by: clip1.id), let updated2 = vm.clip(by: clip2.id) else {
            Issue.record("Clips not found")
            return
        }
        #expect(CMTimeGetSeconds(updated1.timeRange.duration) == 3.0)
        #expect(CMTimeGetSeconds(updated1.timeRange.start) == 0.0)

        // Verify Clip 2 shifted left from 6s to 3s (ripple)
        #expect(CMTimeGetSeconds(updated2.timeRange.start) == 3.0)

        // Test Undo
        let didUndo = vm.undo()
        #expect(didUndo == true)

        guard let undone1 = vm.clip(by: clip1.id), let undone2 = vm.clip(by: clip2.id) else {
            Issue.record("Clips not found after undo")
            return
        }
        #expect(CMTimeGetSeconds(undone1.timeRange.duration) == 6.0)
        #expect(CMTimeGetSeconds(undone2.timeRange.start) == 6.0)
        #expect(undone1.properties["speed"]?.asNumber == 1.0)
    }

    @Test("applyAudioMix configures volume ramps and pitch algorithm correctly")
    @MainActor
    func testAudioMixConfiguration() {
        let engine = TimelinePlaybackEngine()
        let clip = TimelineClip(
            name: "Clip With Audio",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            properties: [
                "volume": .number(1.5),
                "fadeIn": .number(2.0),
                "fadeOut": .number(3.0),
                "pitchPreservation": .bool(true)
            ]
        )
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video, clips: [clip])
        engine.layerAudioTrackIDs[layerID] = [102]

        let item = AVPlayerItem(asset: AVMutableComposition())
        engine.applyAudioMix(layers: [layer], to: item)

        #expect(item.audioMix != nil)
        #expect(item.audioMix?.inputParameters.count == 1)
        #expect(item.audioTimePitchAlgorithm == .timeDomain)

        // Disable pitch preservation -> algorithm changes to .varispeed
        var noPitchClip = clip
        noPitchClip.properties["pitchPreservation"] = .bool(false)
        let noPitchLayer = TimelineLayer(id: layerID, name: "V1", kind: .video, clips: [noPitchClip])
        engine.applyAudioMix(layers: [noPitchLayer], to: item)
        #expect(item.audioTimePitchAlgorithm == .varispeed)
    }

    @Test("applySpeedChange to 0.5x correctly expands clip to 264s when source maxDuration is 145s")
    @MainActor
    func testSlowMotionDurationExceedsMaxDuration() {
        let vm = TimelineViewModel(initialLayers: [])
        let clip = TimelineClip(
            name: "LongVideo",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 132, timescale: 1)),
            maxDuration: CMTime(value: 145, timescale: 1),
            properties: ["speed": .number(1.0)]
        )
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [clip])
        vm.layers = [layer]
        vm.selectedClipIDs = [clip.id]

        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        var newProps = clip.properties
        newProps["speed"] = .number(0.5)
        newProps["duration"] = .number(264.0)

        vm.applySpeedChange(clipID: clip.id, newProperties: newProps, oldProperties: clip.properties)

        guard let updated = vm.clip(by: clip.id) else {
            Issue.record("Clip not found")
            return
        }
        #expect(CMTimeGetSeconds(updated.timeRange.duration) == 264.0)
        #expect(updated.properties["speed"]?.asNumber == 0.5)

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        #expect(inspectorVM.liveNumber(for: "duration", default: 0) == 264.0)
        #expect(inspectorVM.liveNumber(for: "speed", default: 0) == 0.5)
    }

    @Test("TimelineClipTrimBounds accounts for clip speed in maxEnd and minStart")
    func testTrimBoundsAccountForSpeed() {
        let clip = TimelineClip(
            name: "SpeedClip",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 10, timescale: 1), duration: CMTime(value: 20, timescale: 1)),
            maxDuration: CMTime(value: 100, timescale: 1),
            sourceStartTime: CMTime(value: 10, timescale: 1),
            properties: ["speed": .number(0.5)]
        )

        // At 0.5x, 90s remaining source media allows 90 / 0.5 = 180s on timeline
        // maxEnd = 10s (start) + 180s = 190s
        let maxEnd = TimelineClipTrimBounds.maxEnd(clip: clip, nextClipStart: nil)
        #expect(abs(maxEnd - 190.0) < 0.001)

        // At 0.5x, 10s sourceStartTime can be trimmed left by 10 / 0.5 = 20s
        // minStart = 10s - 20s = -10s, clamped to 0.0
        let minStart = TimelineClipTrimBounds.minStart(clip: clip, previousClipEnd: nil)
        #expect(minStart == 0.0)
    }
}
