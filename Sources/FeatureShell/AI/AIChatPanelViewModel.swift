import Foundation
import Observation
import Domain

/// Một tin nhắn trong khung hội thoại đa lượt với Trợ lý AI Dựng phim.
public struct AIChatMessage: Identifiable, Sendable, Equatable {
    public enum Role: String, Sendable, Equatable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public let text: String
    public let toolBadges: [String]
    public let isError: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        toolBadges: [String] = [],
        isError: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.toolBadges = toolBadges
        self.isError = isError
        self.timestamp = timestamp
    }
}

/// Quản lý trạng thái hội thoại đa lượt (Multi-turn AI Chat) ở Sidebar phải khi chưa chọn clip nào.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R3.2 (@Observable).
@Observable
@MainActor
public final class AIChatPanelViewModel {
    private static let apiKeyStorageKey = "ve_gemini_api_key"
    private static let modelStorageKey = "ve_gemini_model"

    public static let availableModels: [(id: String, label: String)] = [
        ("gemini-2.5-flash", "Gemini 2.5 Flash"),
        ("gemini-2.5-pro", "Gemini 2.5 Pro")
    ]

    public static let standardQuickWorkflowPrompt = """
    - Đồng bộ nhạc, tắt tiếng video, cắt bỏ phần thừa của video và audio.
    - Cân chỉnh nhân vật vào giữa khung hình, chiều cao nhân vật khoảng 1/3 chiều cao khung hình.
    - Cân chỉnh chiều cao nhân vật (kéo chân) để có chiều cao chuẩn.
    - Thêm tiêu đề "Tình Ca Người Đi Biển". Font chữ đẹp dễ nhìn, viền chữ tương phản, glow hài hòa, hiệu ứng đẹp mắt.
    - Chỉnh màu tươi sáng, không quá tương phản, không quá đậm màu, và phải chân thực.
    """

    public weak var timelineViewModel: TimelineViewModel?
    public weak var mediaLibraryViewModel: MediaLibraryViewModel? {
        didSet {
            dispatcher?.mediaLibraryViewModel = mediaLibraryViewModel
        }
    }

    public var messages: [AIChatMessage] = []
    public var inputText: String = ""
    public var isProcessing: Bool = false
    public var isEditingAPIKey: Bool = false
    public var draftAPIKey: String = ""

    public var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: Self.apiKeyStorageKey)
        }
    }

    public var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: Self.modelStorageKey)
        }
    }

    private var dispatcher: MCPTimelineToolDispatcher?
    private var agentService: GeminiEditAgentService?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        self.mediaLibraryViewModel = mediaLibraryViewModel

        let savedKey = UserDefaults.standard.string(forKey: Self.apiKeyStorageKey)
            ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            ?? ""
        self.apiKey = savedKey
        self.draftAPIKey = savedKey
        self.selectedModel = UserDefaults.standard.string(forKey: Self.modelStorageKey) ?? "gemini-2.5-flash"

        if let timelineViewModel {
            configureDependencies(timelineViewModel: timelineViewModel, mediaLibraryViewModel: mediaLibraryViewModel)
        }
        appendWelcomeMessageIfNeeded()
    }

    public func configureDependencies(
        timelineViewModel: TimelineViewModel,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        if let mediaLibraryViewModel {
            self.mediaLibraryViewModel = mediaLibraryViewModel
        }
        let engine = TimelineScriptEngine(viewModel: timelineViewModel)
        let toolDispatcher = MCPTimelineToolDispatcher(
            scriptEngine: engine,
            mediaLibraryViewModel: self.mediaLibraryViewModel
        )
        self.dispatcher = toolDispatcher
        self.agentService = GeminiEditAgentService(dispatcher: toolDispatcher)
    }

    public var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func saveAPIKey() {
        apiKey = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingAPIKey = false
    }

    public func clearConversation() {
        agentService?.clearHistory()
        messages.removeAll()
        appendWelcomeMessageIfNeeded()
    }

    public func undoLastChange() {
        guard let timelineViewModel, timelineViewModel.undo() else { return }
        timelineViewModel.selectedClipIDs.removeAll()
        messages.append(
            AIChatMessage(
                role: .assistant,
                text: "Đã hoàn tác (Undo) thao tác chỉnh sửa gần nhất trên Timeline.",
                toolBadges: ["Undo"]
            )
        )
    }

    public func sendPrompt(_ customPrompt: String? = nil) {
        let prompt = (customPrompt ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isProcessing else { return }

        if customPrompt == nil {
            inputText = ""
        }
        messages.append(AIChatMessage(role: .user, text: prompt))

        guard hasAPIKey else {
            isEditingAPIKey = true
            messages.append(
                AIChatMessage(
                    role: .assistant,
                    text: "Vui lòng nhập Gemini API Key ở khung cài đặt phía trên để bắt đầu tự động dựng phim.",
                    isError: true
                )
            )
            return
        }

        if agentService == nil, let timelineViewModel {
            configureDependencies(timelineViewModel: timelineViewModel, mediaLibraryViewModel: mediaLibraryViewModel)
        }
        guard let agentService else { return }

        isProcessing = true
        let activeKey = apiKey
        let activeModel = selectedModel

        Task {
            do {
                let result = try await agentService.sendUserMessage(
                    prompt,
                    apiKey: activeKey,
                    model: activeModel
                )
                self.isProcessing = false
                self.messages.append(
                    AIChatMessage(
                        role: .assistant,
                        text: result.replyText,
                        toolBadges: result.executedToolBadges
                    )
                )
            } catch {
                self.isProcessing = false
                self.messages.append(
                    AIChatMessage(
                        role: .assistant,
                        text: error.localizedDescription,
                        isError: true
                    )
                )
            }
        }
    }

    private func appendWelcomeMessageIfNeeded() {
        guard messages.isEmpty else { return }
        messages.append(
            AIChatMessage(
                role: .assistant,
                text: "Xin chào! Hãy nhập yêu cầu dựng phim (thêm video, cắt gọt, chèn chữ động, phủ màu điện ảnh...). Bạn có thể yêu cầu tinh chỉnh liên tục qua nhiều lượt chat."
            )
        )
    }
}
