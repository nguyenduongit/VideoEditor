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
        let samplePreset = AdjustmentPreset(id: "cinematic", name: "Cinematic", description: "Test Preset", config: AdjustmentConfiguration())
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine, dependencies: vm.dependencies)
        vm.dependencies.adjustmentTemplates.updateInMemoryPreset(samplePreset)

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

        #expect(!MCPToolSchemas.toolList.isEmpty)
        for tool in MCPToolSchemas.toolList {
            #expect(!tool.name.isEmpty)
            #expect(!tool.description.isEmpty)
            #expect(!tool.inputSchema.isEmpty)
        }

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        #expect(inspectorVM.selectedClip == nil)
        #expect(inspectorVM.actionsPanelViewModel.tasks.count == 5)
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

    @Test func testMCPTextPropertyResolverFontAndAnimationMatching() async {
        let font1 = MCPTextPropertyResolver.resolveFontName("UVN Bay Buom")
        #expect(font1.contains("Bay") || font1 == "UVNBayBuom")

        let font2 = MCPTextPropertyResolver.resolveFontName("da lat")
        #expect(font2.localizedCaseInsensitiveContains("da") || font2 == "UVNDaLat")

        let inAnim = MCPTextPropertyResolver.resolveInAnimation("vortex spin")
        #expect(inAnim == .whipRight || inAnim == .slideUp)

        let outAnim = MCPTextPropertyResolver.resolveOutAnimation("pixelate")
        #expect(outAnim == .fadeOut)

        let loopAnim = MCPTextPropertyResolver.resolveLoopAnimation("neon pulse")
        #expect(loopAnim == .flicker)
    }

    @Test func testMCPApplyTemplateAppliesCustomFontAndBackground() async throws {
        let vm = TimelineViewModel(initialLayers: [])
        let engine = TimelineScriptEngine(viewModel: vm)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        // 1. Check catalog returns availableFonts
        let catalog = try await dispatcher.handleToolCallAsync(toolName: "library_get_catalog", argumentsJSON: "{}")
        #expect(catalog.contains("availableFonts"))

        // 2. Apply template with artistic font and background
        let args = """
        {
          "kind": "text",
          "customText": "Lời Tự Tình Mùa Thu",
          "fontName": "UVN Bay Buom",
          "fontSize": 58,
          "hasBackground": true,
          "backgroundColorHex": "#000000",
          "backgroundOpacity": 0.75,
          "inAnimation": "slideUp",
          "outAnimation": "slideDown",
          "motionEasing": "Bounce"
        }
        """
        let res = try await dispatcher.handleToolCallAsync(toolName: "timeline_apply_template", argumentsJSON: args)
        #expect(res.contains("\"status\":\"success\""))

        let textClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text })
        #expect(textClip != nil)
        let json = textClip?.properties["textConfig"]?.asString ?? ""
        let cfg = TextConfiguration.decode(from: json)
        #expect(cfg != nil)
        #expect(cfg?.content == "Lời Tự Tình Mùa Thu")
        #expect(cfg?.fontName.contains("Bay") == true)
        #expect(cfg?.hasBackground == true)
        #expect(cfg?.animation.inType == .slideUp)
        #expect(cfg?.animation.outType == .dropDown)
        #expect(cfg?.animation.motionEasing == .bounce)
    }
}
