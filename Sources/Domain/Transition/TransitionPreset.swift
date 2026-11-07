import Foundation

/// Danh mục phân loại mẫu Chuyển cảnh (Transition Category).
public enum TransitionCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case basic = "Cơ bản"
    case motion = "Chuyển động"
    case glitch = "Kỹ xảo & Glitch"
    case light = "Ánh sáng & Phim"
    case geometric = "Hình học"

    public var id: String { rawValue }

    public static var assignableCases: [TransitionCategory] {
        [.basic, .motion, .glitch, .light, .geometric]
    }
}

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
        defaultDuration: Double = 0.5,
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
        self.defaultDuration = max(0.1, min(3.0, defaultDuration))
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
        let dur = (try? c.decodeIfPresent(Double.self, forKey: .defaultDuration)) ?? 0.5
        self.defaultDuration = max(0.1, min(3.0, dur))
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

    public static let `default` = TransitionPreset(
        id: "dissolve_default",
        name: "Hòa tan (Dissolve)",
        description: "Chuyển cảnh mượt mà kinh điển bằng hòa trộn gamma tuyến tính giữa 2 video.",
        category: .basic,
        tags: ["dissolve", "smooth", "classic"],
        defaultDuration: 0.5,
        shaderType: .dissolve,
        defaultEasing: .easeInOut,
        iconName: "circle.lefthalf.filled",
        parameters: [
            CustomParameterDescriptor(id: "gammaCurve", title: "Độ mượt Gamma", minValue: 0.5, maxValue: 2.2, defaultValue: 1.0, step: 0.05)
        ],
        isSystem: true
    )

    public static let builtInCatalog: [TransitionPreset] = [
        TransitionPreset.default,
        TransitionPreset(
            id: "push_slide",
            name: "Đẩy khung hình (Push)",
            description: "Khung hình mới trượt vào đẩy lùi khung hình cũ theo hướng tùy chọn.",
            category: .basic,
            tags: ["push", "slide", "directional"],
            defaultDuration: 0.5,
            shaderType: .directionalPush,
            defaultEasing: .easeInOut,
            iconName: "rectangle.righthalf.inset.filled.arrow.right",
            parameters: [
                CustomParameterDescriptor(id: "dirX", title: "Hướng ngang (X)", minValue: -1.0, maxValue: 1.0, defaultValue: -1.0, step: 0.5),
                CustomParameterDescriptor(id: "dirY", title: "Hướng dọc (Y)", minValue: -1.0, maxValue: 1.0, defaultValue: 0.0, step: 0.5)
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "whip_pan_left",
            name: "Whip Pan Trái",
            description: "Lia máy tốc độ cao sang trái kèm nhòe chuyển động định hướng GPU.",
            category: .motion,
            tags: ["whip", "pan", "fast", "left"],
            defaultDuration: 0.4,
            shaderType: .whipPanLeft,
            defaultEasing: .cubicBezier,
            iconName: "arrow.left",
            parameters: [
                CustomParameterDescriptor(id: "blurStrength", title: "Độ nhòe lia máy", minValue: 0.2, maxValue: 2.5, defaultValue: 1.0, step: 0.1)
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "whip_pan_right",
            name: "Whip Pan Phải",
            description: "Lia máy tốc độ cao sang phải kèm nhòe chuyển động định hướng GPU.",
            category: .motion,
            tags: ["whip", "pan", "fast", "right"],
            defaultDuration: 0.4,
            shaderType: .whipPanRight,
            defaultEasing: .cubicBezier,
            iconName: "arrow.right",
            parameters: [
                CustomParameterDescriptor(id: "blurStrength", title: "Độ nhòe lia máy", minValue: 0.2, maxValue: 2.5, defaultValue: 1.0, step: 0.1)
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "zoom_blur",
            name: "Zoom Blur",
            description: "Thu phóng xuyên tâm tạo lực hút quang học mạnh mẽ giữa 2 cảnh.",
            category: .motion,
            tags: ["zoom", "blur", "punch"],
            defaultDuration: 0.5,
            shaderType: .zoomBlur,
            defaultEasing: .cubicBezier,
            iconName: "plus.magnifyingglass",
            parameters: [
                CustomParameterDescriptor(id: "zoomStrength", title: "Cường độ hút tâm", minValue: 0.1, maxValue: 1.0, defaultValue: 0.38, step: 0.02)
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "cross_warp",
            name: "Uốn sóng (Cross Warp)",
            description: "Biến dạng mặt sóng lỏng hòa quyện không gian giữa hai khung hình.",
            category: .motion,
            tags: ["warp", "liquid", "wave"],
            defaultDuration: 0.55,
            shaderType: .crossWarp,
            defaultEasing: .easeInOut,
            iconName: "water.waves",
            parameters: [
                CustomParameterDescriptor(id: "warpStrength", title: "Biên độ uốn sóng", minValue: 8.0, maxValue: 160.0, defaultValue: 48.0, step: 2.0, unit: "px")
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "glitch_wipe",
            name: "Glitch Slice",
            description: "Cắt lát nhiễu sóng tín hiệu kỹ thuật số RGB phong cách Cyberpunk.",
            category: .glitch,
            tags: ["glitch", "cyber", "warp", "rgb"],
            defaultDuration: 0.35,
            shaderType: .glitchWipe,
            defaultEasing: .linear,
            iconName: "waveform.path.badge.plus",
            parameters: [
                CustomParameterDescriptor(id: "sliceIntensity", title: "Độ xé lát RGB", minValue: 10.0, maxValue: 200.0, defaultValue: 90.0, step: 5.0, unit: "px")
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "light_leak",
            name: "Vệt sáng (Light Leak)",
            description: "Lóa sáng ống kính ấm áp mô phỏng cuộn phim nhựa 35mm cổ điển.",
            category: .light,
            tags: ["light", "leak", "vintage", "glow"],
            defaultDuration: 0.6,
            shaderType: .lightLeak,
            defaultEasing: .easeInOut,
            iconName: "sun.max.fill",
            parameters: [
                CustomParameterDescriptor(id: "flareIntensity", title: "Cường độ lóa sáng", minValue: 0.2, maxValue: 2.0, defaultValue: 1.0, step: 0.05),
                CustomParameterDescriptor(id: "warmth", title: "Sắc ấm hổ phách", minValue: 0.0, maxValue: 1.0, defaultValue: 0.85, step: 0.05)
            ],
            isSystem: true
        ),
        TransitionPreset(
            id: "geometric_wipe",
            name: "Hình học (Geometric Wipe)",
            description: "Quét mở màn hình theo vòng tròn Iris, đường chéo hoặc mành sọc.",
            category: .geometric,
            tags: ["wipe", "iris", "circle", "diagonal", "geometric"],
            defaultDuration: 0.5,
            shaderType: .geometricWipe,
            defaultEasing: .easeInOut,
            iconName: "circle.dashed.inset.filled",
            parameters: [
                CustomParameterDescriptor(id: "shapeMode", title: "Kiểu hình (0:Tròn 1:Chéo 2:Mành)", minValue: 0.0, maxValue: 2.0, defaultValue: 0.0, step: 1.0),
                CustomParameterDescriptor(id: "feather", title: "Độ mềm biên", minValue: 0.005, maxValue: 0.25, defaultValue: 0.06, step: 0.005)
            ],
            isSystem: true
        )
    ]

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
