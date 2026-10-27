import Foundation

/// Danh mục phân loại mẫu chỉnh màu (Adjustment Template Category) đồng bộ với Supabase
public enum AdjustmentTemplateCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "Tất cả"
    case cinematic = "Điện ảnh"
    case filmVintage = "Phim & Cổ điển"
    case portraitVlog = "Chân dung & Vlog"
    case cyberNeon = "Cyber & Đêm"
    case moodyMono = "Moody & B&W"

    public var id: String { rawValue }
}

/// Mẫu thiết lập sẵn thông số màu (Color Grading Template Script) tuần tự hóa JSON độc lập và tương thích Supabase `jsonb`.
/// Khai thác toàn diện cả 5 hệ màu: Basic, 8-Channel HSL, 3-Way Color Wheels, RGB/Luma Curves, và Effects (Vignette, Grain, Sharpen).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain), R5.5 (Serialization) và R5.6 (Forward Compatibility).
public struct AdjustmentPreset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var schemaVersion: Int
    public var name: String
    public var description: String
    public var category: AdjustmentTemplateCategory
    public var tags: [String]
    public var previewBadge: String?
    public var previewColorsHex: [String]
    public var config: AdjustmentConfiguration
    public var isSystem: Bool

    public init(
        id: String,
        schemaVersion: Int = 1,
        name: String,
        description: String,
        category: AdjustmentTemplateCategory = .cinematic,
        tags: [String] = [],
        previewBadge: String? = nil,
        previewColorsHex: [String] = ["#1A8099", "#D97326"],
        config: AdjustmentConfiguration,
        isSystem: Bool = false
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.description = description
        self.category = category
        self.tags = tags
        self.previewBadge = previewBadge
        self.previewColorsHex = previewColorsHex.isEmpty ? ["#27272A", "#52525B"] : previewColorsHex
        self.config = config
        self.isSystem = isSystem
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.schemaVersion = (try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Mẫu chỉnh màu"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.category = (try? c.decodeIfPresent(AdjustmentTemplateCategory.self, forKey: .category)) ?? .cinematic
        self.tags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        self.previewBadge = try? c.decodeIfPresent(String.self, forKey: .previewBadge)
        let decodedColors = (try? c.decodeIfPresent([String].self, forKey: .previewColorsHex)) ?? []
        self.previewColorsHex = decodedColors.isEmpty ? ["#27272A", "#52525B"] : decodedColors
        self.config = (try? c.decodeIfPresent(AdjustmentConfiguration.self, forKey: .config)) ?? AdjustmentConfiguration()
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

    public static func decode(from jsonString: String) -> AdjustmentPreset? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        // Giải thích try?: Bỏ qua an toàn nếu JSON từ server bị lỗi cú pháp (R5.6)
        return try? JSONDecoder().decode(AdjustmentPreset.self, from: data)
    }

    /// Danh sách các phân hệ đang kích hoạt trong preset (dùng hiển thị huy hiệu kỹ thuật trên UI)
    public var activeModuleBadges: [String] {
        var result: [String] = []
        if !config.basic.isNeutral { result.append("Basic") }
        if !config.hsl.isNeutral { result.append("HSL") }
        if !config.wheels.isNeutral { result.append("Wheels") }
        if !config.curves.isNeutral { result.append("Curves") }
        if !config.effects.isNeutral { result.append("FX") }
        if !config.lut.isNeutral { result.append("LUT") }
        return result
    }

    public static let `default` = AdjustmentPreset(
        id: "default",
        name: "Mặc định",
        description: "Màu nguyên bản không chỉnh sửa",
        category: .cinematic,
        previewColorsHex: ["#27272A", "#18181B"],
        config: AdjustmentConfiguration(),
        isSystem: true
    )

    /// Danh sách mẫu chỉnh màu được nạp động từ các file JSON Script và bộ nhớ đệm Supabase
    public static var templates: [AdjustmentPreset] {
        AdjustmentTemplateLoader.shared.loadAllTemplates()
    }
}
