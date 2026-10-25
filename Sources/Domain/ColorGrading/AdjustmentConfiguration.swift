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
    enum CodingKeys: String, CodingKey {
        case hue, saturation, luminance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hue = (try? container.decodeIfPresent(Float.self, forKey: .hue)) ?? 0.0
        self.saturation = (try? container.decodeIfPresent(Float.self, forKey: .saturation)) ?? 0.0
        self.luminance = (try? container.decodeIfPresent(Float.self, forKey: .luminance)) ?? 0.0
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

    enum CodingKeys: String, CodingKey {
        case red, orange, yellow, green, cyan, blue, purple, magenta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.red = (try? container.decodeIfPresent(HSLChannel.self, forKey: .red)) ?? HSLChannel()
        self.orange = (try? container.decodeIfPresent(HSLChannel.self, forKey: .orange)) ?? HSLChannel()
        self.yellow = (try? container.decodeIfPresent(HSLChannel.self, forKey: .yellow)) ?? HSLChannel()
        self.green = (try? container.decodeIfPresent(HSLChannel.self, forKey: .green)) ?? HSLChannel()
        self.cyan = (try? container.decodeIfPresent(HSLChannel.self, forKey: .cyan)) ?? HSLChannel()
        self.blue = (try? container.decodeIfPresent(HSLChannel.self, forKey: .blue)) ?? HSLChannel()
        self.purple = (try? container.decodeIfPresent(HSLChannel.self, forKey: .purple)) ?? HSLChannel()
        self.magenta = (try? container.decodeIfPresent(HSLChannel.self, forKey: .magenta)) ?? HSLChannel()
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

    enum CodingKeys: String, CodingKey {
        case temp, tint, saturation, exposure, contrast, highlight, shadow, white, black, brilliance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.temp = (try? container.decodeIfPresent(Float.self, forKey: .temp)) ?? 0.0
        self.tint = (try? container.decodeIfPresent(Float.self, forKey: .tint)) ?? 0.0
        self.saturation = (try? container.decodeIfPresent(Float.self, forKey: .saturation)) ?? 0.0
        self.exposure = (try? container.decodeIfPresent(Float.self, forKey: .exposure)) ?? 0.0
        self.contrast = (try? container.decodeIfPresent(Float.self, forKey: .contrast)) ?? 0.0
        self.highlight = (try? container.decodeIfPresent(Float.self, forKey: .highlight)) ?? 0.0
        self.shadow = (try? container.decodeIfPresent(Float.self, forKey: .shadow)) ?? 0.0
        self.white = (try? container.decodeIfPresent(Float.self, forKey: .white)) ?? 0.0
        self.black = (try? container.decodeIfPresent(Float.self, forKey: .black)) ?? 0.0
        self.brilliance = (try? container.decodeIfPresent(Float.self, forKey: .brilliance)) ?? 0.0
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
    public var isEnabled: Bool = true
    public var basic: BasicGradingParameters
    public var hsl: HSLAdjustments
    public var wheels: ColorWheelsAdjustments
    public var curves: ColorCurvesAdjustments
    public var effects: EffectsGradingParameters
    public var lut: LUTConfiguration

    public init(
        isEnabled: Bool = true,
        basic: BasicGradingParameters = BasicGradingParameters(),
        hsl: HSLAdjustments = HSLAdjustments(),
        wheels: ColorWheelsAdjustments = ColorWheelsAdjustments(),
        curves: ColorCurvesAdjustments = ColorCurvesAdjustments(),
        effects: EffectsGradingParameters = EffectsGradingParameters(),
        lut: LUTConfiguration = LUTConfiguration()
    ) {
        self.isEnabled = isEnabled
        self.basic = basic
        self.hsl = hsl
        self.wheels = wheels
        self.curves = curves
        self.effects = effects
        self.lut = lut
    }

    public var hasGradingChanges: Bool {
        !basic.isNeutral || !hsl.isNeutral || !wheels.isNeutral ||
        !curves.isNeutral || !effects.isNeutral || !lut.isNeutral
    }

    public var isNeutral: Bool {
        guard isEnabled else { return true }
        return !hasGradingChanges
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled, basic, hsl, wheels, curves, effects, lut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
        self.basic = (try? container.decodeIfPresent(BasicGradingParameters.self, forKey: .basic)) ?? BasicGradingParameters()
        self.hsl = (try? container.decodeIfPresent(HSLAdjustments.self, forKey: .hsl)) ?? HSLAdjustments()
        self.wheels = (try? container.decodeIfPresent(ColorWheelsAdjustments.self, forKey: .wheels)) ?? ColorWheelsAdjustments()
        self.curves = (try? container.decodeIfPresent(ColorCurvesAdjustments.self, forKey: .curves)) ?? ColorCurvesAdjustments()
        self.effects = (try? container.decodeIfPresent(EffectsGradingParameters.self, forKey: .effects)) ?? EffectsGradingParameters()
        self.lut = (try? container.decodeIfPresent(LUTConfiguration.self, forKey: .lut)) ?? LUTConfiguration()
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
