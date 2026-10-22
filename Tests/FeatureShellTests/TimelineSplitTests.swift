import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

struct TimelineSplitTests {
    @Test @MainActor func testSplitVideoClipCalculatesSourceStartCorrectly() {
        let clip = TimelineClip(
            id: UUID(),
            name: "VideoClip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)),
            maxDuration: CMTime(value: 60, timescale: 1),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4"),
            sourceStartTime: CMTime(value: 2, timescale: 1)
        )

        let splitTime = CMTime(value: 4, timescale: 1)
        let result = clip.split(at: splitTime)
        #expect(result != nil)

        if let (left, right) = result {
            #expect(left.id == clip.id)
            #expect(left.timeRange.start == .zero)
            #expect(left.timeRange.duration == CMTime(value: 4, timescale: 1))
            #expect(left.sourceStartTime == CMTime(value: 2, timescale: 1))

            #expect(right.id != clip.id)
            #expect(right.timeRange.start == CMTime(value: 4, timescale: 1))
            #expect(right.timeRange.duration == CMTime(value: 6, timescale: 1))
            #expect(right.sourceStartTime == CMTime(value: 6, timescale: 1))
            #expect(right.mediaURL == clip.mediaURL)
        }
    }

    @Test @MainActor func testSplitAudioClipCalculatesSourceStartCorrectly() {
        let clip = TimelineClip(
            id: UUID(),
            name: "AudioClip",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(value: 1, timescale: 1), duration: CMTime(value: 5, timescale: 1)),
            maxDuration: CMTime(value: 100, timescale: 1),
            mediaURL: URL(fileURLWithPath: "/tmp/audio.mp3"),
            sourceStartTime: CMTime(value: 1, timescale: 2) // 0.5s
        )

        let splitTime = CMTime(value: 3, timescale: 1)
        let result = clip.split(at: splitTime)
        #expect(result != nil)

