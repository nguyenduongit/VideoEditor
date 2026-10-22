import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("MCPServerProtocolTests")
@MainActor
struct MCPServerProtocolTests {
    @Test func testMCPInitializeMethod() async {
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let initReq = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
        """

        let response = await dispatcher.handleJSONRPCMessage(initReq)
        #expect(response != nil)
        #expect(response?.contains("protocolVersion") == true)
        #expect(response?.contains("video-editor-timeline") == true)
    }

    @Test func testMCPToolsListMethod() async {
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let listReq = """
        {"jsonrpc":"2.0","id":"req-2","method":"tools/list","params":{}}
        """

        let response = await dispatcher.handleJSONRPCMessage(listReq)
        #expect(response != nil)
        #expect(response?.contains("timeline_get_state") == true)
        #expect(response?.contains("timeline_execute_commands") == true)
        #expect(response?.contains("timeline_export_project_script") == true)
        #expect(response?.contains("timeline_load_project_script") == true)
    }

    @Test func testMCPToolsCallExecuteCommands() async throws {
        let layerID = UUID()
        let layer = TimelineLayer(id: layerID, name: "V1", kind: .video)
        let vm = TimelineViewModel(initialLayers: [layer])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let clip = ClipScript(
            name: "MCP Remote Clip",
            kind: .video,
            source: .color(hex: "#FF0000"),
            timelineRange: RationalTimeRange(
                start: RationalTime(value: 0, timescale: 30),
                duration: RationalTime(value: 60, timescale: 30)
            )
        )
        let cmd = TimelineCommand.addClip(layerID: layerID, clip: clip)
        let cmdData = try JSONEncoder().encode([cmd])
        let cmdJson = String(decoding: cmdData, as: UTF8.self)

        let toolCallReq = """
        {
          "jsonrpc": "2.0",
          "id": 100,
          "method": "tools/call",
          "params": {
            "name": "timeline_execute_commands",
            "arguments": \(cmdJson)
          }
        }
        """

        let response = await dispatcher.handleJSONRPCMessage(toolCallReq)
        #expect(response != nil)
        #expect(response?.contains("\"isError\":false") == true)
        #expect(vm.layers[0].clips.count == 1)
        if !vm.layers[0].clips.isEmpty {
            #expect(vm.layers[0].clips[0].name == "MCP Remote Clip")
        }
    }

    @Test func testMCPUnknownMethodReturnsError() async {
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let req = """
        {"jsonrpc":"2.0","id":999,"method":"non_existent_method","params":{}}
        """

        let response = await dispatcher.handleJSONRPCMessage(req)
        #expect(response != nil)
        #expect(response?.contains("-32601") == true)
    }
}
