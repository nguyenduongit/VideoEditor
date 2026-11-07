import Foundation

/// Gói Thiết Lập Hoạt Ảnh Sáng Tạo Mở (Open Creative Animation Package) đồng bộ trực tuyến trên Supabase.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R5.5 (Serialization) và R5.6 (Forward Compatibility).
public struct AnimationPreset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var phase: AnimationPhaseCategory
    public var tags: [String]
    public var previewBadge: String?
    public var manifest: CreativeAnimationManifest
    public var isSystem: Bool
    public var community: CommunityMetadata

    public init(
        id: String,
        schemaVersion: Int = 1,
        name: String,
        description: String,
        phase: AnimationPhaseCategory,
        tags: [String] = [],
        previewBadge: String? = nil,
        manifest: CreativeAnimationManifest,
        isSystem: Bool = false,
        community: CommunityMetadata? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.phase = phase
        self.tags = tags
        self.previewBadge = previewBadge
        self.manifest = manifest
        self.isSystem = isSystem
        self.community = community ?? (isSystem ? .systemDefault : CommunityMetadata())
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Hoạt ảnh"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.phase = (try? c.decodeIfPresent(AnimationPhaseCategory.self, forKey: .phase)) ?? .inAnimation
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        self.manifest = (try? c.decodeIfPresent(CreativeAnimationManifest.self, forKey: .manifest))
            ?? CreativeAnimationManifest(id: id, name: name, phase: self.phase)
        let sys = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
        self.isSystem = sys
        self.community = (try? c.decodeIfPresent(CommunityMetadata.self, forKey: .community))
            ?? (sys ? .systemDefault : CommunityMetadata())
    }

    public func encodeToJSON(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> AnimationPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnimationPreset.self, from: data)
    }
}

