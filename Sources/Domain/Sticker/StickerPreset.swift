import Foundation

/// Danh mục phân loại Nhãn dán (Sticker Category)
public enum StickerCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case emoji = "Emoji & Biểu cảm"
    case natureHoliday = "Thiên nhiên & Lễ hội"
    case social = "Mạng xã hội"
    case arrow = "Mũi tên & Chỉ dẫn"
    case badge = "Huy hiệu & Đồ họa"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .emoji: return "Emoji & Faces"
        case .natureHoliday: return "Nature & Holidays"
        case .social: return "Social & Vlog"
        case .arrow: return "Arrows"
        case .badge: return "Badges & Graphics"
        }
    }

    public static var assignableCases: [StickerCategory] {
        [.emoji, .natureHoliday, .social, .arrow, .badge]
    }
}

/// Mẫu Nhãn dán (Sticker Preset) hỗ trợ Vector SVG nội tuyến (tiện lưu trữ Supabase JSON) và ảnh động GIF / APNG.
/// Tuân thủ quy tắc R2.3 (thuần Domain), R3.1 (<= 300 dòng), và R5.5 (Serialization) của AGENTS.md.
public struct StickerPreset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: StickerCategory
    public var format: StickerFormat
    public var tags: [String]
    public var defaultDuration: Double
    public var assetPath: String?
    public var systemSymbolFallback: String
    public var config: StickerConfiguration
    public var isSystem: Bool
    public var community: CommunityMetadata

    public init(
        id: String,
        schemaVersion: Int = 2,
        name: String,
        description: String,
        category: StickerCategory = .emoji,
        format: StickerFormat = .svg,
        tags: [String] = [],
        defaultDuration: Double = 3.0,
        assetPath: String? = nil,
        systemSymbolFallback: String = "face.smiling",
        config: StickerConfiguration? = nil,
        isSystem: Bool = false,
        community: CommunityMetadata? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.category = category
        self.format = format
        self.tags = tags
        self.defaultDuration = max(0.5, min(30.0, defaultDuration))
        self.assetPath = assetPath
        self.systemSymbolFallback = systemSymbolFallback
        self.config = config ?? StickerConfiguration(
            format: format,
            loopMode: .loop,
            playbackSpeed: 1.0,
            sourceURLString: assetPath,
            systemSymbolFallback: systemSymbolFallback
        )
        self.isSystem = isSystem
        self.community = community ?? (isSystem ? .systemDefault : CommunityMetadata())
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, name, description, category, format, tags
        case defaultDuration, assetPath, systemSymbolFallback, config, isSystem, community
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 2
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Sticker"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(StickerCategory.self, forKey: .category)) ?? .emoji
        let decodedFormat = (try? c.decodeIfPresent(StickerFormat.self, forKey: .format)) ?? .svg
        self.format = decodedFormat
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let rawDur = (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 3.0
        self.defaultDuration = max(0.5, min(30.0, rawDur))
        let path = try? c.decodeIfPresent(String.self, forKey: .assetPath)
        self.assetPath = path
        let fallback = (try? c.decodeIfPresent(String.self, forKey: .systemSymbolFallback)) ?? "face.smiling"
        self.systemSymbolFallback = fallback
        self.config = (try? c.decodeIfPresent(StickerConfiguration.self, forKey: .config)) ?? StickerConfiguration(
            format: decodedFormat,
            sourceURLString: path,
            systemSymbolFallback: fallback
        )
        let sys = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
        self.isSystem = sys
        self.community = (try? c.decodeIfPresent(CommunityMetadata.self, forKey: .community))
            ?? (sys ? .systemDefault : CommunityMetadata())
    }

    public static let builtInCatalog: [StickerPreset] = [
        StickerPreset(
            id: "sticker_animated_flower_leaf",
            name: "Hoa Lá Động (SVG)",
            description: "Cây hoa lá đung đưa và cánh hoa rơi hoạt họa bằng vector SVG thuần CSS",
            category: .natureHoliday,
            format: .svg,
            tags: ["flower", "leaf", "nature", "animated", "svg", "css"],
            defaultDuration: 3.0,
            systemSymbolFallback: "sparkles",
            config: StickerConfiguration(
                format: .svg,
                loopMode: .loop,
                playbackSpeed: 1.0,
                sourceURLString: "sticker_animated_flower_leaf.apng",
                svgMarkup: animatedFlowerSVGMarkup,
                systemSymbolFallback: "sparkles",
                hasShadow: false,
                shadowColorHex: "#00000040",
                shadowBlur: 10.0,
                shadowDistance: 4.0
            ),
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_animated_xmas_tree",
            name: "Cây Thông Noel (SVG)",
            description: "Cây thông Noel đung đưa, đèn led nhấp nháy nhiều màu và tuyết rơi hoạt họa bằng vector SVG thuần CSS",
            category: .natureHoliday,
            format: .svg,
            tags: ["xmas", "tree", "christmas", "holiday", "noel", "animated", "svg"],
            defaultDuration: 3.0,
            systemSymbolFallback: "sparkles",
            config: StickerConfiguration(
                format: .svg,
                loopMode: .loop,
                playbackSpeed: 1.0,
                sourceURLString: "sticker_animated_xmas_tree.apng",
                svgMarkup: animatedXmasTreeSVGMarkup,
                systemSymbolFallback: "sparkles",
                hasShadow: false,
                shadowColorHex: "#00000040",
                shadowBlur: 10.0,
                shadowDistance: 4.0
            ),
            isSystem: true
        )
    ] + emojiPresets

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> StickerPreset? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StickerPreset.self, from: data)
    }
}
