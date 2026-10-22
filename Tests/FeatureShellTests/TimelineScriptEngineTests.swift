import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineScriptEngineTests")
@MainActor
struct TimelineScriptEngineTests {
    @Test("TimelineScriptEngine executes JSON command script")
    func testExecuteJSONScript() throws {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let engine = TimelineScriptEngine(viewModel: vm)

        let clip = ClipScript(
            name: "Scripted Block",
            kind: .video,
            source: .file(url: URL(fileURLWithPath: "/tmp/scripted.mp4")),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 90, timescale: 30) // 3 seconds
            )
        )

        let commands = [TimelineCommand.addClip(layerID: layerID, clip: clip)]
        let jsonData = try JSONEncoder().encode(commands)
        let jsonString = String(decoding: jsonData, as: UTF8.self)

        let result = try engine.executeScriptJSON(jsonString)
        #expect(result.isSuccess == true)
        #expect(result.executedCommandsCount == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Scripted Block")
    }

    @Test("TimelineScriptEngine exports and loads project JSON")
    func testExportAndLoadProjectJSON() throws {
        let layer = TimelineLayer(name: "A1", kind: .audio)
        let vm = TimelineViewModel(initialLayers: [layer])
        let engine = TimelineScriptEngine(viewModel: vm)

        let exportedJSON = try engine.exportProjectJSON(title: "Exported Project")
        #expect(exportedJSON.contains("Exported Project"))
        #expect(exportedJSON.contains("A1"))

        let newVM = TimelineViewModel()
        let newEngine = TimelineScriptEngine(viewModel: newVM)
        try newEngine.loadProjectJSON(exportedJSON)

        #expect(newVM.layers.count == 1)
        #expect(newVM.layers[0].name == "A1")
        #expect(newVM.layers[0].kind == .audio)
    }

    @Test("MCPTimelineToolDispatcher handles get_state and execute_commands")
    func testMCPToolDispatcher() throws {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        // 1. Tool: timeline_get_state
        let stateJSON = try dispatcher.handleToolCall(toolName: "timeline_get_state")
        #expect(stateJSON.contains("schemaVersion"))
        #expect(stateJSON.contains("V1"))

        // 2. Tool: timeline_execute_commands
        let clip = ClipScript(
            name: "AI Generated Clip",
            kind: .video,
            source: .color(hex: "#123456"),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 60, timescale: 30)
            )
        )
        let commands = [TimelineCommand.addClip(layerID: layerID, clip: clip)]
        let cmdJSONData = try JSONEncoder().encode(commands)
        let cmdJSONString = String(decoding: cmdJSONData, as: UTF8.self)

        let execResultJSON = try dispatcher.handleToolCall(
            toolName: "timeline_execute_commands",
            argumentsJSON: cmdJSONString
        )
        #expect(execResultJSON.contains("\"isSuccess\":true"))
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "AI Generated Clip")
    }

    @Test("AI and Script commands share unified undo/redo with TimelineViewModel and UI Cmd+Z")
    func testUnifiedUndoRedoBetweenScriptEngineAndUI() throws {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let engine = TimelineScriptEngine(viewModel: vm)

        #expect(vm.canUndo == false)
        #expect(vm.canRedo == false)

        let clip = ClipScript(
            name: "Agent Clip",
            kind: .video,
            source: .color(hex: "#FF0000"),
            timelineRange: RationalTimeRange(start: RationalTime(value: 0, timescale: 30), duration: RationalTime(value: 30, timescale: 30))
        )
        let result = engine.executeCommands([.addClip(layerID: layerID, clip: clip)])
        #expect(result.isSuccess == true)
        #expect(vm.layers[0].clips.count == 1)

        // Unified undo stack: viewModel reflects AI command immediately
        #expect(vm.canUndo == true)
        #expect(vm.canRedo == false)

        // User triggers Cmd+Z on UI
        let didUndo = vm.undo()
        #expect(didUndo == true)
        #expect(vm.layers[0].clips.isEmpty)
        #expect(vm.canUndo == false)
        #expect(vm.canRedo == true)

        // User triggers Redo on UI
        let didRedo = vm.redo()
        #expect(didRedo == true)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Agent Clip")
    }
}

