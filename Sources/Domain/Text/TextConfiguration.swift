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

    public init(
        content: String = "Văn bản",
        fontName: String = "Helvetica",
        fontSize: Double = 48.0,
        textColorHex: String = "#FFFFFF",
        isBold: Bool = false,
        isItalic: Bool = false,
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
        hasBackground: Bool = false,
        backgroundColorHex: String = "#000000B2",
        backgroundCornerRadius: Double = 8.0,
        backgroundPadding: Double = 12.0,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        opacity: Double = 1.0
    ) {
        self.content = content
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.isBold = isBold
        self.isItalic = isItalic
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
        self.hasBackground = hasBackground
        self.backgroundColorHex = backgroundColorHex
        self.backgroundCornerRadius = backgroundCornerRadius
        self.backgroundPadding = backgroundPadding
        self.positionX = positionX
        self.positionY = positionY
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
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
