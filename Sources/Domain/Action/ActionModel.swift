import Foundation

/// Định nghĩa một tác vụ dựng phim đơn lẻ (Atomic Workflow Task) ánh xạ 1:1 với công cụ hệ thống.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation).
public struct WorkflowTaskItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let badge: String
    public let icon: String
    public let description: String

    public init(id: String, name: String, badge: String, icon: String, description: String) {
        self.id = id
        self.name = name
        self.badge = badge
        self.icon = icon
        self.description = description
    }

    /// All built-in atomic workflow tasks (100% Tool Parity with Timeline & Inspector).
    public static let allTasks: [WorkflowTaskItem] = [
        WorkflowTaskItem(
            id: "syncAudio",
            name: "Sync Audio",
            badge: "🎵 Sync",
            icon: "waveform.badge.magnifyingglass",
            description: "Analyze audio waveforms and align Audio track timing to Video"
        ),
        WorkflowTaskItem(
            id: "autoTrim",
            name: "Auto Trim",
            badge: "✂️ Auto Trim",
            icon: "timeline.selection",
            description: "Trim excess head and tail segments outside the overlapping range of Video & Audio"
        ),
        WorkflowTaskItem(
            id: "shiftToStart",
            name: "Compact Backward",
            badge: "⏮ Compact",
            icon: "backward.end.alt.fill",
            description: "Compact selected clips backward toward preceding clip or 00:00"
        ),
        WorkflowTaskItem(
            id: "muteVideo",
            name: "Mute Video Track",
            badge: "🔇 Mute",
            icon: "speaker.slash.fill",
            description: "Mute original audio of video tracks when using external music"
        ),
        WorkflowTaskItem(
            id: "markBeats",
            name: "Auto Beat",
            badge: "🥁 Beat",
            icon: "metronome.fill",
            description: "Automatically analyze audio rhythm and place beat markers"
        ),
        WorkflowTaskItem(
            id: "autoColor",
            name: "Auto Adjustment",
            badge: "🎨 Auto Grade",
            icon: "paintpalette.fill",
            description: "Balance exposure, contrast, and apply an Auto Adjustment layer"
        ),
        WorkflowTaskItem(
            id: "aspect916",
            name: "Switch to 9:16",
            badge: "📐 9:16",
            icon: "aspectratio",
            description: "Switch canvas aspect ratio to 9:16 for TikTok / Reels / Shorts"
        ),
        WorkflowTaskItem(
            id: "addTitle",
            name: "Add Title",
            badge: "🔤 Title",
            icon: "textformat",
            description: "Insert a styled title clip from presets with motion animation"
        ),
        WorkflowTaskItem(
            id: "visionFraming",
            name: "Auto Framing (AI)",
            badge: "🎯 Reframe",
            icon: "person.fill.viewfinder",
            description: "Detect subject via Vision and apply Auto-Pan framing"
        )
    ]

    public static func find(by id: String) -> WorkflowTaskItem? {
        allTasks.first(where: { $0.id == id })
    }
}

/// Đại diện cho một Action tổng hợp gồm chuỗi nhiều công cụ hệ thống chạy liên hoàn theo kịch bản (Script).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation).
public struct CustomAction: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var taskIDs: [String]
    public var titleText: String?
    public var titlePresetID: String?
    public var createdAt: Date
    public var isSystem: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String = "play.fill",
        taskIDs: [String],
        titleText: String? = nil,
        titlePresetID: String? = nil,
        createdAt: Date = Date(),
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.taskIDs = taskIDs
        self.titleText = titleText
        self.titlePresetID = titlePresetID
        self.createdAt = createdAt
        self.isSystem = isSystem
    }

    /// Danh sách Action mặc định (rỗng để người dùng tự tạo Action trên Supabase)
    public static let defaultActions: [CustomAction] = []
}
