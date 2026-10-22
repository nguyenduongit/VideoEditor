import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("TimelineHistoryTimeTravelTests")
@MainActor
struct TimelineHistoryTimeTravelTests {
    @Test("jumpToHistory allows arbitrary time-travel navigation across edit history")
    func testTimeTravelNavigation() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset1 = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample1.mp4"), type: .video)
        let asset2 = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample2.mp4"), type: .video)

        // Step 1: Add asset 1
        vm.addAsset(asset1, at: .zero)
        #expect(vm.commandExecutor?.history.count == 1)
        #expect(vm.commandExecutor?.historyIndex == 1)

        // Step 2: Add asset 2
        vm.addAsset(asset2, at: CMTime(value: 6, timescale: 1))
        #expect(vm.commandExecutor?.history.count == 2)
        #expect(vm.commandExecutor?.historyIndex == 2)

        // Time travel to Step 0 (Empty)
        let jumpZero = vm.jumpToHistory(targetIndex: 0)
        #expect(jumpZero == true)
        #expect(vm.layers.isEmpty || vm.layers.allSatisfy { $0.clips.isEmpty })
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == true)

        // Time travel forward to Step 1 (Only asset 1)
        let jumpOne = vm.jumpToHistory(targetIndex: 1)
        #expect(jumpOne == true)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.canUndo == true)
        #expect(vm.canRedo == true)

        // Time travel forward to Step 2 (Both assets)
        let jumpTwo = vm.jumpToHistory(targetIndex: 2)
        #expect(jumpTwo == true)
        #expect(vm.layers[0].clips.count == 2)
        #expect(vm.canUndo == true)
        #expect(vm.canRedo == false)
    }

    @Test("ProjectScript maintains undo/redo capability across export and import")
    func testPersistentUndoRedoAcrossExportAndLoad() {
        let vm1 = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/persistent_undo.mp4"), type: .video)

        // Add asset and split
        vm1.addAsset(asset, at: .zero)
        vm1.splitClips(at: CMTime(value: 2, timescale: 1))
        #expect(vm1.canUndo == true)
        #expect(vm1.commandExecutor?.history.count == 2)

        // Export script
        let script = vm1.exportScript(title: "Persistent Project")
        #expect(script.history.count == 2)
        #expect(script.historyIndex == 2)

        // Open in a new blank session
        let vm2 = TimelineViewModel(initialLayers: [])
        vm2.loadScript(script)

        #expect(vm2.canUndo == true)
        #expect(vm2.commandExecutor?.history.count == 2)
        #expect(vm2.commandExecutor?.historyIndex == 2)

        // Undo Split in new session
        let undoSplit = vm2.undo()
        #expect(undoSplit == true)
        #expect(vm2.layers[0].clips.count == 1)
        #expect(vm2.canUndo == true)
        #expect(vm2.canRedo == true)

        // Undo Add in new session
        let undoAdd = vm2.undo()
        #expect(undoAdd == true)
        #expect(vm2.layers.isEmpty || vm2.layers[0].clips.isEmpty)
        #expect(vm2.canUndo == false)
        #expect(vm2.canRedo == true)

        // Redo Add
        let redoAdd = vm2.redo()
        #expect(redoAdd == true)
        #expect(vm2.layers[0].clips.count == 1)

        // Redo Split
        let redoSplit = vm2.redo()
        #expect(redoSplit == true)
        #expect(vm2.layers[0].clips.count == 2)
        #expect(vm2.canRedo == false)
    }

    @Test("Subsequent operations on split clip maintain deterministic undo/redo across export and import")
    func testSplitSubsequentOperationsUndoRedoAcrossExport() throws {
        let vm1 = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample.mp4"), type: .video)

        // 1. Add clip
        vm1.addAsset(asset, at: .zero)
        #expect(vm1.commandExecutor?.history.count == 1)

        // 2. Split clip at 2s
        let rightIDs = vm1.splitClips(at: CMTime(value: 2, timescale: 1))
        #expect(rightIDs.count == 1)
        #expect(vm1.commandExecutor?.history.count == 2)
        guard let rightID = rightIDs.first else { return }

        // 3. Delete the right clip
        vm1.selectedClipIDs = [rightID]
        vm1.deleteSelectedClips()
        #expect(vm1.commandExecutor?.history.count == 3)
        #expect(vm1.layers[0].clips.count == 1)

        // 4. Export script and serialize to JSON / deserialize
        let exportedScript = vm1.exportScript(title: "Split Delete Project")
        let encoder = JSONEncoder()
        let data = try encoder.encode(exportedScript)
        let decodedScript = try JSONDecoder().decode(ProjectScript.self, from: data)

        // 5. Load script in fresh VM
        let vm2 = TimelineViewModel(initialLayers: [])
        vm2.loadScript(decodedScript)
        #expect(vm2.commandExecutor?.history.count == 3)
        #expect(vm2.commandExecutor?.historyIndex == 3)
        #expect(vm2.layers[0].clips.count == 1)

        // 6. Undo Step 3 (Undo Delete Right Clip)
        let undoDelete = vm2.undo()
        #expect(undoDelete == true)
        #expect(vm2.layers[0].clips.count == 2)
        #expect(vm2.layers[0].clips.contains { $0.id == rightID })

        // 7. Undo Step 2 (Undo Split)
        let undoSplit = vm2.undo()
        #expect(undoSplit == true)
        #expect(vm2.layers[0].clips.count == 1)

        // 8. Undo Step 1 (Undo Add)
        let undoAdd = vm2.undo()
        #expect(undoAdd == true)
        #expect(vm2.layers.isEmpty || vm2.layers[0].clips.isEmpty)
        #expect(vm2.canUndo == false)
        #expect(vm2.canRedo == true)

        // 9. Redo Step 1 (Redo Add)
        let redoAdd = vm2.redo()
        #expect(redoAdd == true)
        #expect(vm2.layers[0].clips.count == 1)

        // 10. Redo Step 2 (Redo Split) -> must restore the right clip with the exact rightID
        let redoSplit = vm2.redo()
        #expect(redoSplit == true)
        #expect(vm2.layers[0].clips.count == 2)
        #expect(vm2.layers[0].clips.contains { $0.id == rightID })

        // 11. Redo Step 3 (Redo Delete Right Clip) -> finds rightID and deletes it successfully!
        let redoDelete = vm2.redo()
        #expect(redoDelete == true)
        #expect(vm2.layers[0].clips.count == 1)
        #expect(vm2.canRedo == false)

        // 12. Verify Undo works again after reaching the top
        let undoAgain = vm2.undo()
        #expect(undoAgain == true)
        #expect(vm2.layers[0].clips.count == 2)
        #expect(vm2.layers[0].clips.contains { $0.id == rightID })

        let redoAgain = vm2.redo()
        #expect(redoAgain == true)
        #expect(vm2.layers[0].clips.count == 1)
    }
}
