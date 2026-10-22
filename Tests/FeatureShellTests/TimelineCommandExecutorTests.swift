import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineCommandExecutorTests")
@MainActor
struct TimelineCommandExecutorTests {
    @Test("AddClip command executes and undos/redos accurately")
    func testAddClipCommandUndoRedo() {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let executor = TimelineCommandExecutor(viewModel: vm)

        let clipScript = ClipScript(
            id: UUID(),
            name: "Test Video",
            kind: .video,
            source: .file(url: URL(fileURLWithPath: "/tmp/test.mp4")),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 60, timescale: 30)
            )
        )

        let command = TimelineCommand.addClip(layerID: layerID, clip: clipScript)

        #expect(vm.layers[0].clips.isEmpty)
        #expect(executor.canUndo == false)

        let success = executor.execute(command)
        #expect(success == true)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Test Video")
        #expect(executor.canUndo == true)

        let undoSuccess = executor.undo()
        #expect(undoSuccess == true)
        #expect(vm.layers[0].clips.isEmpty)
        #expect(executor.canRedo == true)

        let redoSuccess = executor.redo()
        #expect(redoSuccess == true)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Test Video")
    }

    @Test("MoveClip command moves clip to target layer and undoes back to source layer")
    func testMoveClipUndoRedo() {
        let layer1ID = UUID()
        let layer2ID = UUID()
        let clipID = UUID()

        let clip = TimelineClip(
            id: clipID,
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 30))
        )

        let layer1 = TimelineLayer(id: layer1ID, name: "V1", kind: .video, clips: [clip])
        let layer2 = TimelineLayer(id: layer2ID, name: "V2", kind: .video, clips: [])
        let vm = TimelineViewModel(initialLayers: [layer1, layer2])
        let executor = TimelineCommandExecutor(viewModel: vm)

        let moveCmd = TimelineCommand.moveClip(
            clipID: clipID,
            targetLayerID: layer2ID,
            newStartTime: RationalTime(value: 150, timescale: 30) // 5.0 seconds
        )

        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[1].clips.count == 0)

        executor.execute(moveCmd)
        #expect(vm.layers[0].clips.count == 0)
        #expect(vm.layers[1].clips.count == 1)
        #expect(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.start) == 5.0)

        executor.undo()
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[1].clips.count == 0)
        #expect(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.start) == 0.0)
    }

    @Test("SetLayerStatus command mutates layer status and undoes to previous status")
    func testSetLayerStatusUndoRedo() {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video, isLocked: false, isHidden: false, isMuted: false)
        let vm = TimelineViewModel(initialLayers: [layer])
        let executor = TimelineCommandExecutor(viewModel: vm)

        let cmd = TimelineCommand.setLayerStatus(layerID: layerID, isLocked: true, isHidden: true, isMuted: true)
        executor.execute(cmd)

        #expect(vm.layers[0].isLocked == true)
        #expect(vm.layers[0].isHidden == true)
        #expect(vm.layers[0].isMuted == true)

        executor.undo()
        #expect(vm.layers[0].isLocked == false)
        #expect(vm.layers[0].isHidden == false)
        #expect(vm.layers[0].isMuted == false)
    }

    @Test("Batch command executes all children and atomic undo rolls back all")
    func testBatchCommandUndoRedo() {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let executor = TimelineCommandExecutor(viewModel: vm)

        let clip1 = ClipScript(
            name: "Clip 1",
            kind: .video,
            source: .color(hex: "#FF0000"),
            timelineRange: RationalTimeRange(start: .zero, duration: RationalTime(value: 30, timescale: 30))
        )
        let clip2 = ClipScript(
            name: "Clip 2",
            kind: .video,
            source: .color(hex: "#00FF00"),
            timelineRange: RationalTimeRange(start: RationalTime(value: 30, timescale: 30), duration: RationalTime(value: 30, timescale: 30))
        )

        let batch = TimelineCommand.batch(commands: [
            .addClip(layerID: layerID, clip: clip1),
            .addClip(layerID: layerID, clip: clip2)
        ])

        executor.execute(batch)
        #expect(vm.layers[0].clips.count == 2)

        executor.undo()
        #expect(vm.layers[0].clips.isEmpty)

        executor.redo()
        #expect(vm.layers[0].clips.count == 2)
    }
}
