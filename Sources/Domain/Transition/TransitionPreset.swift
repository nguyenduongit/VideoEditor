import Foundation

/// Mẫu chuyển cảnh dựng sẵn hoặc từ Supabase (`TransitionPreset`) dành cho liên kết 2 clip kề nhau.
/// Hỗ trợ tham số động `parameters` (`CustomParameterDescriptor`) và mã nguồn Metal Shading Language (`customMetalSource`).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R3.1 (File <= 300 dòng) và R5.5 (Serialization).
public struct TransitionPreset: Identifiable, Codable, Sendable, Equatable {
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
    public var isSystem: Bool
    public var community: CommunityMetadata

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
        customMetalSource: String? = nil,
        isSystem: Bool = false,
        community: CommunityMetadata = CommunityMetadata()
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
        self.isSystem = isSystem
        self.community = community
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 2
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Chuyển cảnh"
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
        let sys = (try? c.decodeIfPresent(Bool.self, forKey: .isSystem)) ?? false
        self.isSystem = sys
        self.community = (try? c.decodeIfPresent(CommunityMetadata.self, forKey: .community))
            ?? CommunityMetadata(authorName: sys ? "VideoEditor Official" : "Creator")
    }

    public static let `default`: TransitionPreset = catalogBasic.first(where: { $0.id == "dissolve_default" }) ?? catalogBasic[0]

    /// Danh mục 83 mẫu Chuyển cảnh chính thức phân bổ đều trên 8 danh mục NLE quốc tế.
    public static let builtInCatalog: [TransitionPreset] = {
        catalogBasic + catalogMotion + catalogEffects
    }()

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> TransitionPreset? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TransitionPreset.self, from: data)
    }
}
