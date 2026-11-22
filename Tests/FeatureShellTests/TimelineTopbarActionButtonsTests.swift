import Foundation
import CoreMedia
import SwiftUI
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineTopbarActionButtonsTests")
@MainActor
struct TimelineTopbarActionButtonsTests {

    @Test func testTimelineViewModelCanSplitState() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        vm.addClip(clip, to: layer.id)

        // Initially no clips selected
        #expect(!vm.canSplit)

        // Select clip -> canSplit becomes true
        vm.selectClip(clip.id)
        #expect(vm.canSplit)

        // Add second clip and multi-select
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 6, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        vm.addClip(clip2, to: layer.id)
        vm.selectedClipIDs = [clip.id, clip2.id]
        #expect(vm.canSplit)

        // Clear selection -> canSplit becomes false
        vm.clearSelection()
        #expect(!vm.canSplit)
    }

    @Test func testTimelineTopbarViewCanSplitAndCanSyncAudioProps() {
        var splitTriggered = false
        var syncTriggered = false

        var pps: CGFloat = 60.0
        let binding = Binding(get: { pps }, set: { pps = $0 })

        // Default instance
        let _ = TimelineTopbarView()

        // Custom instance with canSplit and canSyncAudio
        let _ = TimelineTopbarView(
            currentTime: CMTime(seconds: 2, preferredTimescale: 600),
            pixelsPerSecond: binding,
            canSplit: true,
            canSyncAudio: true,
            isSyncingAudio: false,
            canAutoTrim: true,
            canCompactBackward: true,
            onSplit: { splitTriggered = true },
            onSyncAudio: { syncTriggered = true }
        )
        #expect(!splitTriggered)
        #expect(!syncTriggered)
    }

    @Test("System Tools: Auto Trim, Compact Backward (selected clips only), and Mute Video execute with full Undo/Redo")
    func testAutoTrimCompactBackwardAndMuteVideoTools() {
        let clipVideo = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 20, preferredTimescale: 600)),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let clipAudio = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 12, preferredTimescale: 600)),
            mediaURL: URL(fileURLWithPath: "/tmp/audio.mp3")
        )
        let vm = TimelineViewModel(initialLayers: [
            TimelineLayer(name: "V1", kind: .video, clips: [clipVideo]),
            TimelineLayer(name: "A1", kind: .audio, clips: [clipAudio])
        ])

        // 1. Before Auto Trim: Video [0..20], Audio [4..16] -> canAutoTrim is true, canCompactBackward is false (nothing selected)
        #expect(vm.canAutoTrim == true)
        #expect(vm.canCompactBackward == false)

        // 2. Run Auto Trim -> Both Video and Audio are trimmed to overlap [4..16], Video sourceStartTime becomes 4.0s
        #expect(vm.autoTrimOverlapClips() == true)
        #expect(vm.canAutoTrim == false)
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.start) - 4.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.duration) - 12.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].sourceStartTime) - 4.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.start) - 4.0) < 0.05)

        // 3. After Auto Trim: must select clips before Compact Backward becomes active!
        #expect(vm.canCompactBackward == false)
        vm.selectedClipIDs = [clipVideo.id, clipAudio.id]
        #expect(vm.canCompactBackward == true)
        #expect(vm.compactSelectedClipsBackward() == true)
        #expect(vm.canCompactBackward == false)
        #expect(vm.layers[0].clips[0].timeRange.start == .zero)
        #expect(vm.layers[1].clips[0].timeRange.start == .zero)

        // 4. Mute Video tool mutes video layer & clip volume
        #expect(vm.muteVideoTracks() == true)
        #expect(vm.layers[0].isMuted == true)
        #expect(vm.layers[0].clips[0].properties["volume"]?.asNumber == 0.0)

        // 5. Undo step by step: Undo Mute -> Undo Compact Backward -> Undo Auto Trim
        #expect(vm.undo() == true)
        #expect(vm.layers[0].isMuted == false)
        #expect(vm.undo() == true)
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.start) - 4.0) < 0.05)
        #expect(vm.undo() == true)
        #expect(vm.layers[0].clips[0].timeRange.start == .zero)
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.duration) - 20.0) < 0.05)
    }

    @Test("Compact Backward affects ONLY selected clips and snaps flush against preceding clip instead of 00:00")
    func testCompactBackwardAppliesOnlyToSelectedAndRespectsPrecedingClip() {
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 8, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))
        )
        let clip3Unselected = TimelineClip(
            name: "Clip 3",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))
        )

        let vm = TimelineViewModel(initialLayers: [
            TimelineLayer(name: "V1", kind: .video, clips: [clip1, clip2, clip3Unselected])
        ])

        // Nothing selected -> disabled & no-op
        #expect(vm.canCompactBackward == false)
        #expect(vm.compactSelectedClipsBackward() == false)

        // Select ONLY Clip 2 [8..11]. Clip 1 is at [1..5].
        // Clip 2 must compact flush against Clip 1's end (5.0s), NOT 00:00, and Clip 1 & Clip 3 stay untouched.
        vm.selectClip(clip2.id)
        #expect(vm.canCompactBackward == true)
        #expect(vm.compactSelectedClipsBackward() == true)

        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip1.id)!.timeRange.start) - 1.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip2.id)!.timeRange.start) - 5.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip3Unselected.id)!.timeRange.start) - 15.0) < 0.02)
        #expect(vm.canCompactBackward == false)

        // Undo restores Clip 2 to 8.0s
        #expect(vm.undo() == true)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip2.id)!.timeRange.start) - 8.0) < 0.02)

        // Now select BOTH Clip 1 and Clip 2 -> Clip 1 moves to 0.0s [0..4], Clip 2 compacts to 4.0s [4..7], Clip 3 stays at 15.0s!
        vm.selectedClipIDs = [clip1.id, clip2.id]
        #expect(vm.canCompactBackward == true)
        #expect(vm.compactSelectedClipsBackward() == true)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip1.id)!.timeRange.start) - 0.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip2.id)!.timeRange.start) - 4.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(vm.clip(by: clip3Unselected.id)!.timeRange.start) - 15.0) < 0.02)
    }
}
