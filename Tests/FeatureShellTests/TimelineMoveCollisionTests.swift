import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineMoveCollisionTests")
@MainActor
struct TimelineMoveCollisionTests {

    @Test func testTimelineLayerAppendClipRejectsOverlappingClip() {
        var layer = TimelineLayer(name: "Video 1", kind: .video)
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clip2Overlapping = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )
        let clip3Adjacent = TimelineClip(
            name: "Clip 3",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 7, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))
        )

        #expect(layer.appendClip(clip1) == true)
        #expect(layer.clips.count == 1)

        // Clip 2 intersects [2..7] at [4..7] -> Must be rejected
        #expect(layer.appendClip(clip2Overlapping) == false)
        #expect(layer.clips.count == 1)

        // Clip 3 starts exactly at 7s (adjacent) -> Allowed
        #expect(layer.appendClip(clip3Adjacent) == true)
        #expect(layer.clips.count == 2)
    }

    @Test func testMoveClipOnSameTrackClampsAtNeighborBoundaries() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)

        let clipA = TimelineClip(
            name: "Clip A",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clipB = TimelineClip(
            name: "Clip B",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 7, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clipC = TimelineClip(
            name: "Clip C",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )

        vm.addClip(clipA, to: layer.id)
        vm.addClip(clipB, to: layer.id)
        vm.addClip(clipC, to: layer.id)

        #expect(vm.layers[0].clips.count == 3)

        // Attempt to move clip B to 2s (violates clip A's [0..5] boundary)
        vm.moveClip(
            clipID: clipB.id,
            from: layer.id,
            to: layer.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 2, preferredTimescale: 600)
        )

        // B must be clamped at exactly 5s
        let bAfterMoveLeft = vm.layers[0].clips.first { $0.id == clipB.id }
        #expect(bAfterMoveLeft != nil)
        #expect(bAfterMoveLeft?.timeRange.start == CMTime(seconds: 5, preferredTimescale: 600))

        // Attempt to move clip B to 13s (clip C starts at 15s, duration of B is 5s, max allowed start is 10s)
        vm.moveClip(
            clipID: clipB.id,
            from: layer.id,
            to: layer.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 13, preferredTimescale: 600)
        )

        // B must be clamped at exactly 10s
        let bAfterMoveRight = vm.layers[0].clips.first { $0.id == clipB.id }
        #expect(bAfterMoveRight != nil)
        #expect(bAfterMoveRight?.timeRange.start == CMTime(seconds: 10, preferredTimescale: 600))
    }

    @Test func testMoveClipCrossTrackCollidingEscalatesToNewLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer1 = vm.createLayer(for: .video)
        let layer2 = vm.createLayer(for: .video)

        let clipA = TimelineClip(
            name: "Clip A",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clipB = TimelineClip(
            name: "Clip B",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 10, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )

        vm.addClip(clipA, to: layer1.id)
        vm.addClip(clipB, to: layer2.id)

        #expect(vm.layers.count == 2)

        // Move Clip B from Layer 2 to Layer 1 at 3s -> collides with Clip A [2..7] on Layer 1
        vm.moveClip(
            clipID: clipB.id,
            from: layer2.id,
            to: layer1.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 3, preferredTimescale: 600)
        )

        // Auto Layer Escalation should occur: Clip B should be placed at 3s on a new layer
        // And layer2 (if now empty) is cleaned up
        let foundB = vm.layers.flatMap { $0.clips }.first { $0.id == clipB.id }
        #expect(foundB != nil)
        #expect(foundB?.timeRange.start == CMTime(seconds: 3, preferredTimescale: 600))

        // Clip A must still be intact on layer1
        let foundA = vm.layers.first(where: { $0.id == layer1.id })?.clips.first { $0.id == clipA.id }
        #expect(foundA != nil)
        #expect(foundA?.timeRange.start == CMTime(seconds: 2, preferredTimescale: 600))

        // Check that no track contains overlapping clips
        for track in vm.layers {
            for i in 0..<track.clips.count {
                for j in (i + 1)..<track.clips.count {
                    let c1 = track.clips[i]
                    let c2 = track.clips[j]
                    #expect(c1.timeRange.intersection(c2.timeRange).duration == .zero)
                }
            }
        }
    }

    @Test func testUndoRedoEscalatedMoveRestoresOriginalLayerAndCleansNewLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let layer1 = vm.createLayer(for: .video)
        let layer2 = vm.createLayer(for: .video)

        let clipA = TimelineClip(
            name: "Clip A",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        let clipB = TimelineClip(
            name: "Clip B",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 10, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600))
        )

        vm.addClip(clipA, to: layer1.id)
        vm.addClip(clipB, to: layer2.id)

        // Move Clip B from layer2 to layer1 at 4s (causes collision and auto-escalation)
        vm.moveClip(
            clipID: clipB.id,
            from: layer2.id,
            to: layer1.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 4, preferredTimescale: 600)
        )

        #expect(vm.canUndo == true)

        // Undo the move
        vm.undo()

        // Clip B should be back on layer2 at 10s
        let restoredB = vm.layers.first(where: { $0.id == layer2.id })?.clips.first { $0.id == clipB.id }
        #expect(restoredB != nil)
        #expect(restoredB?.timeRange.start == CMTime(seconds: 10, preferredTimescale: 600))

        // Redo the move
        vm.redo()

        let redoneB = vm.layers.flatMap { $0.clips }.first { $0.id == clipB.id }
        #expect(redoneB != nil)
        #expect(redoneB?.timeRange.start == CMTime(seconds: 4, preferredTimescale: 600))
    }

    @Test func testMoveClipWithNilTargetDefaultsToSourceLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        )
        vm.addClip(clip, to: layer.id)

        // Move with targetLayerID = nil and insertAtIndex = nil
        vm.moveClip(
            clipID: clip.id,
            from: layer.id,
            to: nil,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 12, preferredTimescale: 600)
        )

        let moved = vm.layers.first(where: { $0.id == layer.id })?.clips.first { $0.id == clip.id }
        #expect(moved != nil)
        #expect(moved?.timeRange.start == CMTime(seconds: 12, preferredTimescale: 600))
    }
}

