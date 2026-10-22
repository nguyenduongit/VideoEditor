import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineViewModelUndoRedoTests")
@MainActor
struct TimelineViewModelUndoRedoTests {
    @Test func testTimelineViewModelUndoRedoIntegration() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let layer = vm.createLayer(for: .video)
        let clipScript = ClipScript(
            name: "Clip Test",
            kind: .video,
            source: .file(url: URL(fileURLWithPath: "/tmp/clip.mp4")),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 90, timescale: 30)
            )
        )

        #expect(!vm.canUndo)
        #expect(!vm.canRedo)

        // Execute AddClip via command executor
        let addCmd = TimelineCommand.addClip(layerID: layer.id, clip: clipScript)
        let success = executor.execute(addCmd)
        #expect(success == true)

        #expect(vm.canUndo)
        #expect(!vm.canRedo)
        #expect(vm.layers[0].clips.count == 1)

        // Undo
        vm.undo()
        #expect(!vm.canUndo)
        #expect(vm.canRedo)
        #expect(vm.layers.isEmpty || vm.layers[0].clips.isEmpty)

        // Redo
        vm.redo()
        #expect(vm.canUndo)
        #expect(!vm.canRedo)
        #expect(vm.layers[0].clips.count == 1)
    }

    @Test func testProjectScriptExportAndLoad() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 10, timescale: 1))
        )
        vm.addClip(clip, to: layer.id)

        let script = vm.exportScript(title: "My Project")
        #expect(script.metadata.title == "My Project")
        #expect(script.layers.count == 1)
        #expect(script.layers[0].clips.count == 1)

        // Load project script
        let newScript = ProjectScript(
            title: "Imported",
            fps: 30,
            layers: [
                LayerScript(
                    name: "New Layer",
                    kind: .audio,
                    isLocked: false,
                    isHidden: false,
                    isMuted: true,
                    clips: []
                )
            ]
        )
        vm.loadScript(newScript)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].name == "New Layer")
        #expect(vm.layers[0].isMuted == true)
        #expect(!vm.canUndo)
    }
}
