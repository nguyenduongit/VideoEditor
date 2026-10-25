import Foundation
import Domain

/// Kết quả trả về sau 1 lượt hội thoại đa bước (Multi-turn Function Calling) với Gemini AI.
public struct GeminiAgentTurnResult: Sendable, Equatable {
    public let replyText: String
    public let executedToolBadges: [String]

    public init(replyText: String, executedToolBadges: [String] = []) {
        self.replyText = replyText
        self.executedToolBadges = executedToolBadges
    }
}

/// Dịch vụ kết nối trực tiếp Gemini REST API (`generateContent`) với bộ công cụ MCP (`MCPTimelineToolDispatcher`).
/// Lưu trữ ngữ cảnh hội thoại đa lượt (`conversationContents`) giúp người dùng tinh chỉnh liên tục qua nhiều câu lệnh.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R5.4 (Typed Errors, không force unwrap).
@MainActor
public final class GeminiEditAgentService {
    private let dispatcher: MCPTimelineToolDispatcher
    private var conversationContents: [[String: Any]] = []
    private let maxToolRounds = 8

    public init(dispatcher: MCPTimelineToolDispatcher) {
        self.dispatcher = dispatcher
    }

    public func clearHistory() {
        conversationContents.removeAll()
    }

    public var historyTurnCount: Int {
        conversationContents.count
    }