        if let (left, right) = result {
            #expect(left.timeRange.start == CMTime(value: 1, timescale: 1))
            #expect(left.timeRange.duration == CMTime(value: 2, timescale: 1))
            #expect(left.sourceStartTime == CMTime(value: 1, timescale: 2))

            #expect(right.timeRange.start == CMTime(value: 3, timescale: 1))
            #expect(right.timeRange.duration == CMTime(value: 3, timescale: 1))
            #expect(right.sourceStartTime == CMTime(value: 5, timescale: 2)) // 0.5s + 2.0s = 2.5s
        }
    }

    @Test @MainActor func testSplitImageTextAdjustmentClips() {
        for kind in [ClipKind.image, ClipKind.text, ClipKind.adjustment] {
            let clip = TimelineClip(
                name: "\(kind.title)Clip",
                kind: kind,
                timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
            )
            let result = clip.split(at: CMTime(value: 2, timescale: 1))
            #expect(result != nil)
            if let (left, right) = result {
                #expect(left.timeRange.duration == CMTime(value: 2, timescale: 1))
                #expect(right.timeRange.duration == CMTime(value: 3, timescale: 1))
                #expect(right.sourceStartTime == .zero)
            }
        }
    }

    @Test @MainActor func testSplitClipsWithSelection() {
        let vm = TimelineViewModel()
        let clip1 = TimelineClip(id: UUID(), name: "C1", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)))
        let clip2 = TimelineClip(id: UUID(), name: "C2", kind: .video, timeRange: CMTimeRange(start: CMTime(value: 10, timescale: 1), duration: CMTime(value: 10, timescale: 1)))

        let layer = vm.createLayer(for: .video)
        vm.addClip(clip1, to: layer.id)
        vm.addClip(clip2, to: layer.id)

        // Select only clip1
        vm.selectClip(clip1.id)

        var splitReported: [UUID] = []
        vm.onClipsSplit = { ids in
            splitReported = ids
        }

        let newRightIDs = vm.splitClips(at: CMTime(value: 4, timescale: 1))

        #expect(newRightIDs.count == 1)
        #expect(splitReported == newRightIDs)
        #expect(vm.layers[0].clips.count == 3)
        #expect(vm.selectedClipIDs == Set(newRightIDs))
    }

    @Test @MainActor func testSplitClipsWithoutSelectionSplitsAllIntersecting() {
        let vm = TimelineViewModel()
        let clipV = TimelineClip(id: UUID(), name: "V1", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 8, timescale: 1)))
        let clipA = TimelineClip(id: UUID(), name: "A1", kind: .audio, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 8, timescale: 1)))

        let layerV = vm.createLayer(for: .video)
        let layerA = vm.createLayer(for: .audio)
        vm.addClip(clipV, to: layerV.id)
        vm.addClip(clipA, to: layerA.id)

        vm.clearSelection()

        let newRightIDs = vm.splitClips(at: CMTime(value: 3, timescale: 1))

        #expect(newRightIDs.count == 2)
        #expect(vm.layers.first(where: { $0.kind == .video })?.clips.count == 2)
        #expect(vm.layers.first(where: { $0.kind == .audio })?.clips.count == 2)
    }

    @Test @MainActor func testSplitLockedLayerIgnored() {
        let vm = TimelineViewModel()
        let clip = TimelineClip(name: "LockedClip", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1)))
        var layer = vm.createLayer(for: .video)
        layer.isLocked = true
        layer.appendClip(clip)
        vm.layers = [layer]

        let newRightIDs = vm.splitClips(at: CMTime(value: 5, timescale: 1))
        #expect(newRightIDs.isEmpty)
        #expect(vm.layers[0].clips.count == 1)
    }

    @Test @MainActor func testSplitTooShortOrOutsideReturnsNil() {
        let clip = TimelineClip(name: "ShortClip", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)))

        // Outside before
        #expect(clip.split(at: CMTime(value: -1, timescale: 1)) == nil)
        // Outside after
        #expect(clip.split(at: CMTime(value: 10, timescale: 1)) == nil)
        // Too close to start (< 0.1s)
        #expect(clip.split(at: CMTime(value: 1, timescale: 30)) == nil)
    }

    @Test @MainActor func testNonDestructiveTrimAndCollisionAfterSplit() {
        let vm = TimelineViewModel()
        let clip = TimelineClip(
            id: UUID(),
            name: "Video60s",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 60, timescale: 1)),
            maxDuration: CMTime(value: 60, timescale: 1),
            mediaURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            sourceStartTime: .zero
        )

        let layer = vm.createLayer(for: .video)
        vm.addClip(clip, to: layer.id)
        vm.selectClip(clip.id)

        let rightIDs = vm.splitClips(at: CMTime(value: 25, timescale: 1))
        #expect(rightIDs.count == 1)
        let rightID = rightIDs[0]

        let clipsAfterSplit = vm.layers[0].clips
        #expect(clipsAfterSplit.count == 2)
        let leftClip = clipsAfterSplit[0]
        let rightClip = clipsAfterSplit[1]

        #expect(leftClip.id == clip.id)
        #expect(leftClip.timeRange.start == .zero)
        #expect(leftClip.timeRange.duration == CMTime(value: 25, timescale: 1))
        #expect(leftClip.sourceStartTime == .zero)

        #expect(rightClip.id == rightID)
        #expect(rightClip.timeRange.start == CMTime(value: 25, timescale: 1))
        #expect(rightClip.timeRange.duration == CMTime(value: 35, timescale: 1))
        #expect(rightClip.sourceStartTime == CMTime(value: 25, timescale: 1))

        // 1. Collision blocking: left clip cannot expand right into rightClip (start at 25s)
        vm.trimClip(clipID: leftClip.id, in: layer.id, newStart: .zero, newDuration: CMTime(value: 30, timescale: 1), newSourceStart: nil)
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 25, timescale: 1))

        // 2. Collision blocking: right clip cannot expand left into leftClip (ends at 25s)
        vm.trimClip(
            clipID: rightClip.id,
            in: layer.id,
            newStart: CMTime(value: 20, timescale: 1),
            newDuration: CMTime(value: 40, timescale: 1),
            newSourceStart: CMTime(value: 20, timescale: 1)
        )
        #expect(vm.layers[0].clips[1].timeRange.start == CMTime(value: 25, timescale: 1))

        // 3. Move rightClip to 35s creating a 10s gap (25s..35s)
        vm.moveClip(clipID: rightClip.id, from: layer.id, to: layer.id, insertAtIndex: nil, newStartTime: CMTime(value: 35, timescale: 1))
        #expect(vm.layers[0].clips[1].timeRange.start == CMTime(value: 35, timescale: 1))

        // 4. Now leftClip can expand right into the gap (up to 35s)
        vm.trimClip(clipID: leftClip.id, in: layer.id, newStart: .zero, newDuration: CMTime(value: 32, timescale: 1), newSourceStart: nil)
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 32, timescale: 1))

        // 5. Expand rightClip left edge into the gap: start moves from 35s to 33s, recovering earlier source frames
        vm.trimClip(
            clipID: rightClip.id,
            in: layer.id,
            newStart: CMTime(value: 33, timescale: 1),
            newDuration: CMTime(value: 37, timescale: 1),
            newSourceStart: CMTime(value: 23, timescale: 1)
        )
        let updatedRight = vm.layers[0].clips[1]
        #expect(updatedRight.timeRange.start == CMTime(value: 33, timescale: 1))
        #expect(updatedRight.timeRange.duration == CMTime(value: 37, timescale: 1))
        #expect(updatedRight.sourceStartTime == CMTime(value: 23, timescale: 1))
    }

    @Test @MainActor func testSplitAtFractionalFramePreservesExactSourceStart() {
        let videoClip = TimelineClip(
            id: UUID(),
            name: "VideoClip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 300, timescale: 30)),
            maxDuration: CMTime(value: 300, timescale: 30),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4"),
            sourceStartTime: .zero
        )

        // Split at 00:00:01:28 (58 frames at 30fps = 1.933333s)
        let splitTime = CMTime(value: 58, timescale: 30)
        let result = videoClip.split(at: splitTime)
        #expect(result != nil)

        if let (left, right) = result {
            #expect(left.timeRange.duration == CMTime(value: 58, timescale: 30))
            #expect(right.timeRange.start == CMTime(value: 58, timescale: 30))
            #expect(right.sourceStartTime == CMTime(value: 58, timescale: 30))
            #expect(CMTimeGetSeconds(right.sourceStartTime) == CMTimeGetSeconds(splitTime))
        }
    }
}
