import Foundation
import Domain
import CoreMedia
import AVFoundation
@preconcurrency import CoreImage

/// Router and JSON-RPC 2.0 message handler for Model Context Protocol AI agents.
@MainActor
public final class MCPTimelineToolDispatcher: MCPServerDelegate {
    let scriptEngine: TimelineScriptEngine
    public weak var mediaLibraryViewModel: MediaLibraryViewModel?
    public let dependencies: EditorDependencies

    public init(
        scriptEngine: TimelineScriptEngine,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil,
        dependencies: EditorDependencies = EditorDependencies()
    ) {
        self.scriptEngine = scriptEngine
        self.mediaLibraryViewModel = mediaLibraryViewModel
        self.dependencies = dependencies
    }

    public enum ToolName: String, CaseIterable {
        case getTimelineState = "timeline_get_state"
        case getLibraryCatalog = "library_get_catalog"
        case addMediaAsset = "timeline_add_media_asset"
        case syncAudio = "timeline_sync_audio"
        case applyTemplate = "timeline_apply_template"
        case editClip = "timeline_edit_clip"
        case executeCommands = "timeline_execute_commands"
        case loadProjectScript = "timeline_load_project_script"
        case exportProjectScript = "timeline_export_project_script"
        case getClipColorTelemetry = "timeline_get_clip_color_telemetry"
        case aiVisionFraming = "timeline_ai_vision_framing"
    }

    public func handleToolCallAsync(toolName: String, argumentsJSON: String = "{}") async throws -> String {
        if toolName == ToolName.syncAudio.rawValue {
            let assets = mediaLibraryViewModel?.assets ?? []
            let data = argumentsJSON.data(using: .utf8) ?? Data("{}".utf8)
            let dict = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
            let muteVideo = (dict["muteVideo"] as? Bool) ?? true
            let res = await scriptEngine.currentViewModel.performAISyncAudio(availableAssets: assets, muteVideo: muteVideo)
            let status = res.isSuccess ? "success" : "error"
            return "{\"status\":\"\(status)\",\"message\":\"\(res.message)\"}"
        }
        if toolName == ToolName.aiVisionFraming.rawValue {
            let assets = mediaLibraryViewModel?.assets ?? []
            let req = AIVisionFramingRequest.fromJSON(argumentsJSON)
            let res = await scriptEngine.currentViewModel.performAIVisionFraming(request: req, availableAssets: assets)
            let status = res.isSuccess ? "success" : "error"
            return "{\"status\":\"\(status)\",\"message\":\"\(res.message)\"}"
        }
        return try handleToolCall(toolName: toolName, argumentsJSON: argumentsJSON)
    }

    public func handleToolCall(toolName: String, argumentsJSON: String = "{}") throws -> String {
        guard let tool = ToolName(rawValue: toolName) else {
            throw AppError.invalidParameter("Unknown MCP tool: \(toolName)")
        }

        switch tool {
        case .getTimelineState, .exportProjectScript:
            return try scriptEngine.exportProjectJSON(prettyPrinted: true)
        case .getLibraryCatalog:
            return try getLibraryCatalogArgument()
        case .addMediaAsset:
            return try addMediaAssetArgument(argumentsJSON)
        case .syncAudio, .aiVisionFraming:
            return "{\"status\":\"pending_async\"}"
        case .applyTemplate:
            return try applyTemplateArgument(argumentsJSON)
        case .editClip:
            return try editClipArgument(argumentsJSON)
        case .executeCommands:
            return try executeCommandsArgument(argumentsJSON)
        case .loadProjectScript:
            return try loadProjectArgument(argumentsJSON)
        case .getClipColorTelemetry:
            return try getClipColorTelemetryArgument(argumentsJSON)
        }
    }

