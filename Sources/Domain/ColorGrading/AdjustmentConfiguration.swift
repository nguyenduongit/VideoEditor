import Foundation

/// Đại diện cho 1 kênh màu trong hệ HSL (-100 ... +100 trên UI)
public struct HSLChannel: Codable, Equatable, Sendable {
    public var hue: Float = 0.0          // Sắc độ (-100 ... +100, tương ứng -180° ... +180°)
    public var saturation: Float = 0.0   // Độ bão hòa (-100 ... +100)
    public var luminance: Float = 0.0    // Độ sáng / Brightness (-100 ... +100)

    public init(hue: Float = 0.0, saturation: Float = 0.0, luminance: Float = 0.0) {
        self.hue = hue
        self.saturation = saturation
        self.luminance = luminance
    }

    public var isNeutral: Bool {
        abs(hue) < 0.001 && abs(saturation) < 0.001 && abs(luminance) < 0.001
    }
}

/// 8 kênh màu HSL độc lập
public struct HSLAdjustments: Codable, Equatable, Sendable {
    public var red = HSLChannel()
    public var orange = HSLChannel()
    public var yellow = HSLChannel()
    public var green = HSLChannel()
    public var cyan = HSLChannel()
    public var blue = HSLChannel()
    public var purple = HSLChannel()
    public var magenta = HSLChannel()

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

/// Các thông số chỉnh màu cơ bản (Basic): White Balance & Tone (-100 ... +100 trên UI)
public struct BasicGradingParameters: Codable, Equatable, Sendable {
    public var temp: Float = 0.0         // Nhiệt độ màu (Ấm / Lạnh)
    public var tint: Float = 0.0         // Sắc thái (Xanh lá / Tím)
    public var saturation: Float = 0.0   // Độ bão hòa màu

    public var exposure: Float = 0.0     // Phơi sáng
    public var contrast: Float = 0.0     // Độ tương phản
    public var highlight: Float = 0.0    // Vùng sáng
    public var shadow: Float = 0.0       // Vùng tối
    public var white: Float = 0.0        // Điểm trắng
    public var black: Float = 0.0        // Điểm đen
    public var brilliance: Float = 0.0   // Độ tươi màu (Vibrance)

    public init(
        temp: Float = 0.0,
        tint: Float = 0.0,
        saturation: Float = 0.0,
        exposure: Float = 0.0,
        contrast: Float = 0.0,
        highlight: Float = 0.0,
        shadow: Float = 0.0,
        white: Float = 0.0,
        black: Float = 0.0,
        brilliance: Float = 0.0
    ) {
        self.temp = temp
        self.tint = tint
        self.saturation = saturation
        self.exposure = exposure
        self.contrast = contrast
        self.highlight = highlight
        self.shadow = shadow
        self.white = white
        self.black = black
        self.brilliance = brilliance
    }

    public var isNeutral: Bool {
        abs(temp) < 0.001 && abs(tint) < 0.001 && abs(saturation) < 0.001 &&
        abs(exposure) < 0.001 && abs(contrast) < 0.001 && abs(highlight) < 0.001 &&
        abs(shadow) < 0.001 && abs(white) < 0.001 && abs(black) < 0.001 &&
        abs(brilliance) < 0.001
    }
}

/// Toàn bộ cấu hình chỉnh màu cho đối tượng Adjustment Layer
public struct AdjustmentConfiguration: Codable, Equatable, Sendable {
    public var basic: BasicGradingParameters
    public var hsl: HSLAdjustments

    public init(
        basic: BasicGradingParameters = BasicGradingParameters(),
        hsl: HSLAdjustments = HSLAdjustments()
    ) {
        self.basic = basic
        self.hsl = hsl
    }

    public var isNeutral: Bool {
        basic.isNeutral && hsl.isNeutral
    }

    public func encodeToJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> AdjustmentConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AdjustmentConfiguration.self, from: data)
    }
}
