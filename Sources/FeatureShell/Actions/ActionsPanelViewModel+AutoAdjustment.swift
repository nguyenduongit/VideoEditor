import Foundation
import Domain

extension ActionsPanelViewModel {
    /// Tính toán thông số cân chỉnh tự động dựa trên phân tích quang phổ thực tế từ khung hình video trên timeline.
    /// Sử dụng `AutoAdjustmentEngine` từ tầng Domain (tuân thủ AGENTS.md Ubiquitous Language & SRP).
    public func computeDynamicAutoAdjustmentJSON(dispatcher: MCPTimelineToolDispatcher) async throws -> String {
        guard let firstVideoClip = timelineViewModel?.layers.flatMap(\.clips).first(where: { $0.kind == .video && $0.mediaURL != nil }) else {
            throw AppError.resourceNotFound(
                String(localized: "No video clip found on the Timeline to analyze color. Please add a video first.")
            )
        }

        let args = "{\"clipId\": \"\(firstVideoClip.id.uuidString)\"}"
        let telemetryStr = try await dispatcher.handleToolCallAsync(
            toolName: "timeline_get_clip_color_telemetry",
            argumentsJSON: args
        )
        guard let data = telemetryStr.data(using: .utf8),
              let telemetry = try? JSONDecoder().decode(ColorTelemetryProfile.self, from: data) else {
            throw AppError.executionFailed(
                String(localized: "Unable to analyze color spectrum from video frame.")
            )
        }

        let result = AutoAdjustmentEngine().computeAdjustment(from: telemetry)
        let dict = makeAutoAdjustmentDict(from: result)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw AppError.executionFailed(
                String(localized: "Unable to initialize color adjustment configuration.")
            )
        }
        return jsonString
    }

    /// Tương thích ngược với tên gọi cũ
    @inlinable
    public func computeDynamicAutoColorJSON(dispatcher: MCPTimelineToolDispatcher) async throws -> String {
        try await computeDynamicAutoAdjustmentJSON(dispatcher: dispatcher)
    }

    private func makeAutoAdjustmentDict(from result: AutoAdjustmentResult) -> [String: Any] {
        let basic = result.basic
        let fullConfig = AdjustmentConfiguration(
            basic: basic,
            hsl: result.hsl,
            effects: EffectsGradingParameters(sharpenAmount: result.sharpenAmount)
        )
        var dict: [String: Any] = [
            "kind": "adjustment",
            "name": String(localized: "Auto Adjustment"),
            "startTimeSeconds": 0.0,
            "exposure": Int(basic.exposure),
            "contrast": Int(basic.contrast),
            "highlight": Int(basic.highlight),
            "shadow": Int(basic.shadow),
            "black": Int(basic.black),
            "white": Int(basic.white),
            "saturation": Int(basic.saturation),
            "brilliance": Int(basic.brilliance),
            "temp": Int(basic.temp),
            "tint": Int(basic.tint),
            "sharpenAmount": Int(result.sharpenAmount)
        ]
        if let configJSON = fullConfig.encodeToJSON() {
            dict["adjustmentConfigJSON"] = configJSON
        }
        return dict
    }
}