    private func executeCommandsArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw AppError.invalidParameter("Invalid arguments JSON encoding")
        }

        let commands: [TimelineCommand]
        if let directCommands = try? JSONDecoder().decode([TimelineCommand].self, from: data) {
            commands = directCommands
        } else if let container = try? JSONDecoder().decode(CommandPayload.self, from: data) {
            commands = container.commands
        } else {
            throw AppError.invalidParameter("Cannot decode commands from arguments")
        }

        let result = scriptEngine.executeCommands(commands)
        let resData = try JSONEncoder().encode(result)
        return String(decoding: resData, as: UTF8.self)
    }

    private func loadProjectArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw AppError.invalidParameter("Invalid arguments JSON")
        }

        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let projectObj = dict["project"] {
            let projectData = try JSONSerialization.data(withJSONObject: projectObj)
            let projectStr = String(decoding: projectData, as: UTF8.self)
            try scriptEngine.loadProjectJSON(projectStr)
        } else {
            try scriptEngine.loadProjectJSON(argumentsJSON)
        }
        return "{\"status\": \"success\"}"
    }

    private func getClipColorTelemetryArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let clipId = dict["clipId"] as? String else {
            throw AppError.invalidParameter("Missing required parameter: clipId")
        }

        let vm = scriptEngine.currentViewModel
        var targetClip: TimelineClip?
        for layer in vm.layers {
            if let c = layer.clips.first(where: { $0.id.uuidString == clipId || $0.name == clipId }) {
                targetClip = c
                break
            }
        }

        guard let clip = targetClip else {
            throw AppError.invalidParameter("Clip not found with ID: \(clipId)")
        }

        let telemetry: ColorTelemetryProfile
        if let mediaURL = clip.mediaURL {
            let sampleTime = CMTimeAdd(clip.sourceStartTime, CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: 0.5))
            if let image = extractImageSynchronously(from: mediaURL, at: sampleTime) {
                telemetry = HistogramEngine.shared.analyzeTelemetry(from: image)
            } else {
                telemetry = ColorTelemetryProfile()
            }
        } else {
            telemetry = ColorTelemetryProfile()
        }

        let resData = try JSONEncoder().encode(telemetry)
        return String(decoding: resData, as: UTF8.self)
    }

    private func extractImageSynchronously(from url: URL, at time: CMTime) -> CIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }

    // MARK: - MCPServerDelegate (JSON-RPC 2.0)

    public func handleJSONRPCMessage(_ message: String) async -> String? {
        guard let data = message.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return formatJSONRPCError(id: nil, error: .parseError)
        }

        let id = json["id"]
        guard let method = json["method"] as? String else {
            return formatJSONRPCError(id: id, error: .invalidRequest)
        }

        if method == "notifications/initialized" {
            return nil
        }

        return await routeMethod(method, id: id, params: json["params"] as? [String: Any])
    }

    private func routeMethod(_ method: String, id: Any?, params: [String: Any]?) async -> String {
        switch method {
        case "initialize":
            return formatInitializeResponse(id: id)
        case "ping":
            return formatResultResponse(id: id, result: [:])
        case "tools/list":
            return formatToolsListResponse(id: id)
        case "tools/call":
            return await handleToolsCallMethod(id: id, params: params)
        default:
            return formatJSONRPCError(
                id: id,
                error: MCPErrorResponse(code: -32601, message: "Method not found: \(method)")
            )
        }
    }

    private func formatInitializeResponse(id: Any?) -> String {
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": ["listChanged": false]
            ],
            "serverInfo": [
                "name": "video-editor-timeline",
                "version": "1.0.0"
            ]
        ]
        return formatResultResponse(id: id, result: result)
    }

    private func formatToolsListResponse(id: Any?) -> String {
        let toolsArray = MCPToolSchemas.toolList.compactMap { tool -> [String: Any]? in
            guard let schemaData = tool.inputSchema.data(using: .utf8),
                  let schemaObj = try? JSONSerialization.jsonObject(with: schemaData) else {
                return nil
            }
            return [
                "name": tool.name,
                "description": tool.description,
                "inputSchema": schemaObj
            ]
        }
        return formatResultResponse(id: id, result: ["tools": toolsArray])
    }

    private func handleToolsCallMethod(id: Any?, params: [String: Any]?) async -> String {
        guard let params, let toolName = params["name"] as? String else {
            return formatJSONRPCError(id: id, error: .invalidParams)
        }

        let argsJSON: String
        if let argsObj = params["arguments"] {
            if let str = argsObj as? String {
                argsJSON = str
            } else if let data = try? JSONSerialization.data(withJSONObject: argsObj) {
                argsJSON = String(decoding: data, as: UTF8.self)
            } else {
                argsJSON = "{}"
            }
        } else {
            argsJSON = "{}"
        }

        do {
            let output = try handleToolCall(toolName: toolName, argumentsJSON: argsJSON)
            let result: [String: Any] = [
                "content": [["type": "text", "text": output]],
                "isError": false
            ]
            return formatResultResponse(id: id, result: result)
        } catch {
            let result: [String: Any] = [
                "content": [["type": "text", "text": "Error: \(error.localizedDescription)"]],
                "isError": true
            ]
            return formatResultResponse(id: id, result: result)
        }
    }

    private func formatResultResponse(id: Any?, result: [String: Any]) -> String {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"jsonrpc\":\"2.0\",\"id\":null,\"result\":{}}"
        }
        return str
    }

    private func formatJSONRPCError(id: Any?, error: MCPErrorResponse) -> String {
        let errorObj: [String: Any] = [
            "code": error.code,
            "message": error.message
        ]
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": errorObj
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32603,\"message\":\"Internal error\"}}"
        }
        return str
    }
}

private struct CommandPayload: Codable {
    let commands: [TimelineCommand]
}
