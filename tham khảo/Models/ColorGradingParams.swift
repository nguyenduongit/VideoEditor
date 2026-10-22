import Foundation

/// Đại diện cho 1 kênh màu trong hệ HSL
public struct HSLChannel: Codable, Equatable, Sendable {
    public var hue: Float = 0.0          // Sắc độ (-1.0 ... 1.0, tương ứng -180° ... +180°)
    public var saturation: Float = 0.0   // Độ bão hòa (-1.0 ... 1.0, tương ứng -100% ... +100%)
    public var luminance: Float = 0.0    // Độ sáng (-1.0 ... 1.0, tương ứng -100% ... +100%)

    public init(hue: Float = 0.0, saturation: Float = 0.0, luminance: Float = 0.0) {
        self.hue = hue
        self.saturation = saturation
        self.luminance = luminance
    }

    public var isNeutral: Bool {
        abs(hue) < 0.001 && abs(saturation) < 0.001 && abs(luminance) < 0.001
    }
}

/// Tập hợp 8 dải màu HSL độc lập cho phép tinh chỉnh màu sắc chi tiết
public struct HSLAdjustments: Codable, Equatable, Sendable {
    public var red: HSLChannel = HSLChannel()
    public var orange: HSLChannel = HSLChannel()
    public var yellow: HSLChannel = HSLChannel()
    public var green: HSLChannel = HSLChannel()
    public var cyan: HSLChannel = HSLChannel()
    public var blue: HSLChannel = HSLChannel()
    public var purple: HSLChannel = HSLChannel()
    public var magenta: HSLChannel = HSLChannel()

    public init() {}

    public var isNeutral: Bool {
        red.isNeutral && orange.isNeutral && yellow.isNeutral &&
        green.isNeutral && cyan.isNeutral && blue.isNeutral &&
        purple.isNeutral && magenta.isNeutral
    }

    public subscript(index: Int) -> HSLChannel {
        get {
            switch index {
            case 0: return red
            case 1: return orange
            case 2: return yellow
            case 3: return green
            case 4: return cyan
            case 5: return blue
            case 6: return purple
            case 7: return magenta
            default: return red
            }
        }
        set {
            switch index {
            case 0: red = newValue
            case 1: orange = newValue
            case 2: yellow = newValue
            case 3: green = newValue
            case 4: cyan = newValue
            case 5: blue = newValue
            case 6: purple = newValue
            case 7: magenta = newValue
            default: break
            }
        }
    }
}

/// Bộ thông số hoàn chỉnh áp dụng cho bộ lọc màu (Color Grading)
public struct ColorGradingParams: Sendable {
    public let saturation: Float
    public let contrast: Float
    public let brightness: Float
    public let shadowAmount: Float
    public let highlightAmount: Float
    public let vibrance: Float
    public let temperatureOffset: Float // Bù trừ nhiệt độ màu Kelvin (Ấm / Lạnh)
    public let tintOffset: Float        // Bù trừ sắc thái Tint (Xanh lục / Tím - Green / Magenta)
    public let whites: Float
    public let blacks: Float
    public let hsl: HSLAdjustments
    public let presetIndex: Int
    public let presetIntensity: Float
    
    public init(
        saturation: Float,
        contrast: Float,
        brightness: Float,
        shadowAmount: Float = 0.0,
        highlightAmount: Float = 0.0,
        vibrance: Float = 0.0,
        temperatureOffset: Float = 0.0,
        tintOffset: Float = 0.0,
        whites: Float = 0.0,
        blacks: Float = 0.0,
        hsl: HSLAdjustments = HSLAdjustments(),
        presetIndex: Int = 0,
        presetIntensity: Float = 1.0
    ) {
        self.saturation = saturation
        self.contrast = contrast
        self.brightness = brightness
        self.shadowAmount = shadowAmount
        self.highlightAmount = highlightAmount
        self.vibrance = vibrance
        self.temperatureOffset = temperatureOffset
        self.tintOffset = tintOffset
        self.whites = whites
        self.blacks = blacks
        self.hsl = hsl
        self.presetIndex = presetIndex
        self.presetIntensity = presetIntensity
    }
}
