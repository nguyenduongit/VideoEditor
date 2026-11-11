import Foundation

/// Cấu hình lõi đơn dòng duy nhất dùng chung cho cả Người dùng và Mẫu chữ (Text Template).
/// Cấu trúc 3 trụ cột chính: Text (Basic / Dual Stroke / Style / Curved) · Background · Animation.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public struct TextConfiguration: Codable, Equatable, Hashable, Sendable {
    // MARK: - Nội dung đơn dòng & Typography (Subtab Basic)
    private var rawContent: String
    public var content: String {
        get { rawContent }
        set { rawContent = Self.sanitizeSingleLine(newValue) }
    }
    public var fontName: String
    public var fontSize: Double
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderlined: Bool
    public var alignment: TextAlignmentType
    public var characterSpacing: Double

    // MARK: - Tô màu mặt chữ (Solid & Linear Gradient)
    public var colorFillMode: TextColorFillMode
    public var textColorHex: String
    public var gradientColors: [String]
    public var gradientAngle: Double

    // MARK: - 3 Subtab Chuyên Sâu (Dual Stroke · Style [Glow + Shadow] · Curved)
    public var innerStroke: TextStrokeStyle
    public var outerStroke: TextStrokeStyle
    public var glow: TextGlowStyle
    public var shadow: TextShadowStyle
    public var curve: TextCurveStyle

    // MARK: - Tab Background & Tab Animation & Transform
    public var background: TextBackgroundStyle
    public var positionX: Double
    public var positionY: Double
    public var scale: Double
    public var rotation: Double
    public var skewX: Double
    public var skewY: Double
    public var opacity: Double
    public var blurRadius: Double
    public var glitchIntensity: Double
    public var noiseIntensity: Double
    public var animation: TextAnimationConfiguration

    public static func sanitizeSingleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    public init(
        content: String = "Text",
        fontName: String = "Helvetica",
        fontSize: Double = 60.0,
        textColorHex: String = "#FFFFFF",
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        alignment: TextAlignmentType = .center,
        characterSpacing: Double = 0.0,
        colorFillMode: TextColorFillMode = .solid,
        gradientColors: [String] = ["#FF2A85", "#FDE047"],
        gradientAngle: Double = 90.0,
        innerStroke: TextStrokeStyle = TextStrokeStyle(isEnabled: true, width: 0.0, colorHex: "#FFFFFF"),
        outerStroke: TextStrokeStyle = TextStrokeStyle(isEnabled: true, width: 0.0, colorHex: "#EF4444"),
        glow: TextGlowStyle = TextGlowStyle(isEnabled: true, colorHex: "NONE"),
        shadow: TextShadowStyle = TextShadowStyle(isEnabled: true, colorHex: "NONE"),
        curve: TextCurveStyle = TextCurveStyle(),
        background: TextBackgroundStyle = TextBackgroundStyle(isEnabled: true, sourceKind: .solid, solidColorHex: "NONE"),
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        skewX: Double = 0.0,
        skewY: Double = 0.0,
        opacity: Double = 1.0,
        blurRadius: Double = 0.0,
        glitchIntensity: Double = 0.0,
        noiseIntensity: Double = 0.0,
        animation: TextAnimationConfiguration = TextAnimationConfiguration()
    ) {
        self.rawContent = Self.sanitizeSingleLine(content)
        self.fontName = fontName
        self.fontSize = max(8.0, fontSize)
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.alignment = alignment
        self.characterSpacing = characterSpacing
        self.colorFillMode = colorFillMode
        self.textColorHex = textColorHex
        self.gradientColors = gradientColors.count >= 2 ? gradientColors : ["#FF2A85", "#FDE047"]
        self.gradientAngle = gradientAngle
        self.innerStroke = innerStroke
        self.outerStroke = outerStroke
        self.glow = glow
        self.shadow = shadow
        self.curve = curve
        self.background = background
        self.positionX = positionX
        self.positionY = positionY
        self.scale = max(0.05, scale)
        self.rotation = rotation
        self.skewX = max(-60.0, min(60.0, skewX))
        self.skewY = max(-60.0, min(60.0, skewY))
        self.opacity = max(0.0, min(1.0, opacity))
        self.blurRadius = max(0.0, min(60.0, blurRadius))
        self.glitchIntensity = max(0.0, min(100.0, glitchIntensity))
        self.noiseIntensity = max(0.0, min(100.0, noiseIntensity))
        self.animation = animation
    }

    enum CodingKeys: String, CodingKey {
        case content
        case fontName, fontSize, isBold, isItalic, isUnderlined, alignment, characterSpacing
        case colorFillMode, textColorHex, gradientColors, gradientAngle
        case innerStroke, outerStroke, glow, shadow, curve, background
        case positionX, positionY, scale, rotation, skewX, skewY, opacity
        case blurRadius, glitchIntensity, noiseIntensity, animation
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rawContent, forKey: .content)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(isBold, forKey: .isBold)
        try c.encode(isItalic, forKey: .isItalic)
        try c.encode(isUnderlined, forKey: .isUnderlined)
        try c.encode(alignment, forKey: .alignment)
        try c.encode(characterSpacing, forKey: .characterSpacing)
        try c.encode(colorFillMode, forKey: .colorFillMode)
        try c.encode(textColorHex, forKey: .textColorHex)
        try c.encode(gradientColors, forKey: .gradientColors)
        try c.encode(gradientAngle, forKey: .gradientAngle)
        try c.encode(innerStroke, forKey: .innerStroke)
        try c.encode(outerStroke, forKey: .outerStroke)
        try c.encode(glow, forKey: .glow)
        try c.encode(shadow, forKey: .shadow)
        try c.encode(curve, forKey: .curve)
        try c.encode(background, forKey: .background)
        try c.encode(positionX, forKey: .positionX)
        try c.encode(positionY, forKey: .positionY)
        try c.encode(scale, forKey: .scale)
        try c.encode(rotation, forKey: .rotation)
        try c.encode(skewX, forKey: .skewX)
        try c.encode(skewY, forKey: .skewY)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(blurRadius, forKey: .blurRadius)
        try c.encode(glitchIntensity, forKey: .glitchIntensity)
        try c.encode(noiseIntensity, forKey: .noiseIntensity)
        try c.encode(animation, forKey: .animation)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        let decodedText = (try? c.decodeIfPresent(String.self, forKey: .init("content"))) ?? "Text"
        self.rawContent = Self.sanitizeSingleLine(decodedText)
        self.fontName = (try? c.decodeIfPresent(String.self, forKey: .init("fontName"))) ?? "Helvetica"
        self.fontSize = max(8.0, (try? c.decodeIfPresent(Double.self, forKey: .init("fontSize"))) ?? 48.0)
        self.isBold = (try? c.decodeIfPresent(Bool.self, forKey: .init("isBold"))) ?? false
        self.isItalic = (try? c.decodeIfPresent(Bool.self, forKey: .init("isItalic"))) ?? false
        self.isUnderlined = (try? c.decodeIfPresent(Bool.self, forKey: .init("isUnderlined"))) ?? false
        self.alignment = (try? c.decodeIfPresent(TextAlignmentType.self, forKey: .init("alignment"))) ?? .center
        self.characterSpacing = (try? c.decodeIfPresent(Double.self, forKey: .init("characterSpacing"))) ?? 0.0
        self.textColorHex = (try? c.decodeIfPresent(String.self, forKey: .init("textColorHex"))) ?? "#FFFFFF"

        let legacyIsGrad = (try? c.decodeIfPresent(Bool.self, forKey: .init("isGradient"))) ?? false
        self.colorFillMode = (try? c.decodeIfPresent(TextColorFillMode.self, forKey: .init("colorFillMode")))
            ?? (legacyIsGrad ? .linearGradient : .solid)
        let cols = (try? c.decodeIfPresent([String].self, forKey: .init("gradientColors"))) ?? ["#FF2A85", "#FDE047"]
        self.gradientColors = cols.count >= 2 ? cols : ["#FF2A85", "#FDE047"]
        self.gradientAngle = (try? c.decodeIfPresent(Double.self, forKey: .init("gradientAngle"))) ?? 90.0

        self.innerStroke = Self.decodeInnerStroke(from: c)
        self.outerStroke = Self.decodeOuterStroke(from: c)
        self.glow = Self.decodeGlow(from: c)
        self.shadow = Self.decodeShadow(from: c)
        self.curve = Self.decodeCurve(from: c)
        self.background = Self.decodeBackground(from: c)

        self.positionX = (try? c.decodeIfPresent(Double.self, forKey: .init("positionX"))) ?? 0.0
        self.positionY = (try? c.decodeIfPresent(Double.self, forKey: .init("positionY"))) ?? 0.0
        self.scale = max(0.05, (try? c.decodeIfPresent(Double.self, forKey: .init("scale"))) ?? 1.0)
        self.rotation = (try? c.decodeIfPresent(Double.self, forKey: .init("rotation"))) ?? 0.0
        self.skewX = (try? c.decodeIfPresent(Double.self, forKey: .init("skewX"))) ?? 0.0
        self.skewY = (try? c.decodeIfPresent(Double.self, forKey: .init("skewY"))) ?? 0.0
        self.opacity = max(0.0, min(1.0, (try? c.decodeIfPresent(Double.self, forKey: .init("opacity"))) ?? 1.0))
        self.blurRadius = (try? c.decodeIfPresent(Double.self, forKey: .init("blurRadius"))) ?? 0.0
        self.glitchIntensity = (try? c.decodeIfPresent(Double.self, forKey: .init("glitchIntensity"))) ?? 0.0
        self.noiseIntensity = (try? c.decodeIfPresent(Double.self, forKey: .init("noiseIntensity"))) ?? 0.0
        self.animation = (try? c.decodeIfPresent(TextAnimationConfiguration.self, forKey: .init("animation")))
            ?? TextAnimationConfiguration()
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
