import Foundation

/// Căn lề cho khối văn bản
public enum TextAlignmentType: String, Codable, Sendable, CaseIterable {
    case left
    case center
    case right
}

/// Toàn bộ cấu hình kiểu chữ, định dạng, hiệu ứng viền/bóng/nền và biến đổi cho Text Clip
public struct TextConfiguration: Codable, Equatable, Sendable {
    // MARK: - Nội dung & Kiểu chữ cơ bản
    public var content: String
    public var fontName: String
    public var fontSize: Double
    public var textColorHex: String
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
    public var isAllCaps: Bool
    public var alignment: TextAlignmentType
    public var characterSpacing: Double
    public var lineSpacing: Double

    // MARK: - Hiệu ứng viền (Stroke / Outline)
    public var hasStroke: Bool
    public var strokeColorHex: String
    public var strokeWidth: Double

    // MARK: - Hiệu ứng đổ bóng (Shadow)
    public var hasShadow: Bool
    public var shadowColorHex: String
    public var shadowRadius: Double
    public var shadowOffsetX: Double
    public var shadowOffsetY: Double

    // MARK: - Hiệu ứng phát sáng (Outer Glow)
    public var hasGlow: Bool
    public var glowColorHex: String
    public var glowRadius: Double

    // MARK: - Hộp nền (Background Box / Badge)
    public var hasBackground: Bool
    public var backgroundColorHex: String
    public var backgroundCornerRadius: Double
    public var backgroundPadding: Double

    // MARK: - Biến đổi (Transform)
    public var positionX: Double
    public var positionY: Double
    public var scale: Double
    public var rotation: Double
    public var opacity: Double

    // MARK: - Hoạt ảnh chuyển động (Animation)
    public var animation: TextAnimationConfiguration

    public init(
        content: String = "Văn bản",
        fontName: String = "Helvetica",
        fontSize: Double = 48.0,
        textColorHex: String = "#FFFFFF",
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        isAllCaps: Bool = false,
        alignment: TextAlignmentType = .center,
        characterSpacing: Double = 0.0,
        lineSpacing: Double = 4.0,
        hasStroke: Bool = false,
        strokeColorHex: String = "#000000",
        strokeWidth: Double = 2.0,
        hasShadow: Bool = false,
        shadowColorHex: String = "#000000",
        shadowRadius: Double = 6.0,
        shadowOffsetX: Double = 2.0,
        shadowOffsetY: Double = 2.0,
        hasGlow: Bool = false,
        glowColorHex: String = "#FFD700",
        glowRadius: Double = 8.0,
        hasBackground: Bool = false,
        backgroundColorHex: String = "#000000B2",
        backgroundCornerRadius: Double = 8.0,
        backgroundPadding: Double = 12.0,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        opacity: Double = 1.0,
        animation: TextAnimationConfiguration = TextAnimationConfiguration()
    ) {
        self.content = content
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.isAllCaps = isAllCaps
        self.alignment = alignment
        self.characterSpacing = characterSpacing
        self.lineSpacing = lineSpacing
        self.hasStroke = hasStroke
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.hasShadow = hasShadow
        self.shadowColorHex = shadowColorHex
        self.shadowRadius = shadowRadius
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.hasGlow = hasGlow
        self.glowColorHex = glowColorHex
        self.glowRadius = glowRadius
        self.hasBackground = hasBackground
        self.backgroundColorHex = backgroundColorHex
        self.backgroundCornerRadius = backgroundCornerRadius
        self.backgroundPadding = backgroundPadding
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.animation = animation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = (try? container.decode(String.self, forKey: .content)) ?? "Văn bản"
        self.fontName = (try? container.decode(String.self, forKey: .fontName)) ?? "Helvetica"
        self.fontSize = (try? container.decode(Double.self, forKey: .fontSize)) ?? 48.0
        self.textColorHex = (try? container.decode(String.self, forKey: .textColorHex)) ?? "#FFFFFF"
        self.isBold = (try? container.decode(Bool.self, forKey: .isBold)) ?? false
        self.isItalic = (try? container.decode(Bool.self, forKey: .isItalic)) ?? false
        self.isUnderline = (try? container.decode(Bool.self, forKey: .isUnderline)) ?? false
        self.isStrikethrough = (try? container.decode(Bool.self, forKey: .isStrikethrough)) ?? false
        self.isAllCaps = (try? container.decode(Bool.self, forKey: .isAllCaps)) ?? false
        self.alignment = (try? container.decode(TextAlignmentType.self, forKey: .alignment)) ?? .center
        self.characterSpacing = (try? container.decode(Double.self, forKey: .characterSpacing)) ?? 0.0
        self.lineSpacing = (try? container.decode(Double.self, forKey: .lineSpacing)) ?? 4.0
        self.hasStroke = (try? container.decode(Bool.self, forKey: .hasStroke)) ?? false
        self.strokeColorHex = (try? container.decode(String.self, forKey: .strokeColorHex)) ?? "#000000"
        self.strokeWidth = (try? container.decode(Double.self, forKey: .strokeWidth)) ?? 2.0
        self.hasShadow = (try? container.decode(Bool.self, forKey: .hasShadow)) ?? false
        self.shadowColorHex = (try? container.decode(String.self, forKey: .shadowColorHex)) ?? "#000000"
        self.shadowRadius = (try? container.decode(Double.self, forKey: .shadowRadius)) ?? 6.0
        self.shadowOffsetX = (try? container.decode(Double.self, forKey: .shadowOffsetX)) ?? 2.0
        self.shadowOffsetY = (try? container.decode(Double.self, forKey: .shadowOffsetY)) ?? 2.0
        self.hasGlow = (try? container.decode(Bool.self, forKey: .hasGlow)) ?? false
        self.glowColorHex = (try? container.decode(String.self, forKey: .glowColorHex)) ?? "#FFD700"
        self.glowRadius = (try? container.decode(Double.self, forKey: .glowRadius)) ?? 8.0
        self.hasBackground = (try? container.decode(Bool.self, forKey: .hasBackground)) ?? false
        self.backgroundColorHex = (try? container.decode(String.self, forKey: .backgroundColorHex)) ?? "#000000B2"
        self.backgroundCornerRadius = (try? container.decode(Double.self, forKey: .backgroundCornerRadius)) ?? 8.0
        self.backgroundPadding = (try? container.decode(Double.self, forKey: .backgroundPadding)) ?? 12.0
        self.positionX = (try? container.decode(Double.self, forKey: .positionX)) ?? 0.0
        self.positionY = (try? container.decode(Double.self, forKey: .positionY)) ?? 0.0
        self.scale = (try? container.decode(Double.self, forKey: .scale)) ?? 1.0
        self.rotation = (try? container.decode(Double.self, forKey: .rotation)) ?? 0.0
        self.opacity = (try? container.decode(Double.self, forKey: .opacity)) ?? 1.0
        self.animation = (try? container.decode(TextAnimationConfiguration.self, forKey: .animation)) ?? TextAnimationConfiguration()
    }

    public func encodeToJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> TextConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TextConfiguration.self, from: data)
    }
}
