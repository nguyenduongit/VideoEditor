import Foundation

/// Định nghĩa một tác vụ dựng phim đơn lẻ (Atomic Workflow Task).
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

    /// Toàn bộ các tác vụ đơn lẻ có sẵn trong hệ thống.
    public static let allTasks: [WorkflowTaskItem] = [
        WorkflowTaskItem(
            id: "syncAudio",
            name: "Đồng bộ nhịp & Cắt thừa",
            badge: "🎵 Khớp beat",
            icon: "waveform.path.badge.plus",
            description: "Khớp beat sóng nhạc, tắt tiếng gốc, cắt gọn 2 đầu clip"
        ),
        WorkflowTaskItem(
            id: "autoColor",
            name: "Phủ màu tự động",
            badge: "🎨 Phủ màu",
            icon: "paintpalette.fill",
            description: "Cân bằng sáng tối và phủ màu trong trẻo toàn timeline"
        ),
        WorkflowTaskItem(
            id: "aspect916",
            name: "Đổi tỷ lệ 9:16",
            badge: "📐 9:16",
            icon: "aspectratio",
            description: "Chuyển khổ canvas sang 9:16 cho TikTok / Reels / Shorts"
        ),
        WorkflowTaskItem(
            id: "addTitle",
            name: "Thêm chữ tiêu đề",
            badge: "🔤 Tiêu đề",
            icon: "textformat",
            description: "Tạo 1 clip text mở đầu với hoạt ảnh nghệ thuật"
        ),
        WorkflowTaskItem(
            id: "visionFraming",
            name: "Căn giữa khung hình",
            badge: "🎯 Bố cục",
            icon: "person.fill.viewfinder",
            description: "Tự động nhận diện chủ thể và căn chỉnh theo tỷ lệ 1/3"
        )
    ]

    public static func find(by id: String) -> WorkflowTaskItem? {
        allTasks.first(where: { $0.id == id })
    }
}

/// Đại diện cho một Action tổng hợp gồm chuỗi nhiều Task chạy liên hoàn.
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
