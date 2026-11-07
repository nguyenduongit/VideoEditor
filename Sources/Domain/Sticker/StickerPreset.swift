import Foundation

/// Danh mục phân loại Nhãn dán (Sticker Category)
public enum StickerCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case emoji = "Emoji & Biểu cảm"
    case social = "Mạng xã hội"
    case arrow = "Mũi tên & Chỉ dẫn"
    case badge = "Huy hiệu & Đồ họa"

    public var id: String { rawValue }

    public static var assignableCases: [StickerCategory] {
        [.emoji, .social, .arrow, .badge]
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
            id: "sticker_svg_star_badge",
            name: "Huy Hiệu Ngôi Sao (SVG)",
            description: "Nhãn dán vector SVG sắc nét ở mọi mức phóng đại",
            category: .badge,
            format: .svg,
            tags: ["svg", "star", "badge", "vector"],
            defaultDuration: 3.5,
            systemSymbolFallback: "star.circle.fill",
            config: StickerConfiguration(
                format: .svg,
                svgMarkup: """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 240">
                  <circle cx="120" cy="120" r="104" fill="#F59E0B" stroke="#FFFFFF" stroke-width="10"/>
                  <polygon points="120,44 142,92 194,98 155,134 166,186 120,160 74,186 85,134 46,98 98,92" fill="#FFFBEB"/>
                </svg>
                """,
                systemSymbolFallback: "star.circle.fill",
                hasShadow: true
            ),
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_svg_neon_arrow",
            name: "Mũi Tên Neon (SVG)",
            description: "Mũi tên chỉ dẫn vector SVG viền sáng rực rỡ",
            category: .arrow,
            format: .svg,
            tags: ["svg", "arrow", "neon", "vector"],
            defaultDuration: 3.0,
            systemSymbolFallback: "arrow.right.circle.fill",
            config: StickerConfiguration(
                format: .svg,
                svgMarkup: """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 280 160">
                  <path d="M24,56 H164 V20 L256,80 L164,140 V104 H24 Z" fill="#06B6D4" stroke="#FFFFFF" stroke-width="10" stroke-linejoin="round"/>
                </svg>
                """,
                systemSymbolFallback: "arrow.right.circle.fill",
                hasShadow: true
            ),
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_svg_love_pill",
            name: "Nhãn Tim Đỏ (SVG)",
            description: "Khung pill thả tim vector SVG lưu gọn trong JSON Supabase",
            category: .social,
            format: .svg,
            tags: ["svg", "love", "heart", "social", "vector"],
            defaultDuration: 3.0,
            systemSymbolFallback: "heart.text.square.fill",
            config: StickerConfiguration(
                format: .svg,
                svgMarkup: """
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 280 140">
                  <rect x="12" y="16" width="256" height="108" rx="54" fill="#EF4444" stroke="#FFFFFF" stroke-width="8"/>
                  <path d="M140,102 C140,102 96,74 96,50 C96,36 108,28 120,28 C130,28 137,34 140,41 C143,34 150,28 160,28 C172,28 184,36 184,50 C184,74 140,102 140,102 Z" fill="#FFFFFF"/>
                </svg>
                """,
                systemSymbolFallback: "heart.fill",
                hasShadow: true
            ),
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_heart_like",
            name: "Trái tim Like",
            description: "Biểu tượng yêu thích nhảy theo nhịp",
            category: .social,
            format: .apng,
            tags: ["heart", "like", "love", "social"],
            defaultDuration: 3.0,
            systemSymbolFallback: "heart.fill",
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_thumbs_up",
            name: "Ngón tay Like",
            description: "Nút Like động phong cách phẳng",
            category: .social,
            format: .gif,
            tags: ["like", "thumbsup", "social"],
            defaultDuration: 3.0,
            systemSymbolFallback: "hand.thumbsup.fill",
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_fire_trending",
            name: "Ngọn lửa Hot",
            description: "Hiệu ứng lửa bùng cháy dành cho nội dung nổi bật",
            category: .badge,
            format: .apng,
            tags: ["fire", "hot", "trending", "flame"],
            defaultDuration: 3.0,
            systemSymbolFallback: "flame.fill",
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_arrow_pointing",
            name: "Mũi tên chú ý",
            description: "Mũi tên nhấp nháy chỉ dẫn người xem",
            category: .arrow,
            format: .apng,
            tags: ["arrow", "pointer", "direction"],
            defaultDuration: 3.0,
            systemSymbolFallback: "arrowshape.right.fill",
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_party_popper",
            name: "Pháo giấy chúc mừng",
            description: "Hiệu ứng nổ pháo giấy sinh động",
            category: .emoji,
            format: .gif,
            tags: ["party", "celebrate", "popper"],
            defaultDuration: 2.5,
            systemSymbolFallback: "party.popper.fill",
            isSystem: true
        ),
        StickerPreset(
            id: "sticker_star_sparkle",
            name: "Ngôi sao lấp lánh",
            description: "Chùm sao phát sáng lấp lánh",
            category: .badge,
            format: .apng,
            tags: ["star", "sparkle", "shine"],
            defaultDuration: 3.0,
            systemSymbolFallback: "sparkles",
            isSystem: true
        )
    ]

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
