import Foundation
import Domain

extension ActionsPanelViewModel {
    /// Tính toán thông số màu động dựa trên phân tích quang phổ thực tế từ khung hình video trên timeline.
    /// Nếu không có clip video hoặc đo đạc thất bại, sẽ fallback an toàn về bộ thông số trong trẻo mặc định.
    public func computeDynamicAutoColorJSON(dispatcher: MCPTimelineToolDispatcher) async -> String {
        guard let firstVideoClip = timelineViewModel?.layers.first(where: { $0.kind == .video })?.clips.first else {
            return defaultFallbackColorJSON()
        }

        let args = "{\"clipId\": \"\(firstVideoClip.id.uuidString)\"}"
        guard let telemetryStr = try? await dispatcher.handleToolCallAsync(
            toolName: "timeline_get_clip_color_telemetry",
            argumentsJSON: args
        ),
        let data = telemetryStr.data(using: .utf8),
        let telemetry = try? JSONDecoder().decode(ColorTelemetryProfile.self, from: data) else {
            return defaultFallbackColorJSON()
        }

        // 1. Phơi sáng (Exposure): Target độ sáng trung bình 0.50 (50% IRE).
        let lumaDelta = 0.50 - Double(telemetry.averageLuma)
        let autoExposure = Int(max(-18.0, min(25.0, lumaDelta * 70.0)))

        // 2. Vùng tối (Shadow): Tự động nâng sáng vùng tối nếu cảnh bị tối hoặc bết đen.
        var autoShadow = 15
        if telemetry.shadowClippingRatio > 0.02 || telemetry.blackPoint < 0.08 {
            autoShadow = Int(min(35.0, 15.0 + Double(telemetry.shadowClippingRatio * 150.0)))
        }

        // 3. Vùng sáng (Highlight): Tự động hạ sáng nếu có hiện tượng cháy sáng.
        var autoHighlight = -4
        if telemetry.highlightClippingRatio > 0.02 || telemetry.whitePoint > 0.92 {
            autoHighlight = -Int(min(25.0, 6.0 + Double(telemetry.highlightClippingRatio * 100.0)))
        }

        // 4. Cân bằng trắng (White Balance): Triệt tiêu ám màu thực tế (ám vàng/ấm hoặc ám xanh/lạnh).
        let autoTemp = Int(max(-18.0, min(18.0, Double(telemetry.suggestedTempOffset * 0.35))))
        let autoTint = Int(max(-12.0, min(12.0, Double(telemetry.suggestedTintOffset * 0.30))))

        // 5. Độ tương phản (Contrast): Bù trừ theo dải động thực tế của video.
        let autoContrast = telemetry.dynamicRange < 0.70 ? 8 : (telemetry.dynamicRange > 0.90 ? 2 : 5)

        // 6. Tôn sáng & độ sắc nét (Brilliance, Saturation, Sharpen).
        let autoBrilliance = 14
        let autoSaturation = 6
        let autoSharpen = 8

        let dict: [String: Any] = [
            "kind": "adjustment",
            "name": "Cân chỉnh màu tự động",
            "startTimeSeconds": 0.0,
            "exposure": autoExposure,
            "brilliance": autoBrilliance,
            "shadow": autoShadow,
            "highlight": autoHighlight,
            "contrast": autoContrast,
            "saturation": autoSaturation,
            "temp": autoTemp,
            "tint": autoTint,
            "sharpenAmount": autoSharpen
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return defaultFallbackColorJSON()
    }

    private func defaultFallbackColorJSON() -> String {
        "{\"kind\": \"adjustment\", \"name\": \"Cân chỉnh màu tự động\", \"startTimeSeconds\": 0.0, \"exposure\": 8, \"brilliance\": 18, \"shadow\": 20, \"highlight\": -6, \"contrast\": 3, \"saturation\": 5, \"temp\": 2, \"sharpenAmount\": 8}"
    }
}
