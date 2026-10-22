import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineMultiMoveTests")
@MainActor
struct TimelineMultiMoveTests {

    @Test func testGroupMoveAcrossMultipleLayersWithUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let videoLayer = vm.createLayer(for: .video)
        let audioLayer = vm.createLayer(for: .audio)

        let clipV1 = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clipA1 = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )

        vm.addClip(clipV1, to: videoLayer.id)
        vm.addClip(clipA1, to: audioLayer.id)

        vm.selectedClipIDs = [clipV1.id, clipA1.id]

        let moveDelta = CMTime(seconds: 3, preferredTimescale: 600)
        vm.commitGroupMove(delta: moveDelta)

        guard let updatedV1 = vm.layers[0].clips.first(where: { $0.id == clipV1.id }),
              let updatedA1 = vm.layers[1].clips.first(where: { $0.id == clipA1.id }) else {
            Issue.record("Clips should exist after moving")
            return
        }

        #expect(CMTimeCompare(updatedV1.timeRange.start, CMTime(seconds: 5, preferredTimescale: 600)) == 0)
        #expect(CMTimeCompare(updatedA1.timeRange.start, CMTime(seconds: 8, preferredTimescale: 600)) == 0)
        #expect(vm.canUndo)

        // Undo
        vm.undo()
        guard let undoneV1 = vm.layers[0].clips.first(where: { $0.id == clipV1.id }),
              let undoneA1 = vm.layers[1].clips.first(where: { $0.id == clipA1.id }) else {
            Issue.record("Clips should exist after undo")
            return
        }
        #expect(CMTimeCompare(undoneV1.timeRange.start, CMTime(seconds: 2, preferredTimescale: 600)) == 0)
        #expect(CMTimeCompare(undoneA1.timeRange.start, CMTime(seconds: 5, preferredTimescale: 600)) == 0)
        #expect(vm.canRedo)

        // Redo
        vm.redo()
        guard let redoneV1 = vm.layers[0].clips.first(where: { $0.id == clipV1.id }),
              let redoneA1 = vm.layers[1].clips.first(where: { $0.id == clipA1.id }) else {
            Issue.record("Clips should exist after redo")
            return
        }
        #expect(CMTimeCompare(redoneV1.timeRange.start, CMTime(seconds: 5, preferredTimescale: 600)) == 0)
        #expect(CMTimeCompare(redoneA1.timeRange.start, CMTime(seconds: 8, preferredTimescale: 600)) == 0)
    }

    @Test func testGroupMoveClampedWhenOneClipBlockedByObstacle() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)
        let audioLayer = vm.createLayer(for: .audio)

        let clipV1 = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let obstacleV2 = TimelineClip(
            name: "Obstacle",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 8, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        let clipA1 = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(seconds: 10, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )

        vm.addClip(clipV1, to: videoLayer.id)
        vm.addClip(obstacleV2, to: videoLayer.id)
        vm.addClip(clipA1, to: audioLayer.id)

        vm.selectedClipIDs = [clipV1.id, clipA1.id]

        // Propose to move forward by 6s (clipV1 would reach 6s, ending at 11s -> colliding with obstacle at 8s)
        let proposedStart = CMTime(seconds: 6, preferredTimescale: 600)
        let clampedDelta = vm.clampedGroupMoveDelta(pivotClipID: clipV1.id, proposedStart: proposedStart)

        // Safe max delta is 3s (0s + 5s = 5s, obstacle at 8s -> 8 - 5 = 3s)
        #expect(CMTimeCompare(clampedDelta, CMTime(seconds: 3, preferredTimescale: 600)) == 0)

        vm.commitGroupMove(delta: clampedDelta)

        guard let movedV1 = vm.layers[0].clips.first(where: { $0.id == clipV1.id }),
              let movedA1 = vm.layers[1].clips.first(where: { $0.id == clipA1.id }) else {
            Issue.record("Clips should exist after commit")
            return
        }

        #expect(CMTimeCompare(movedV1.timeRange.start, CMTime(seconds: 3, preferredTimescale: 600)) == 0)
        #expect(CMTimeCompare(movedA1.timeRange.start, CMTime(seconds: 13, preferredTimescale: 600)) == 0)
    }

    @Test func testGroupMoveLeftClampedAtTimelineStartZero() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)
        let audioLayer = vm.createLayer(for: .audio)

        let clipV1 = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        let clipA1 = TimelineClip(
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(seconds: 6, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))
        )

        vm.addClip(clipV1, to: videoLayer.id)
        vm.addClip(clipA1, to: audioLayer.id)

        vm.selectedClipIDs = [clipV1.id, clipA1.id]

        // Propose to move left to -3s (delta = -5s)
        let proposedStart = CMTime(seconds: -3, preferredTimescale: 600)
        let clampedDelta = vm.clampedGroupMoveDelta(pivotClipID: clipV1.id, proposedStart: proposedStart)

        // ClipV1 starts at 2s, so minDelta is -2s
        #expect(CMTimeCompare(clampedDelta, CMTime(seconds: -2, preferredTimescale: 600)) == 0)

        vm.commitGroupMove(delta: clampedDelta)

        guard let movedV1 = vm.layers[0].clips.first(where: { $0.id == clipV1.id }),
              let movedA1 = vm.layers[1].clips.first(where: { $0.id == clipA1.id }) else {
            Issue.record("Clips should exist after commit")
            return
        }

        #expect(CMTimeCompare(movedV1.timeRange.start, CMTime.zero) == 0)
        #expect(CMTimeCompare(movedA1.timeRange.start, CMTime(seconds: 4, preferredTimescale: 600)) == 0)
    }

    @Test func testGroupMoveVisualOffsetUpdatesAndResets() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)

        let clipV1 = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        vm.addClip(clipV1, to: videoLayer.id)
        vm.selectedClipIDs = [clipV1.id]
        vm.pixelsPerSecond = 50.0

        vm.updateGroupMove(pivotClipID: clipV1.id, proposedStart: CMTime(seconds: 3, preferredTimescale: 600))
        #expect(vm.groupMoveOffset == 2.0 * vm.pixelsPerSecond)

        vm.resetGroupMove()
        #expect(vm.groupMoveOffset == 0)
    }

    @Test func testGroupMoveMultipleClipsSameLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoLayer = vm.createLayer(for: .video)

        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 2, preferredTimescale: 600))
        )

        vm.addClip(clip1, to: videoLayer.id)
        vm.addClip(clip2, to: videoLayer.id)
        vm.selectedClipIDs = [clip1.id, clip2.id]

        // Move forward by 2s
        vm.commitGroupMove(delta: CMTime(seconds: 2, preferredTimescale: 600))

        guard let moved1 = vm.layers[0].clips.first(where: { $0.id == clip1.id }),
              let moved2 = vm.layers[0].clips.first(where: { $0.id == clip2.id }) else {
            Issue.record("Clips should exist")
            return
        }

        #expect(CMTimeCompare(moved1.timeRange.start, CMTime(seconds: 3, preferredTimescale: 600)) == 0)
        #expect(CMTimeCompare(moved2.timeRange.start, CMTime(seconds: 6, preferredTimescale: 600)) == 0)
    }
}
