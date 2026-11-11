import Foundation

/// Danh mục phân loại mẫu Hiệu ứng thị giác (Effect Template Category) đồng bộ với Supabase.
public enum EffectTemplateCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case lightTransition = "Ánh sáng & Mở màn"
    case partyBeat = "Nhịp điệu & Flash"
    case cinematic = "Điện ảnh & Mờ"
    case motionShake = "Rung & Chuyển động"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .lightTransition: return "Light & Intro"
        case .partyBeat: return "Party & Beat"
        case .cinematic: return "Cinematic"
        case .motionShake: return "Motion Shake"
        }
    }

    public static var assignableCases: [EffectTemplateCategory] {
        [.lightTransition, .partyBeat, .cinematic, .motionShake]
    }
}

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
        category: EffectTemplateCategory = .lightTransition,
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
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Hiệu ứng"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(EffectTemplateCategory.self, forKey: .category)) ?? .lightTransition
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

    public static func decode(from jsonString: String) -> EffectPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EffectPreset.self, from: data)
    }
}
