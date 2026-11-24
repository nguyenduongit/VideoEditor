import Foundation

/// Dev-authored system transition entry (`TransitionLibraryItem`) connecting two adjacent clips.
/// Strictly read-only to end users per AGENTS.md Article 15 (no user preset save/delete or Supabase sync).
/// Complies with AGENTS.md (Pure Domain, 1 Primary Type per file, Sendable, Equatable).
public struct TransitionLibraryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: TransitionCategory
    public var tags: [String]
    public var defaultDuration: Double
    public var shaderType: TransitionShaderType
    public var defaultEasing: TransitionEasing
    public var iconName: String
    public var previewBadge: String?
    public var parameters: [CustomParameterDescriptor]
    public var parameterValues: [String: Double]
    public var customMetalSource: String?

    public init(
        id: String,
        schemaVersion: Int = 2,
        name: String,
        description: String,
        category: TransitionCategory = .basic,
        tags: [String] = [],
        defaultDuration: Double = 2.0,
        shaderType: TransitionShaderType = .dissolve,
        defaultEasing: TransitionEasing = .easeInOut,
        iconName: String = "arrow.left.arrow.right",
        previewBadge: String? = nil,
        parameters: [CustomParameterDescriptor] = [],
        parameterValues: [String: Double] = [:],
        customMetalSource: String? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.defaultDuration = max(0.1, min(5.0, defaultDuration))
        self.shaderType = shaderType
        self.defaultEasing = defaultEasing
        self.iconName = iconName
        self.previewBadge = previewBadge
        self.parameters = parameters
        var merged = parameterValues
        for param in parameters where merged[param.id] == nil {
            merged[param.id] = param.defaultValue
        }
        self.parameterValues = merged
        self.customMetalSource = customMetalSource
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 2
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Transition"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(TransitionCategory.self, forKey: .category)) ?? .basic
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let dur = (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 2.0
        self.defaultDuration = max(0.1, min(5.0, dur))
        self.shaderType = (try? c.decodeIfPresent(TransitionShaderType.self, forKey: .shaderType)) ?? .dissolve
        self.defaultEasing = (try? c.decodeIfPresent(TransitionEasing.self, forKey: .defaultEasing)) ?? .easeInOut
        self.iconName = (try? c.decodeIfPresent(String.self, forKey: .iconName)) ?? "arrow.left.arrow.right"
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        let params = (try? c.decodeIfPresent([CustomParameterDescriptor].self, forKey: .parameters)) ?? []
        self.parameters = params
        var vals = (try? c.decodeIfPresent([String: Double].self, forKey: .parameterValues)) ?? [:]
        for p in params where vals[p.id] == nil {
            vals[p.id] = p.defaultValue
        }
        self.parameterValues = vals
        self.customMetalSource = try? c.decodeIfPresent(String.self, forKey: .customMetalSource)
    }

    public static let `default`: TransitionLibraryItem = catalogBasic.first(where: { $0.id == "dissolve_default" }) ?? catalogBasic[0]

    /// Complete built-in System Library of 83 dev-authored Metal transitions across 8 NLE categories.
    public static let systemItems: [TransitionLibraryItem] = {
        catalogBasic + catalogMotion + catalogEffects
    }()

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> TransitionLibraryItem? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TransitionLibraryItem.self, from: data)
    }
}
