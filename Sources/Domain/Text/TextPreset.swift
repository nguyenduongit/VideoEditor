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

    /// Các danh mục thực tế gán cho từng file JSON (không tính tab lọc "Tất cả")
    public static var assignableCases: [TextTemplateCategory] {
        [.karaoke, .trending, .cyber, .cinema, .vlog]
    }
}

import CoreMedia

/// Lớp phụ (Sub-Layer) dùng cho các mẫu chữ phức hợp đa lớp (Compound Multi-Layer Template)
/// Tuân thủ AGENTS.md R2.3 (sử dụng thời gian hữu tỉ RationalTime thay cho Double seconds đơn thuần).
public struct TextTemplateSubLayer: Codable, Sendable, Equatable {
    public var name: String
    public var startOffset: RationalTime
    public var startOffsetSeconds: Double {
        get { startOffset.seconds }
        set { startOffset = RationalTime(cmTime: CMTime(seconds: max(0.0, newValue), preferredTimescale: 600)) }
    }
    public var durationRatio: Double
    public var config: TextConfiguration

    public init(
        name: String,
        startOffset: RationalTime,
        durationRatio: Double = 1.0,
        config: TextConfiguration
    ) {
        self.name = name
        self.startOffset = startOffset
        self.durationRatio = max(0.1, min(1.0, durationRatio))
        self.config = config
    }

    public init(
        name: String,
        startOffsetSeconds: Double = 0.0,
        durationRatio: Double = 1.0,
        config: TextConfiguration
    ) {
        let cm = CMTime(seconds: max(0.0, startOffsetSeconds), preferredTimescale: 600)
        self.init(name: name, startOffset: RationalTime(cmTime: cm), durationRatio: durationRatio, config: config)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case startOffset
        case startOffsetSeconds
        case durationRatio
        case config
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Sub Layer"
        if let rational = try? c.decodeIfPresent(RationalTime.self, forKey: .startOffset) {
            self.startOffset = rational
        } else {
            let sec = (try? c.decodeIfPresent(Double.self, forKey: .startOffsetSeconds)) ?? 0.0
            self.startOffset = RationalTime(cmTime: CMTime(seconds: max(0.0, sec), preferredTimescale: 600))
        }
        self.durationRatio = (try? c.decodeIfPresent(Double.self, forKey: .durationRatio)) ?? 1.0
        self.config = (try? c.decodeIfPresent(TextConfiguration.self, forKey: .config)) ?? TextConfiguration()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(startOffset, forKey: .startOffset)
        try c.encode(startOffsetSeconds, forKey: .startOffsetSeconds)
        try c.encode(durationRatio, forKey: .durationRatio)
        try c.encode(config, forKey: .config)
    }
}

/// Mẫu kiểu chữ thiết kế sẵn (Text Template Script) tuần tự hóa JSON độc lập và tương thích Supabase `jsonb`.
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
    public var subLayers: [TextTemplateSubLayer]
    public var isSystem: Bool

    public init(
        id: String,
        schemaVersion: Int = 1,
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
        subLayers: [TextTemplateSubLayer] = [],
        isSystem: Bool = false
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
        self.subLayers = subLayers
        self.isSystem = isSystem
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Mẫu chữ"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(TextTemplateCategory.self, forKey: .category)) ?? .trending
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.defaultDuration = (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 4.0
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        self.previewBackgroundHex = (try? c.decodeIfPresent(String.self, forKey: .previewBackgroundHex)) ?? "#18181B"
        self.fallbackFontName = try? c.decodeIfPresent(String.self, forKey: .fallbackFontName)
        self.remoteFontURL = try? c.decodeIfPresent(String.self, forKey: .remoteFontURL)
        self.config = (try? c.decodeIfPresent(TextConfiguration.self, forKey: .config)) ?? TextConfiguration()
        self.subLayers = (try? c.decodeIfPresent([TextTemplateSubLayer].self, forKey: .subLayers)) ?? []
        self.isSystem = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
    }

    public func encodeToJSON(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        // Giải thích try?: Trả về nil nếu dữ liệu float không hợp lệ (NaN/Infinite)
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> TextPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        // Giải thích try?: Bỏ qua an toàn nếu JSON từ server bị lỗi cú pháp (R5.6)
        return try? JSONDecoder().decode(TextPreset.self, from: data)
    }

    /// Mẫu văn bản chuẩn mặc định
    public static let `default` = TextPreset(
        id: "default",
        name: "Văn bản mặc định",
        description: "Kiểu chữ tiêu chuẩn cơ bản",
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

    /// Danh sách mẫu chữ mặc định chuẩn (bất biến, không phụ thuộc singleton — R3.3)
    public static var templates: [TextPreset] {
        [Self.default]
    }
}
