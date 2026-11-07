import Foundation

/// Căn lề cho dòng văn bản đơn
public enum TextAlignmentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case left
    case center
    case right

    public var id: Self { self }
}

/// Chế độ tô màu mặt chữ (chỉ giữ Solid và Linear Gradient chuyên nghiệp; tương thích ngược khi giải mã JSON cũ)
public enum TextColorFillMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case solid
    case linearGradient

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .linearGradient: return "Linear"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "solid"
        switch raw {
        case "linearGradient", "radialGradient":
            self = .linearGradient
        default:
            self = .solid
        }
    }
}

/// Chế độ hòa trộn màu (Blend Mode) dùng chung cho Background của Text và Sticker
public enum TextLayerBlendMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case normal
    case screen
    case overlay
    case add
    case multiply

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .add: return "Add (Glow)"
        case .multiply: return "Multiply"
        }
    }

    public var ciFilterName: String {
        switch self {
        case .normal: return "CISourceOverCompositing"
        case .screen: return "CIScreenBlendMode"
        case .overlay: return "CIOverlayBlendMode"
        case .add: return "CIAdditionCompositing"
        case .multiply: return "CIMultiplyCompositing"
        }
    }
}

/// Cấu hình một đường viền độc lập của chữ (dùng đối xứng cho cả Stroke 1 - Trong và Stroke 2 - Ngoài)
public struct TextStrokeStyle: Codable, Equatable, Hashable, Sendable {
    public var isEnabled: Bool
    public var width: Double
    public var colorHex: String
    public var isGradient: Bool
    public var gradientColors: [String]
    public var gradientAngle: Double

    public init(
        isEnabled: Bool = true,
        width: Double = 0.0,
        colorHex: String = "#FFFFFF",
        isGradient: Bool = false,
        gradientColors: [String] = ["#FFD700", "#FF2A85"],
        gradientAngle: Double = 90.0
    ) {
        self.isEnabled = isEnabled
        self.width = max(0.0, min(45.0, width))
        self.colorHex = colorHex
        self.isGradient = isGradient
        self.gradientColors = gradientColors.count >= 2 ? gradientColors : ["#FFD700", "#FF2A85"]
        self.gradientAngle = gradientAngle
    }

    public var isActive: Bool {
        isEnabled && width > 0.05
    }

    public var fillMode: TextColorFillMode {
        get { isGradient ? .linearGradient : .solid }
        set { isGradient = (newValue == .linearGradient) }
    }
}

/// Cấu hình phát sáng hào quang (Outer Glow) trong Subtab Style
public struct TextGlowStyle: Codable, Equatable, Hashable, Sendable {
    public var isEnabled: Bool
    public var colorHex: String
    public var intensity: Double
    public var range: Double

    public init(
        isEnabled: Bool = true,
        colorHex: String = "NONE",
        intensity: Double = 80.0,
        range: Double = 10.0
    ) {
        self.isEnabled = isEnabled
        self.colorHex = colorHex
        self.intensity = max(0.0, min(100.0, intensity))
        self.range = max(0.0, min(60.0, range))
    }

    public var isActive: Bool {
        isEnabled && colorHex.uppercased() != "NONE" && intensity > 0.5 && range > 0.1
    }
}

/// Cấu hình đổ bóng chuyên sâu kiểu CapCut (Opacity, Blur, Distance, Angle) trong Subtab Style
public struct TextShadowStyle: Codable, Equatable, Hashable, Sendable {
    public var isEnabled: Bool
    public var colorHex: String
    public var opacity: Double
    public var blur: Double
    public var distance: Double
    public var angleDegrees: Double

    public init(
        isEnabled: Bool = true,
        colorHex: String = "NONE",
        opacity: Double = 75.0,
        blur: Double = 6.0,
        distance: Double = 4.0,
        angleDegrees: Double = -45.0
    ) {
        self.isEnabled = isEnabled
        self.colorHex = colorHex
        self.opacity = max(0.0, min(100.0, opacity))
        self.blur = max(0.0, min(50.0, blur))
        self.distance = max(0.0, min(80.0, distance))
        self.angleDegrees = max(-180.0, min(180.0, angleDegrees))
    }

    public var isActive: Bool {
        isEnabled && colorHex.uppercased() != "NONE" && opacity > 0.5
    }

    public var offsetX: Double {
        let rad = angleDegrees * .pi / 180.0
        return cos(rad) * distance
    }

    public var offsetY: Double {
        let rad = angleDegrees * .pi / 180.0
        return -sin(rad) * distance
    }
}

/// Kiểu hình học đường cong chữ chuyên nghiệp trong Subtab Curved
public enum TextCurveShape: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case arc
    case wave

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .arc: return "Arc"
        case .wave: return "Wave"
        }
    }
}

/// Cấu hình uốn cong chữ tham số hóa (Cung tròn Arc & Sóng hình sin Wave)
public struct TextCurveStyle: Codable, Equatable, Hashable, Sendable {
    public var shape: TextCurveShape
    public var angleDegrees: Double
    public var radiusOffset: Double
    public var waveAmplitude: Double
    public var wavelength: Double
    public var followTangent: Bool

    public init(
        shape: TextCurveShape = .none,
        angleDegrees: Double = 60.0,
        radiusOffset: Double = 0.0,
        waveAmplitude: Double = 24.0,
        wavelength: Double = 220.0,
        followTangent: Bool = true
    ) {
        self.shape = shape
        self.angleDegrees = max(-360.0, min(360.0, angleDegrees))
        self.radiusOffset = max(-200.0, min(500.0, radiusOffset))
        self.waveAmplitude = max(-120.0, min(120.0, waveAmplitude))
        self.wavelength = max(60.0, min(800.0, wavelength))
        self.followTangent = followTangent
    }

    public var isActive: Bool {
        switch shape {
        case .none: return false
        case .arc: return abs(angleDegrees) > 0.5
        case .wave: return abs(waveAmplitude) > 0.5
        }
    }
}
