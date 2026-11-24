import Foundation

/// Dev-authored system visual effect entry in the Effects System Library (`EffectLibrary`).
/// Strictly read-only to end users per AGENTS.md Article 15 (no user preset save/delete or Supabase sync).
/// Complies with AGENTS.md (Pure Domain, 1 Primary Type per file, Sendable, Equatable).
public struct EffectLibraryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: EffectCategory
    public var tags: [String]
    public var defaultDuration: Double
    public var previewBadge: String?
    public var config: EffectConfiguration

    public init(
        id: String,
        schemaVersion: Int = 1,
        name: String,
        description: String,
        category: EffectCategory = .basic,
        tags: [String] = [],
        defaultDuration: Double = 3.0,
        previewBadge: String? = nil,
        config: EffectConfiguration
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
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Effect"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(EffectCategory.self, forKey: .category)) ?? .basic
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.defaultDuration = max(0.5, min(30.0, (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 3.0))
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        self.config = (try? c.decodeIfPresent(EffectConfiguration.self, forKey: .config)) ?? EffectConfiguration()
    }

    public func encodeToJSON(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> EffectLibraryItem? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EffectLibraryItem.self, from: data)
    }
}
