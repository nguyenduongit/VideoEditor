import Foundation

/// Điểm neo trên đồ thị đường cong màu 2D (tọa độ chuẩn hóa 0.0 ... 1.0)
public struct CurvePoint: Codable, Equatable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = max(0.0, min(1.0, x))
        self.y = max(0.0, min(1.0, y))
    }
}

/// 4 kênh đường cong màu: Master Luma, Red, Green, Blue
public struct ColorCurvesAdjustments: Codable, Equatable, Sendable {
    public static let defaultLinear: [CurvePoint] = [
        CurvePoint(x: 0.0, y: 0.0),
        CurvePoint(x: 1.0, y: 1.0)
    ]

    public var master: [CurvePoint]
    public var red: [CurvePoint]
    public var green: [CurvePoint]
    public var blue: [CurvePoint]

    public init(
        master: [CurvePoint] = ColorCurvesAdjustments.defaultLinear,
        red: [CurvePoint] = ColorCurvesAdjustments.defaultLinear,
        green: [CurvePoint] = ColorCurvesAdjustments.defaultLinear,
        blue: [CurvePoint] = ColorCurvesAdjustments.defaultLinear
    ) {
        self.master = master
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.master = (try? c.decodeIfPresent([CurvePoint].self, forKey: .master)) ?? Self.defaultLinear
        self.red = (try? c.decodeIfPresent([CurvePoint].self, forKey: .red)) ?? Self.defaultLinear
        self.green = (try? c.decodeIfPresent([CurvePoint].self, forKey: .green)) ?? Self.defaultLinear
        self.blue = (try? c.decodeIfPresent([CurvePoint].self, forKey: .blue)) ?? Self.defaultLinear
    }

    public var isNeutral: Bool {
        isLinear(master) && isLinear(red) && isLinear(green) && isLinear(blue)
    }

    private func isLinear(_ points: [CurvePoint]) -> Bool {
        guard points.count == 2 else { return false }
        return abs(points[0].x - 0.0) < 0.001 && abs(points[0].y - 0.0) < 0.001 &&
               abs(points[1].x - 1.0) < 0.001 && abs(points[1].y - 1.0) < 0.001
    }
}
