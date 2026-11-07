import Foundation

/// Danh mục phân loại mẫu chữ (Text Template Category) đồng bộ với Supabase
public enum TextTemplateCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case karaoke = "Karaoke & Phụ đề"
    case trending = "Trending"
    case cyber = "Neon & Cyber"
    case cinema = "3D & Điện ảnh"
    case vlog = "Vlog & Tin tức"

    public var id: String { rawValue }

    /// Các danh mục thực tế gán cho từng mẫu (không tính tab lọc "Tất cả")
    public static var assignableCases: [TextTemplateCategory] {
        [.karaoke, .trending, .cyber, .cinema, .vlog]
    }
}

/// Mẫu kiểu chữ thiết kế sẵn 1-lõi thống nhất (Text Template Script) tuần tự hóa JSON độc lập trên Supabase `jsonb`.
/// Dùng chung chính xác 1 lõi `TextConfiguration` cho cả người dùng tự tạo lẫn mẫu dựng sẵn.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R5.5 (Serialization) và R5.6 (Forward Compatibility).
public struct TextPreset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: TextTemplateCategory
    public var tags: [String]
    public var defaultDuration: Double
    public var previewBadge: String?
    public var previewBackgroundHex: String
    public var fallbackFontName: String?
    public var remoteFontURL: String?
    public var config: TextConfiguration
    public var isSystem: Bool
    public var community: CommunityMetadata

    public init(
        id: String,
        schemaVersion: Int = 2,
        name: String,
        description: String,
        category: TextTemplateCategory = .trending,
        tags: [String] = [],
        defaultDuration: Double = 4.0,
        previewBadge: String? = nil,
        previewBackgroundHex: String = "#18181B",
        fallbackFontName: String? = nil,
        remoteFontURL: String? = nil,
        config: TextConfiguration,
        isSystem: Bool = false,
        community: CommunityMetadata? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.defaultDuration = max(0.5, min(30.0, defaultDuration))
        self.previewBadge = previewBadge
        self.previewBackgroundHex = previewBackgroundHex
        self.fallbackFontName = fallbackFontName
        self.remoteFontURL = remoteFontURL
        self.config = config
        self.isSystem = isSystem
        self.community = community ?? (isSystem ? .systemDefault : CommunityMetadata())
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 2
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Mẫu chữ"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(TextTemplateCategory.self, forKey: .category)) ?? .trending
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.defaultDuration = max(0.5, min(30.0, (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 4.0))
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        self.previewBackgroundHex = (try? c.decodeIfPresent(String.self, forKey: .previewBackgroundHex)) ?? "#18181B"
        self.fallbackFontName = try? c.decodeIfPresent(String.self, forKey: .fallbackFontName)
        self.remoteFontURL = try? c.decodeIfPresent(String.self, forKey: .remoteFontURL)
        self.config = (try? c.decodeIfPresent(TextConfiguration.self, forKey: .config)) ?? TextConfiguration()
        let sys = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
        self.isSystem = sys
        self.community = (try? c.decodeIfPresent(CommunityMetadata.self, forKey: .community))
            ?? (sys ? .systemDefault : CommunityMetadata())
    }

    public func canBeModified(by userID: String) -> Bool {
        guard !isSystem else { return false }
        return community.authorID.isEmpty || community.authorID == userID
    }

    public func encodeToJSON(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> TextPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TextPreset.self, from: data)
    }

    /// Mẫu văn bản chuẩn mặc định
    public static let `default` = TextPreset(
        id: "default",
        name: "Văn bản mặc định",
        description: "Kiểu chữ đơn dòng tiêu chuẩn cơ bản",
        category: .vlog,
        config: TextConfiguration(
            content: "Văn bản",
            fontName: "Helvetica",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            isBold: true
        ),
        isSystem: true
    )
}
