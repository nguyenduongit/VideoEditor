import Foundation

/// Tọa độ dịch chuyển màu trên bánh xe màu và thanh gạt Master Luma
public struct ColorWheelOffset: Codable, Equatable, Sendable {
    public var x: Float = 0.0       // Trục ngang (-1.0 ... 1.0)
    public var y: Float = 0.0       // Trục dọc (-1.0 ... 1.0)
    public var luma: Float = 0.0    // Master Luma Slider (-100.0 ... +100.0)

    public init(x: Float = 0.0, y: Float = 0.0, luma: Float = 0.0) {
        self.x = x
        self.y = y
        self.luma = luma
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.x = (try? c.decodeIfPresent(Float.self, forKey: .x)) ?? 0.0
        self.y = (try? c.decodeIfPresent(Float.self, forKey: .y)) ?? 0.0
        self.luma = (try? c.decodeIfPresent(Float.self, forKey: .luma)) ?? 0.0
    }

    public var isNeutral: Bool {
        abs(x) < 0.001 && abs(y) < 0.001 && abs(luma) < 0.001
    }
}

/// 3 bánh xe màu chuyên nghiệp: Lift (Shadows), Gamma (Midtones), Gain (Highlights)
public struct ColorWheelsAdjustments: Codable, Equatable, Sendable {
    public var lift = ColorWheelOffset()    // Vùng tối (Shadows)
    public var gamma = ColorWheelOffset()   // Vùng trung (Midtones)
    public var gain = ColorWheelOffset()    // Vùng sáng (Highlights)

    public init(
        lift: ColorWheelOffset = ColorWheelOffset(),
        gamma: ColorWheelOffset = ColorWheelOffset(),
        gain: ColorWheelOffset = ColorWheelOffset()
    ) {
        self.lift = lift
        self.gamma = gamma
        self.gain = gain
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.lift = (try? c.decodeIfPresent(ColorWheelOffset.self, forKey: .lift)) ?? ColorWheelOffset()
        self.gamma = (try? c.decodeIfPresent(ColorWheelOffset.self, forKey: .gamma)) ?? ColorWheelOffset()
        self.gain = (try? c.decodeIfPresent(ColorWheelOffset.self, forKey: .gain)) ?? ColorWheelOffset()
    }

    public var isNeutral: Bool {
        lift.isNeutral && gamma.isNeutral && gain.isNeutral
    }
}
