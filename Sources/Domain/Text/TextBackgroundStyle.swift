import Foundation

/// Loại nguồn nền của Tab Background trên Text Clip
public enum TextBackgroundSourceKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case solid
    case linearGradient
    case radialGradient
    case inlineSVG
    case animatedAsset

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .solid: return "Solid Color"
        case .linearGradient: return "Linear Gradient"
        case .radialGradient: return "Radial Gradient"
        case .inlineSVG: return "SVG Vector"
        case .animatedAsset: return "Image / GIF / APNG"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "solid"
        switch raw {
        case "linearGradient": self = .linearGradient
        case "radialGradient": self = .radialGradient
        case "inlineSVG": self = .inlineSVG
        case "animatedAsset": self = .animatedAsset
        default: self = .solid
        }
    }
}

/// Chế độ co giãn ảnh/SVG bên trong khung nền tự do
public enum TextBackgroundContentFitMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case fill
    case fit
    case stretch

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .fill: return "Fill"
        case .fit: return "Fit"
        case .stretch: return "Stretch"
        }
    }
}

/// Cấu hình nền thống nhất duy nhất cho Tab Background của Text Clip.
/// Tự động bám theo tâm/góc xoay/tỉ lệ của dòng chữ và hỗ trợ đồng bộ chuyển động cùng Animation của chữ.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public struct TextBackgroundStyle: Codable, Equatable, Hashable, Sendable {
    public var isEnabled: Bool
    public var sourceKind: TextBackgroundSourceKind
    public var solidColorHex: String
    public var gradientColorsHex: [String]
    public var gradientAngleDegrees: Double
    public var svgMarkup: String
    public var assetPathOrURL: String

    // MARK: - Trang trí khung hộp (Box Styling)
    public var cornerRadius: Double
    public var borderWidth: Double
    public var borderColorHex: String
    public var hasShadow: Bool
    public var shadowColorHex: String
    public var shadowBlur: Double
    public var shadowDistance: Double
    public var shadowAngleDegrees: Double
    public var featherRadius: Double
    public var blendMode: TextLayerBlendMode
    public var opacity: Double

    // MARK: - Kích thước & Bố cục tương đối theo chữ
    public var fitToTextBounds: Bool
    public var paddingX: Double
    public var paddingY: Double
    public var customWidth: Double
    public var customHeight: Double
    public var contentFitMode: TextBackgroundContentFitMode
    public var offsetX: Double
    public var offsetY: Double

    // MARK: - Điều khiển phát ảnh động & Đồng bộ Animation
    public var loopAsset: Bool
    public var assetSpeed: Double
    public var animateWithText: Bool

    public init(
        isEnabled: Bool = true,
        sourceKind: TextBackgroundSourceKind = .solid,
        solidColorHex: String = "NONE",
        gradientColorsHex: [String] = ["#FF2A85", "#7928CA"],
        gradientAngleDegrees: Double = 45.0,
        svgMarkup: String = "",
        assetPathOrURL: String = "",
        cornerRadius: Double = 10.0,
        borderWidth: Double = 0.0,
        borderColorHex: String = "NONE",
        hasShadow: Bool = true,
        shadowColorHex: String = "NONE",
        shadowBlur: Double = 8.0,
        shadowDistance: Double = 4.0,
        shadowAngleDegrees: Double = -45.0,
        featherRadius: Double = 0.0,
        blendMode: TextLayerBlendMode = .normal,
        opacity: Double = 1.0,
        fitToTextBounds: Bool = true,
        paddingX: Double = 18.0,
        paddingY: Double = 12.0,
        customWidth: Double = 360.0,
        customHeight: Double = 120.0,
        contentFitMode: TextBackgroundContentFitMode = .fill,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        loopAsset: Bool = true,
        assetSpeed: Double = 1.0,
        animateWithText: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.sourceKind = sourceKind
        self.solidColorHex = solidColorHex
        self.gradientColorsHex = gradientColorsHex.count >= 2 ? gradientColorsHex : ["#FF2A85", "#7928CA"]
        self.gradientAngleDegrees = gradientAngleDegrees
        self.svgMarkup = svgMarkup
        self.assetPathOrURL = assetPathOrURL
        self.cornerRadius = max(0.0, cornerRadius)
        self.borderWidth = max(0.0, min(24.0, borderWidth))
        self.borderColorHex = borderColorHex
        self.hasShadow = hasShadow
        self.shadowColorHex = shadowColorHex
        self.shadowBlur = max(0.0, shadowBlur)
        self.shadowDistance = max(0.0, shadowDistance)
        self.shadowAngleDegrees = shadowAngleDegrees
        self.featherRadius = max(0.0, min(40.0, featherRadius))
        self.blendMode = blendMode
        self.opacity = max(0.0, min(1.0, opacity))
        self.fitToTextBounds = fitToTextBounds
        self.paddingX = max(0.0, paddingX)
        self.paddingY = max(0.0, paddingY)
        self.customWidth = max(20.0, customWidth)
        self.customHeight = max(20.0, customHeight)
        self.contentFitMode = contentFitMode
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.loopAsset = loopAsset
        self.assetSpeed = max(0.25, min(4.0, assetSpeed))
        self.animateWithText = animateWithText
    }

    public var isActive: Bool {
        guard isEnabled && opacity > 0.005 else { return false }
        let hasSource: Bool = {
            switch sourceKind {
            case .solid:
                return solidColorHex.uppercased() != "NONE" && !solidColorHex.isEmpty
            case .linearGradient, .radialGradient:
                return gradientColorsHex.contains { $0.uppercased() != "NONE" && !$0.isEmpty }
            case .inlineSVG:
                return !svgMarkup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .animatedAsset:
                return !assetPathOrURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }()
        let hasBorder = borderWidth > 0.1 && borderColorHex.uppercased() != "NONE"
        let hasBoxShadow = hasShadow && shadowColorHex.uppercased() != "NONE" && (shadowBlur > 0.1 || shadowDistance > 0.1)
        return hasSource || hasBorder || hasBoxShadow
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        let rawSource = (try? c.decodeIfPresent(String.self, forKey: .init("sourceKind"))) ?? "solid"
        let decodedEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .init("isEnabled"))) ?? true
        self.isEnabled = (rawSource == "none") ? false : decodedEnabled
        self.sourceKind = (try? c.decodeIfPresent(TextBackgroundSourceKind.self, forKey: .init("sourceKind"))) ?? .solid
        let rawSolidHex = (try? c.decodeIfPresent(String.self, forKey: .init("solidColorHex"))) ?? "NONE"
        self.solidColorHex = (rawSource == "none" || !decodedEnabled) ? "NONE" : rawSolidHex
        let cols = (try? c.decodeIfPresent([String].self, forKey: .init("gradientColorsHex"))) ?? ["#FF2A85", "#7928CA"]
        self.gradientColorsHex = cols.count >= 2 ? cols : ["#FF2A85", "#7928CA"]
        self.gradientAngleDegrees = (try? c.decodeIfPresent(Double.self, forKey: .init("gradientAngleDegrees"))) ?? 45.0
        self.svgMarkup = (try? c.decodeIfPresent(String.self, forKey: .init("svgMarkup"))) ?? ""
        let pathOrURL = (try? c.decodeIfPresent(String.self, forKey: .init("assetPathOrURL")))
            ?? (try? c.decodeIfPresent(String.self, forKey: .init("assetPath"))) ?? ""
        self.assetPathOrURL = pathOrURL
        self.cornerRadius = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("cornerRadius"))) ?? 10.0)
        self.borderWidth = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("borderWidth"))) ?? 0.0)
        self.borderColorHex = (try? c.decodeIfPresent(String.self, forKey: .init("borderColorHex"))) ?? "NONE"
        self.hasShadow = (try? c.decodeIfPresent(Bool.self, forKey: .init("hasShadow"))) ?? true
        self.shadowColorHex = (try? c.decodeIfPresent(String.self, forKey: .init("shadowColorHex"))) ?? "NONE"
        self.shadowBlur = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("shadowBlur"))) ?? 8.0)
        self.shadowDistance = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("shadowDistance"))) ?? 4.0)
        self.shadowAngleDegrees = (try? c.decodeIfPresent(Double.self, forKey: .init("shadowAngleDegrees"))) ?? -45.0
        self.featherRadius = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("featherRadius"))) ?? 0.0)
        self.blendMode = (try? c.decodeIfPresent(TextLayerBlendMode.self, forKey: .init("blendMode"))) ?? .normal
        self.opacity = max(0.0, min(1.0, (try? c.decodeIfPresent(Double.self, forKey: .init("opacity"))) ?? 1.0))
        self.fitToTextBounds = (try? c.decodeIfPresent(Bool.self, forKey: .init("fitToTextBounds"))) ?? true
        self.paddingX = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("paddingX"))) ?? 18.0)
        self.paddingY = max(0.0, (try? c.decodeIfPresent(Double.self, forKey: .init("paddingY"))) ?? 12.0)
        self.customWidth = max(20.0, (try? c.decodeIfPresent(Double.self, forKey: .init("customWidth")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .init("width"))) ?? 360.0)
        self.customHeight = max(20.0, (try? c.decodeIfPresent(Double.self, forKey: .init("customHeight")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .init("height"))) ?? 120.0)
        self.contentFitMode = (try? c.decodeIfPresent(TextBackgroundContentFitMode.self, forKey: .init("contentFitMode"))) ?? .fill
        self.offsetX = (try? c.decodeIfPresent(Double.self, forKey: .init("offsetX")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .init("positionX"))) ?? 0.0
        self.offsetY = (try? c.decodeIfPresent(Double.self, forKey: .init("offsetY")))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .init("positionY"))) ?? 0.0
        self.loopAsset = (try? c.decodeIfPresent(Bool.self, forKey: .init("loopAsset"))) ?? true
        self.assetSpeed = max(0.25, min(4.0, (try? c.decodeIfPresent(Double.self, forKey: .init("assetSpeed"))) ?? 1.0))
        self.animateWithText = (try? c.decodeIfPresent(Bool.self, forKey: .init("animateWithText"))) ?? true
    }
}

internal struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
