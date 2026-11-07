import Foundation

/// Các thuộc tính dẫn xuất rút gọn và bộ giải mã tương thích ngược cho `TextConfiguration`.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TextConfiguration {
    public var isGradient: Bool {
        get { colorFillMode == .linearGradient }
        set { colorFillMode = newValue ? .linearGradient : .solid }
    }
    public var hasStroke: Bool {
        get { innerStroke.isEnabled }
        set { innerStroke.isEnabled = newValue }
    }
    public var strokeColorHex: String {
        get { innerStroke.colorHex }
        set { innerStroke.colorHex = newValue }
    }
    public var strokeWidth: Double {
        get { innerStroke.width }
        set { innerStroke.width = max(0.0, newValue) }
    }
    public var hasOuterStroke: Bool {
        get { outerStroke.isEnabled }
        set { outerStroke.isEnabled = newValue }
    }
    public var outerStrokeColorHex: String {
        get { outerStroke.colorHex }
        set { outerStroke.colorHex = newValue }
    }
    public var outerStrokeWidth: Double {
        get { outerStroke.width }
        set { outerStroke.width = max(0.0, newValue) }
    }
    public var hasGlow: Bool {
        get { glow.isEnabled }
        set { glow.isEnabled = newValue }
    }
    public var glowColorHex: String {
        get { glow.colorHex }
        set { glow.colorHex = newValue }
    }
    public var glowRadius: Double {
        get { glow.range }
        set { glow.range = max(0.0, newValue) }
    }
    public var hasShadow: Bool {
        get { shadow.isEnabled }
        set { shadow.isEnabled = newValue }
    }
    public var shadowColorHex: String {
        get { shadow.colorHex }
        set { shadow.colorHex = newValue }
    }
    public var shadowRadius: Double {
        get { shadow.blur }
        set { shadow.blur = max(0.0, newValue) }
    }
    public var shadowOffsetX: Double {
        get { shadow.offsetX }
        set {
            let curY = shadow.offsetY
            let dist = sqrt(newValue * newValue + curY * curY)
            shadow.distance = dist
            if dist > 0.001 {
                shadow.angleDegrees = atan2(-curY, newValue) * 180.0 / .pi
            }
        }
    }
    public var shadowOffsetY: Double {
        get { shadow.offsetY }
        set {
            let curX = shadow.offsetX
            let dist = sqrt(curX * curX + newValue * newValue)
            shadow.distance = dist
            if dist > 0.001 {
                shadow.angleDegrees = atan2(-newValue, curX) * 180.0 / .pi
            }
        }
    }
    public var hasBackground: Bool {
        get { background.isEnabled }
        set { background.isEnabled = newValue }
    }
    public var backgroundColorHex: String {
        get { background.solidColorHex }
        set { background.solidColorHex = newValue }
    }
    public var backgroundCornerRadius: Double {
        get { background.cornerRadius }
        set { background.cornerRadius = max(0.0, newValue) }
    }
    public var backgroundPadding: Double {
        get { background.paddingX }
        set {
            background.paddingX = max(0.0, newValue)
            background.paddingY = max(0.0, newValue)
        }
    }
    public var backgroundPaddingX: Double {
        get { background.paddingX }
        set { background.paddingX = max(0.0, newValue) }
    }
    public var backgroundPaddingY: Double {
        get { background.paddingY }
        set { background.paddingY = max(0.0, newValue) }
    }
    public var backgroundFeather: Double {
        get { background.featherRadius }
        set { background.featherRadius = max(0.0, newValue) }
    }
    public var backgroundLayer: TextBackgroundStyle {
        get { background }
        set { background = newValue }
    }
    public var isCurved: Bool {
        get { curve.shape != .none }
        set { curve.shape = newValue ? (curve.shape == .none ? .arc : curve.shape) : .none }
    }
    public var curveAngle: Double {
        get { curve.angleDegrees }
        set { curve.angleDegrees = newValue }
    }

    static func decodeInnerStroke(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextStrokeStyle {
        if let s = try? c.decodeIfPresent(TextStrokeStyle.self, forKey: .init("innerStroke")) { return s }
        return TextStrokeStyle(
            isEnabled: (try? c.decodeIfPresent(Bool.self, forKey: .init("hasStroke"))) ?? false,
            width: (try? c.decodeIfPresent(Double.self, forKey: .init("strokeWidth"))) ?? 2.0,
            colorHex: (try? c.decodeIfPresent(String.self, forKey: .init("strokeColorHex"))) ?? "#000000",
            isGradient: (try? c.decodeIfPresent(Bool.self, forKey: .init("innerStrokeIsGradient"))) ?? false,
            gradientColors: (try? c.decodeIfPresent([String].self, forKey: .init("innerStrokeGradientColors"))) ?? ["#FFD700", "#FF2A85"],
            gradientAngle: (try? c.decodeIfPresent(Double.self, forKey: .init("innerStrokeGradientAngle"))) ?? 90.0
        )
    }

    static func decodeOuterStroke(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextStrokeStyle {
        if let s = try? c.decodeIfPresent(TextStrokeStyle.self, forKey: .init("outerStroke")) { return s }
        return TextStrokeStyle(
            isEnabled: (try? c.decodeIfPresent(Bool.self, forKey: .init("hasOuterStroke"))) ?? false,
            width: (try? c.decodeIfPresent(Double.self, forKey: .init("outerStrokeWidth"))) ?? 6.0,
            colorHex: (try? c.decodeIfPresent(String.self, forKey: .init("outerStrokeColorHex"))) ?? "#FFFFFF",
            isGradient: (try? c.decodeIfPresent(Bool.self, forKey: .init("outerStrokeIsGradient"))) ?? false,
            gradientColors: (try? c.decodeIfPresent([String].self, forKey: .init("outerStrokeGradientColors"))) ?? ["#38BDF8", "#818CF8"],
            gradientAngle: (try? c.decodeIfPresent(Double.self, forKey: .init("outerStrokeGradientAngle"))) ?? 90.0
        )
    }

    static func decodeGlow(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextGlowStyle {
        if let g = try? c.decodeIfPresent(TextGlowStyle.self, forKey: .init("glow")) { return g }
        return TextGlowStyle(
            isEnabled: (try? c.decodeIfPresent(Bool.self, forKey: .init("hasGlow"))) ?? false,
            colorHex: (try? c.decodeIfPresent(String.self, forKey: .init("glowColorHex"))) ?? "#FFD700",
            intensity: 80.0,
            range: (try? c.decodeIfPresent(Double.self, forKey: .init("glowRadius"))) ?? 8.0
        )
    }

    static func decodeShadow(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextShadowStyle {
        if let s = try? c.decodeIfPresent(TextShadowStyle.self, forKey: .init("shadow")) { return s }
        let dx = (try? c.decodeIfPresent(Double.self, forKey: .init("shadowOffsetX"))) ?? 2.0
        let dy = (try? c.decodeIfPresent(Double.self, forKey: .init("shadowOffsetY"))) ?? 2.0
        let dist = hypot(dx, dy)
        let ang = dist > 0.001 ? (-atan2(dy, dx) * 180.0 / .pi) : -45.0
        return TextShadowStyle(
            isEnabled: (try? c.decodeIfPresent(Bool.self, forKey: .init("hasShadow"))) ?? false,
            colorHex: (try? c.decodeIfPresent(String.self, forKey: .init("shadowColorHex"))) ?? "#000000",
            opacity: 75.0,
            blur: (try? c.decodeIfPresent(Double.self, forKey: .init("shadowRadius"))) ?? 6.0,
            distance: dist,
            angleDegrees: ang
        )
    }

    static func decodeCurve(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextCurveStyle {
        if let cv = try? c.decodeIfPresent(TextCurveStyle.self, forKey: .init("curve")) { return cv }
        let curved = (try? c.decodeIfPresent(Bool.self, forKey: .init("isCurved"))) ?? false
        let ang = (try? c.decodeIfPresent(Double.self, forKey: .init("curveAngle"))) ?? 60.0
        return TextCurveStyle(shape: curved ? .arc : .none, angleDegrees: ang)
    }

    static func decodeBackground(from c: KeyedDecodingContainer<DynamicCodingKey>) -> TextBackgroundStyle {
        if let bg = try? c.decodeIfPresent(TextBackgroundStyle.self, forKey: .init("background")) { return bg }
        if let legacyLayer = try? c.decodeIfPresent(TextBackgroundStyle.self, forKey: .init("backgroundLayer")),
           legacyLayer.isEnabled {
            return legacyLayer
        }
        let hasBg = (try? c.decodeIfPresent(Bool.self, forKey: .init("hasBackground"))) ?? false
        let hex = (try? c.decodeIfPresent(String.self, forKey: .init("backgroundColorHex"))) ?? "#000000B2"
        let corner = (try? c.decodeIfPresent(Double.self, forKey: .init("backgroundCornerRadius"))) ?? 8.0
        let pad = (try? c.decodeIfPresent(Double.self, forKey: .init("backgroundPadding"))) ?? 12.0
        let padX = (try? c.decodeIfPresent(Double.self, forKey: .init("backgroundPaddingX"))) ?? pad
        let padY = (try? c.decodeIfPresent(Double.self, forKey: .init("backgroundPaddingY"))) ?? pad
        let feather = (try? c.decodeIfPresent(Double.self, forKey: .init("backgroundFeather"))) ?? 0.0
        return TextBackgroundStyle(
            isEnabled: hasBg, sourceKind: .solid, solidColorHex: hex,
            cornerRadius: corner, featherRadius: feather, paddingX: padX, paddingY: padY
        )
    }
}
