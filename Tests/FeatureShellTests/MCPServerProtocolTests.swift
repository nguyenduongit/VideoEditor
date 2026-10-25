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
        #expect(response?.contains("timeline_get_clip_color_telemetry") == true)
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

    @Test func testMCPLibraryCatalogAndApplyTemplateToolsKeepSelectionEmpty() throws {
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let catalogJSON = try dispatcher.handleToolCall(toolName: "library_get_catalog")
        #expect(catalogJSON.contains("textTemplates"))
        #expect(catalogJSON.contains("adjustmentTemplates"))
        #expect(catalogJSON.contains("cinematic"))

        let applyTextArgs = """
        {"kind":"text","templateId":"neon_cyber_pulse","customText":"TÌNH CA NGƯỜI ĐI BIỂN","textColorHex":"#FFE66D","strokeColorHex":"#023047","strokeWidth":4.0,"glowColorHex":"#00F5D4","glowRadius":18.0,"inAnimation":"wave3D","startTimeSeconds":1.0,"durationSeconds":3.0}
        """
        let textRes = try dispatcher.handleToolCall(toolName: "timeline_apply_template", argumentsJSON: applyTextArgs)
        #expect(textRes.contains("success"))
        #expect(vm.selectedClipIDs.isEmpty)

        let applyAdjArgs = """
        {"kind":"adjustment","templateId":"vivid","shadow":28.0,"brilliance":24.0,"exposure":5.0,"startTimeSeconds":0.0,"durationSeconds":4.0}
        """
        let adjRes = try dispatcher.handleToolCall(toolName: "timeline_apply_template", argumentsJSON: applyAdjArgs)
        #expect(adjRes.contains("success"))
        #expect(vm.selectedClipIDs.isEmpty)
        #expect(vm.layers.contains(where: { $0.kind == .adjustment }))

        let agentService = GeminiEditAgentService(dispatcher: dispatcher)
        let declarations = agentService.buildFunctionDeclarations()
        #expect(declarations.count == MCPToolSchemas.toolList.count)
        for decl in declarations {
            let params = decl["parameters"] as? [String: Any]
            let props = params?["properties"] as? [String: Any]
            #expect(props != nil && !(props?.isEmpty ?? true))
            if let commandsProp = props?["commands"] as? [String: Any] {
                #expect(commandsProp["items"] != nil)
            }
        }

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        #expect(inspectorVM.selectedClip == nil)
        #expect(!inspectorVM.aiChatViewModel.messages.isEmpty)
        inspectorVM.aiChatViewModel.undoLastChange()
        #expect(inspectorVM.aiChatViewModel.messages.last?.toolBadges == ["Undo"])
    }

    @Test func testMCPAIVisionFramingToolConfiguresAutoPanScaleAndLegStretch() async throws {
        let vm = TimelineViewModel(initialLayers: [])
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/dancer.mp4"), type: .video)
        vm.addAsset(videoAsset, at: .zero)
        vm.selectedClipIDs.removeAll()

        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let args = """
        {"enableAutoPan":true,"enableLegStretch":true,"legStretchRatio":1.15,"targetSubjectHeightRatio":0.33,"centerSubject":true}
        """
        let res = try await dispatcher.handleToolCallAsync(toolName: "timeline_ai_vision_framing", argumentsJSON: args)
        #expect(res.contains("\"status\":\"success\""))

        let clip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .video })
        let gridStr = clip?.properties["gridConfig"]?.asString ?? ""
        let gridCfg = GridConfiguration.decode(from: gridStr)
        #expect(gridCfg?.isEnabled == true)
        #expect(gridCfg?.isDynamicLines == true)
        #expect(abs((gridCfg?.legStretchRatio ?? 1.0) - 1.15) < 0.001)

        let autoPanStr = clip?.properties["autoPanConfig"]?.asString ?? ""
        let autoPanCfg = AutoPanConfiguration.decode(from: autoPanStr)
        #expect(autoPanCfg?.isEnabled == true)
    }
}
