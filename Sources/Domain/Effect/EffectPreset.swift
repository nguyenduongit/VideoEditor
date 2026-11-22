import Foundation

/// 11 Danh mục chuẩn phân loại mẫu Hiệu ứng thị giác (Video Effect Categories) đồng bộ với Supabase.
/// Tuân thủ AGENTS.md (Pure Domain, Sendable, Codable, File <= 300 dòng).
public enum EffectTemplateCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case basic = "Basic"
    case blur = "Blur"
    case glitch = "Glitch / Distortion"
    case light = "Light Effects"
    case retro = "Retro / Vintage / Film"
    case camera = "Camera Effects"
    case motion = "Motion Effects"
    case color = "Color Effects"
    case nature = "Particle / Nature"
    case artistic = "Artistic / Stylize"
    case overlay = "Text / Overlay"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .basic: return "Basic"
        case .blur: return "Blur"
        case .glitch: return "Glitch"
        case .light: return "Light"
        case .retro: return "Retro / Film"
        case .camera: return "Camera"
        case .motion: return "Motion"
        case .color: return "Color"
        case .nature: return "Nature"
        case .artistic: return "Artistic"
        case .overlay: return "Overlay"
        }
    }

    /// 11 danh mục hiển thị trên thanh Sidebar hiệu ứng.
    public static var assignableCases: [EffectTemplateCategory] {
        [
            .basic,
            .blur,
            .glitch,
            .light,
            .retro,
            .camera,
            .motion,
            .color,
            .nature,
            .artistic,
            .overlay
        ]
    }

    // MARK: - Backward Compatibility Aliases

    public static let lightTransition: EffectTemplateCategory = .light
    public static let partyBeat: EffectTemplateCategory = .motion
    public static let cinematic: EffectTemplateCategory = .retro
    public static let motionShake: EffectTemplateCategory = .camera

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if let matched = EffectTemplateCategory(rawValue: str) {
            self = matched
            return
        }
        let lower = str.lowercased()
        switch lower {
        case "basic", "cơ bản", "basic effects": self = .basic
        case "blur", "làm mờ", "blur effects": self = .blur
        case "glitch", "glitch / distortion", "distortion", "nhiễu": self = .glitch
        case "light", "light effects", "ánh sáng", "ánh sáng & mở màn", "lighttransition": self = .light
        case "retro", "retro / vintage / film", "vintage", "film", "điện ảnh & mờ", "cinematic": self = .retro
        case "camera", "camera effects", "máy quay", "rung & chuyển động", "motionshake": self = .camera
        case "motion", "motion effects", "chuyển động", "nhịp điệu & flash", "partybeat": self = .motion
        case "color", "color effects", "màu sắc": self = .color
        case "nature", "particle / nature", "particles", "hạt & thiên nhiên", "nature effects": self = .nature
        case "artistic", "artistic / stylize", "stylize", "nghệ thuật", "artistic effects": self = .artistic
        case "overlay", "text / overlay", "lớp phủ", "overlay effects": self = .overlay
        default: self = .basic
        }
    }
}

public typealias EffectCategory = EffectTemplateCategory

/// Mẫu thiết lập sẵn hiệu ứng thị giác (Effect Preset Script) tuần tự hóa JSON độc lập và tương thích Supabase `jsonb`.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R5.5 (Serialization) và R5.6 (Forward Compatibility).
public struct EffectPreset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: EffectTemplateCategory
    public var tags: [String]
    public var defaultDuration: Double
    public var previewBadge: String?
    public var config: EffectConfiguration
    public var isSystem: Bool
    public var community: CommunityMetadata

    public init(
        id: String,
        schemaVersion: Int = 1,
        name: String,
        description: String,
        category: EffectTemplateCategory = .basic,
        tags: [String] = [],
        defaultDuration: Double = 3.0,
        previewBadge: String? = nil,
        config: EffectConfiguration,
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
        self.config = config
        self.isSystem = isSystem
        self.community = community ?? (isSystem ? .systemDefault : CommunityMetadata())
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Effect"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(EffectTemplateCategory.self, forKey: .category)) ?? .basic
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.defaultDuration = max(0.5, min(30.0, (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 3.0))
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        self.config = (try? c.decodeIfPresent(EffectConfiguration.self, forKey: .config)) ?? EffectConfiguration()
        let sys = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
        self.isSystem = sys
        self.community = (try? c.decodeIfPresent(CommunityMetadata.self, forKey: .community))
            ?? (sys ? .systemDefault : CommunityMetadata())
    }

    public func canBeModified(by userID: String) -> Bool {
        !isSystem
    }

    public func encodeToJSON(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> EffectPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EffectPreset.self, from: data)
    }
}
