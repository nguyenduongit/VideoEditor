import Foundation

/// Standard categories classifying system Stickers (`StickerLibraryItem`).
/// Complies with AGENTS.md (Pure Domain, 1 Primary Type per file, Sendable, Codable).
public enum StickerCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case emoji = "Emoji & Faces"
    case audioVisualizer = "Audio Visualizers"
    case natureHoliday = "Nature & Holidays"
    case social = "Social & Vlog"
    case arrow = "Arrows"
    case badge = "Badges & Graphics"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue
    }

    public static var assignableCases: [StickerCategory] {
        [.emoji, .audioVisualizer, .natureHoliday, .social, .arrow, .badge]
    }

    public static func resolve(categoryString: String) -> StickerCategory {
        if let matched = StickerCategory(rawValue: categoryString) {
            return matched
        }
        switch categoryString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "all", "tất cả": return .all
        case "emoji & faces", "emoji & biểu cảm": return .emoji
        case "audio visualizers", "audiogram", "sóng âm": return .audioVisualizer
        case "nature & holidays", "thiên nhiên & lễ hội": return .natureHoliday
        case "social & vlog", "mạng xã hội": return .social
        case "arrows", "mũi tên & chỉ dẫn": return .arrow
        case "badges & graphics", "huy hiệu & đồ họa": return .badge
        default: return .emoji
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.resolve(categoryString: raw)
    }
}