    public func sendUserMessage(
        _ text: String,
        apiKey: String,
        model: String = "gemini-2.5-flash"
    ) async throws -> GeminiAgentTurnResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw AppError.invalidParameter("Chưa cấu hình Gemini API Key.")
        }

        let snapshotCount = conversationContents.count
        let userMessage: [String: Any] = [
            "role": "user",
            "parts": [["text": text]]
        ]
        conversationContents.append(userMessage)

        var executedBadges: [String] = []
        var round = 0

        do {
            while round < maxToolRounds {
                round += 1
                let responseDict = try await performGenerateContentRequest(apiKey: trimmedKey, model: model)
                let candidateContent = try extractModelContent(from: responseDict)
                conversationContents.append(candidateContent)

                let parts = (candidateContent["parts"] as? [[String: Any]]) ?? []
                let functionCalls = parts.compactMap { $0["functionCall"] as? [String: Any] }

                if functionCalls.isEmpty {
                    let finalText = parts.compactMap { $0["text"] as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallback = finalText.isEmpty ? "Đã hoàn tất thực hiện yêu cầu trên Timeline." : finalText
                    return GeminiAgentTurnResult(replyText: fallback, executedToolBadges: executedBadges)
                }

                let responseParts = await executeFunctionCalls(functionCalls, badges: &executedBadges)
                let toolResponseContent: [String: Any] = [
                    "role": "user",
                    "parts": responseParts
                ]
                conversationContents.append(toolResponseContent)
            }
        } catch {
            if conversationContents.count > snapshotCount {
                conversationContents.removeSubrange(snapshotCount..<conversationContents.count)
            }
            throw error
        }

        return GeminiAgentTurnResult(
            replyText: "Đã thực hiện các bước chỉnh sửa trên Timeline theo yêu cầu của bạn.",
            executedToolBadges: executedBadges
        )
    }

    private func executeFunctionCalls(
        _ calls: [[String: Any]],
        badges: inout [String]
    ) async -> [[String: Any]] {
        var responseParts: [[String: Any]] = []
        for call in calls {
            let name = (call["name"] as? String) ?? ""
            let argsObj = call["args"] ?? [:]
            let argsData = (try? JSONSerialization.data(withJSONObject: argsObj)) ?? Data("{}".utf8)
            let argsJSON = String(decoding: argsData, as: UTF8.self)

            let outputText: String
            do {
                outputText = try await dispatcher.handleToolCallAsync(toolName: name, argumentsJSON: argsJSON)
                badges.append(humanReadableBadge(for: name, args: argsObj as? [String: Any]))
            } catch {
                outputText = "{\"error\": \"\(error.localizedDescription)\"}"
            }

            let parsedResult = (try? JSONSerialization.jsonObject(with: Data(outputText.utf8))) ?? ["output": outputText]
            let functionResponse: [String: Any] = [
                "name": name,
                "response": ["result": parsedResult]
            ]
            responseParts.append(["functionResponse": functionResponse])
        }
        return responseParts
    }

    private func humanReadableBadge(for toolName: String, args: [String: Any]?) -> String {
        switch toolName {
        case "timeline_get_state":
            return "Đọc Timeline"
        case "library_get_catalog":
            return "Tra cứu Media & Templates"
        case "timeline_add_media_asset":
            let name = (args?["fileName"] as? String) ?? "Media"
            return "Thêm \(name)"
        case "timeline_sync_audio":
            return "Đồng bộ Nhạc & Cắt phần thừa"
        case "timeline_apply_template":
            let kind = (args?["kind"] as? String) ?? ""
            if kind == "text" {
                let text = (args?["customText"] as? String) ?? (args?["templateId"] as? String) ?? "Chữ"
                return "Chữ: \(text)"
            }
            let id = (args?["templateId"] as? String) ?? "Màu sắc"
            return "Chỉnh màu: \(id)"
        case "timeline_edit_clip":
            let op = (args?["operation"] as? String) ?? "Edit"
            return "Biên tập (\(op))"
        case "timeline_execute_commands":
            return "Cập nhật Timeline"
        case "timeline_get_clip_color_telemetry":
            return "Phân tích màu"
        case "timeline_ai_vision_framing":
            return "AI Vision: Căn khung & Chiều cao"
        default:
            return toolName
        }
    }

    private func performGenerateContentRequest(apiKey: String, model: String) async throws -> [String: Any] {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AppError.invalidParameter("URL Gemini API không hợp lệ.")
        }

        let requestBody: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": Self.systemPrompt]]
            ],
            "contents": conversationContents,
            "tools": [
                ["functionDeclarations": buildFunctionDeclarations()]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errText = String(decoding: data, as: UTF8.self)
            throw AppError.transportError("Gemini API lỗi (\(httpResponse.statusCode)): \(errText.prefix(180))")
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AppError.transportError("Không thể đọc phản hồi JSON từ Gemini API.")
        }
        return json
    }

    private func extractModelContent(from responseDict: [String: Any]) throws -> [String: Any] {
        guard let candidates = responseDict["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any] else {
            throw AppError.transportError("Gemini API không trả về nội dung hợp lệ.")
        }
        return content
    }

    public func buildFunctionDeclarations() -> [[String: Any]] {
        MCPToolSchemas.toolList.compactMap { tool in
            guard let data = tool.inputSchema.data(using: .utf8),
                  let schemaObj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return nil
            }
            return [
                "name": tool.name,
                "description": tool.description,
                "parameters": schemaObj
            ]
        }
    }

    private static let systemPrompt = """
    Bạn là Trợ lý Dựng phim AI chuyên nghiệp trong ứng dụng VideoEditor trên macOS.
    Bạn điều khiển trực tiếp Timeline qua các công cụ (tools) và hỗ trợ hội thoại nhiều lượt (multi-turn).

    HƯỚNG DẪN SỬ DỤNG CÔNG CỤ:
    1. Đồng bộ nhạc, tắt tiếng video gốc và cắt bỏ phần thừa ở cả 2 đầu của video và audio:
       - Gọi `timeline_sync_audio(muteVideo: true, trimExcessTail: true)`: công cụ này tự động đưa Video và Audio từ Media Library xuống Timeline (nếu chưa có), khớp sóng âm thanh (Waveform Alignment), tắt tiếng track video gốc (`muteVideo: true`), và tự động cắt gọn phần thừa ở CẢ 2 ĐẦU của cả Video lẫn Audio để bắt đầu tại 00:00 và kết thúc cùng lúc.
    2. Chỉnh màu sắc (Tự tính toán thông số, KHÔNG dùng template trừ khi người dùng nêu tên template):
       - Gọi `timeline_apply_template` với `kind: "adjustment"` và KHÔNG truyền `templateId` (để tạo lớp `"Tùy chỉnh Màu AI"` nguyên bản), sau đó truyền trực tiếp các thông số chỉnh màu:
         `exposure`, `contrast`, `highlight`, `shadow`, `white`, `black`, `saturation`, `brilliance`, `temp`, `vignetteAmount`, `sharpenAmount`.
       - Nếu người dùng yêu cầu "chỉnh màu tươi sáng, không quá tương phản, không quá đậm màu, và phải chân thực": thiết lập nhẹ nhàng, tự nhiên như `exposure: 8`, `brilliance: 18`, `shadow: 20`, `highlight: -6`, `contrast: 3`, `saturation: 5`, `temp: 2`, `sharpenAmount: 8`.
       - Khi người dùng yêu cầu chỉnh tiếp ở lượt sau, truyền `updateExisting: true` kèm các thông số cần thay đổi.
    3. Tạo hoặc sửa Tiêu đề / Phụ đề chữ (Tự thiết kế thông số, KHÔNG truyền `templateId` trừ khi được yêu cầu):
       - Gọi `timeline_apply_template` với `kind: "text"` và KHÔNG truyền `templateId`, truyền trực tiếp:
         `customText` (giữ nguyên đầy đủ dấu Tiếng Việt, VD: `"Tình Ca Người Đi Biển"`), `fontSize` (VD: `62`), `textColorHex` (màu chữ sáng rõ dễ nhìn, VD: `"#FFFFFF"` hoặc `"#FFFDF7"`), `strokeColorHex` & `strokeWidth` (viền chữ tương phản rõ nét, VD: `"#0B2545"` hoặc `"#0F172A"`, `strokeWidth: 4.5`), `glowColorHex` & `glowRadius` (glow hài hòa dịu mắt, VD: `"#38BDF8"` hoặc `"#FDE68A"`, `glowRadius: 16`), `inAnimation` (`'springDrop'`, `'wave3D'`, `'elasticScale'`), `loopAnimation` (`'wave'`, `'float'`), `positionX: 0`, `positionY: -180`, `durationSeconds: 6.0`.
       - Khi người dùng muốn chỉnh sửa chữ đã tạo ở lượt sau, truyền `updateExisting: true`.
    4. Nhận diện nhân vật bằng Apple Vision: Tự động căn tâm (Auto Pan), Scale nhân vật theo chiều cao khung hình, và Kéo dài chân / Chỉnh chiều cao chuẩn:
       - Gọi `timeline_ai_vision_framing`: công cụ này dùng Apple Vision (`VNDetectHumanBodyPoseRequest`) quét các khung hình để xác định chính xác vị trí nhân vật, đường Thắt lưng (Waist) và đường Mắt cá chân (Ankle).
       - Truyền `enableAutoPan: true` và `centerSubject: true` khi người dùng muốn giữ nhân vật ở giữa khung hình.
       - Truyền `targetSubjectHeightRatio: 0.33` khi muốn chiều cao nhân vật khoảng 1/3 chiều cao khung hình (`0.5` cho 1/2 khung hình).
       - Truyền `enableLegStretch: true` và `legStretchRatio: 1.12` (trong khoảng `0.90` đến `1.30`) khi người dùng yêu cầu "cân chỉnh chiều cao nhân vật (kéo chân) để có chiều cao chuẩn".
    5. Cắt (split), gọt thời lượng (trim), xóa (remove) hoặc đổi khung hình (setAspectRatio):
       - Dùng `timeline_edit_clip` với `operation: 'split' | 'trim' | 'remove' | 'setAspectRatio'`.
    6. Khi nhận yêu cầu tổng hợp gồm nhiều gạch đầu dòng, hãy gọi đầy đủ tất cả các công cụ tương ứng (`timeline_sync_audio`, `timeline_ai_vision_framing`, `timeline_apply_template(kind: "text")`, `timeline_apply_template(kind: "adjustment")`) rồi trả lời ngắn gọn, rõ ràng bằng tiếng Việt.
    """
}
