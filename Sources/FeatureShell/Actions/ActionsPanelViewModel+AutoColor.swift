import Foundation
import Domain

extension ActionsPanelViewModel {
    /// Tính toán thông số màu động dựa trên phân tích quang phổ thực tế từ khung hình video trên timeline.
    /// Sử dụng `AutoColorEngine` từ tầng Domain (tuân thủ R2.3, R3.1).
    public func computeDynamicAutoColorJSON(dispatcher: MCPTimelineToolDispatcher) async throws -> String {
        guard let firstVideoClip = timelineViewModel?.layers.flatMap(\.clips).first(where: { $0.kind == .video && $0.mediaURL != nil }) else {
            throw AppError.resourceNotFound(
                String(localized: "Chưa có clip video trên Timeline để phân tích màu sắc. Vui lòng thêm video vào Timeline trước.")
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
                String(localized: "Không thể phân tích quang phổ màu sắc từ khung hình video.")
            )
        }

        let result = AutoColorEngine().computeAdjustment(from: telemetry)
        let dict = makeAutoColorAdjustmentDict(from: result)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw AppError.executionFailed(
                String(localized: "Không thể khởi tạo cấu hình màu sắc.")
            )
        }
        return jsonString
    }

    private func makeAutoColorAdjustmentDict(from result: AutoColorAdjustmentResult) -> [String: Any] {
        let basic = result.basic
        return [
            "kind": "adjustment",
            "name": String(localized: "Cân chỉnh màu tự động"),
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
    }
}
