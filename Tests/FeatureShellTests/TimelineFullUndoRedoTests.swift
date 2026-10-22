import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineFullUndoRedoTests")
@MainActor
struct TimelineFullUndoRedoTests {
    @Test func testSplitClipThenUndoRestoresOriginalClip() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)
        #expect(vm.layers[0].clips.count == 1)

        // Split at 4 seconds
        let splitTime = CMTime(value: 4, timescale: 1)
        let newRightIDs = vm.splitClips(at: splitTime)
        #expect(!newRightIDs.isEmpty)
        #expect(vm.layers[0].clips.count == 2)
        #expect(vm.canUndo)

        // Undo Split
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 10, timescale: 1))

        // Redo Split
        let redoSuccess = vm.redo()
        #expect(redoSuccess == true)
        #expect(vm.layers[0].clips.count == 2)
    }

    @Test func testDeleteSelectedClipsThenUndoRestoresClips() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip to Delete",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)
        vm.selectClip(clip.id)

        vm.deleteSelectedClips()
        #expect(vm.layers.isEmpty || vm.layers[0].clips.isEmpty)
        #expect(vm.canUndo)

        // Undo Delete
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Clip to Delete")
    }

    @Test func testTrimClipThenUndoRestoresOriginalBounds() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip to Trim",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)

        // Trim duration to 6 seconds
        vm.trimClip(
            clipID: clip.id,
            in: layer.id,
            newStart: .zero,
            newDuration: CMTime(value: 6, timescale: 1)
        )
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 6, timescale: 1))
        #expect(vm.canUndo)

        // Undo Trim
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 10, timescale: 1))
    }

    @Test func testMoveClipThenUndoRestoresOriginalTime() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip to Move",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 4, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)

        // Move to start time 3s
        vm.moveClip(
            clipID: clip.id,
            from: layer.id,
            to: layer.id,
            insertAtIndex: nil,
            newStartTime: CMTime(value: 3, timescale: 1)
        )
        #expect(vm.layers[0].clips[0].timeRange.start == CMTime(value: 3, timescale: 1))
        #expect(vm.canUndo)

        // Undo Move
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers[0].clips[0].timeRange.start == .zero)
    }

    @Test func testAddAssetThenUndoRemovesAddedClip() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample_add_undo.mp4"), type: .video)

        vm.addAsset(asset, at: .zero)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.canUndo)

        // Undo Add
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers.isEmpty || vm.layers[0].clips.isEmpty)
    }

    @Test func testObservableCanUndoAndCanRedoStateUpdates() {
        let vm = TimelineViewModel(initialLayers: [])
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == false)

        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample_state.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)
        #expect(vm.canUndo == true)
        #expect(vm.canRedo == false)

        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == true)

        let redoSuccess = vm.redo()
        #expect(redoSuccess == true)
        #expect(vm.canUndo == true)
        #expect(vm.canRedo == false)

        vm.commandExecutor?.clearHistory()
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == false)
    }
}
