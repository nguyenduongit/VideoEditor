import Foundation

/// Parametric 2D trajectory in `em` units supporting Cubic Bezier, Catmull-Rom Spline, and Orbital Arcs.
public enum TextAnimationMotionPath: Codable, Hashable, Sendable {
    public struct Point: Codable, Hashable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public enum SampleOutput: String, Codable, Hashable, Sendable {
        case positionX
        case positionY
        case tangentDegrees
    }

    case cubicBezier(p0: Point, c1: Point, c2: Point, p1: Point)
    case catmullRom(points: [Point], isClosed: Bool)
    case orbitalArc(radiusX: Double, radiusY: Double, startDegrees: Double, endDegrees: Double)

    public func sample(at rawT: Double) -> (x: Double, y: Double, tangentDegrees: Double) {
        let t = min(1.0, max(0.0, rawT))
        switch self {
        case .cubicBezier(let p0, let c1, let c2, let p1):
            return Self.sampleCubicBezier(p0: p0, c1: c1, c2: c2, p1: p1, t: t)
        case .catmullRom(let points, let isClosed):
            return Self.sampleCatmullRom(points: points, isClosed: isClosed, t: t)
        case .orbitalArc(let rx, let ry, let startDeg, let endDeg):
            return Self.sampleOrbitalArc(radiusX: rx, radiusY: ry, startDegrees: startDeg, endDegrees: endDeg, t: t)
        }
    }

    public func sampleValue(for output: SampleOutput, at rawT: Double) -> Double {
        let result = sample(at: rawT)
        switch output {
        case .positionX: return result.x
        case .positionY: return result.y
        case .tangentDegrees: return result.tangentDegrees
        }
    }

    private static func sampleCubicBezier(
        p0: Point, c1: Point, c2: Point, p1: Point, t: Double
    ) -> (x: Double, y: Double, tangentDegrees: Double) {
        let u = 1.0 - t
        let uu = u * u
        let tt = t * t
        let x = uu * u * p0.x + 3.0 * uu * t * c1.x + 3.0 * u * tt * c2.x + tt * t * p1.x
        let y = uu * u * p0.y + 3.0 * uu * t * c1.y + 3.0 * u * tt * c2.y + tt * t * p1.y

        var dx = 3.0 * uu * (c1.x - p0.x) + 6.0 * u * t * (c2.x - c1.x) + 3.0 * tt * (p1.x - c2.x)
        var dy = 3.0 * uu * (c1.y - p0.y) + 6.0 * u * t * (c2.y - c1.y) + 3.0 * tt * (p1.y - c2.y)
        if hypot(dx, dy) < 0.0001 {
            let eps = 0.002
            let tA = max(0.0, t - eps)
            let tB = min(1.0, t + eps)
            let uA = 1.0 - tA, uB = 1.0 - tB
            let pAx = uA * uA * uA * p0.x + 3 * uA * uA * tA * c1.x + 3 * uA * tA * tA * c2.x + tA * tA * tA * p1.x
            let pAy = uA * uA * uA * p0.y + 3 * uA * uA * tA * c1.y + 3 * uA * tA * tA * c2.y + tA * tA * tA * p1.y
            let pBx = uB * uB * uB * p0.x + 3 * uB * uB * tB * c1.x + 3 * uB * tB * tB * c2.x + tB * tB * tB * p1.x
            let pBy = uB * uB * uB * p0.y + 3 * uB * uB * tB * c1.y + 3 * uB * tB * tB * c2.y + tB * tB * tB * p1.y
            dx = pBx - pAx
            dy = pBy - pAy
        }
        let tangent = hypot(dx, dy) > 0.0001 ? atan2(dy, dx) * 180.0 / .pi : 0.0
        return (x, y, tangent)
    }

    private static func sampleCatmullRom(
        points: [Point], isClosed: Bool, t: Double
    ) -> (x: Double, y: Double, tangentDegrees: Double) {
        guard points.count >= 2 else {
            let p = points.first ?? Point(x: 0.0, y: 0.0)
            return (p.x, p.y, 0.0)
        }
        let segCount = isClosed ? points.count : points.count - 1
        let scaled = min(Double(segCount) - 0.000001, max(0.0, t * Double(segCount)))
        let seg = Int(floor(scaled))
        let localT = scaled - Double(seg)

        let p0 = controlPoint(at: seg - 1, in: points, isClosed: isClosed)
        let p1 = controlPoint(at: seg, in: points, isClosed: isClosed)
        let p2 = controlPoint(at: seg + 1, in: points, isClosed: isClosed)
        let p3 = controlPoint(at: seg + 2, in: points, isClosed: isClosed)

        let t2 = localT * localT
        let t3 = t2 * localT
        let x = 0.5 * ((2.0 * p1.x) + (-p0.x + p2.x) * localT +
            (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
            (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)
        let y = 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * localT +
            (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
            (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3)
        let dx = 0.5 * ((-p0.x + p2.x) + 2.0 * (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * localT +
            3.0 * (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t2)
        let dy = 0.5 * ((-p0.y + p2.y) + 2.0 * (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * localT +
            3.0 * (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t2)
        let tangent = hypot(dx, dy) > 0.0001 ? atan2(dy, dx) * 180.0 / .pi : 0.0
        return (x, y, tangent)
    }

    private static func controlPoint(at idx: Int, in points: [Point], isClosed: Bool) -> Point {
        if isClosed {
            let count = points.count
            return points[((idx % count) + count) % count]
        }
        return points[min(points.count - 1, max(0, idx))]
    }

    private static func sampleOrbitalArc(
        radiusX: Double, radiusY: Double, startDegrees: Double, endDegrees: Double, t: Double
    ) -> (x: Double, y: Double, tangentDegrees: Double) {
        let deg = startDegrees + (endDegrees - startDegrees) * t
        let rad = deg * .pi / 180.0
        let x = cos(rad) * radiusX
        let y = sin(rad) * radiusY
        let dirSign = endDegrees >= startDegrees ? 1.0 : -1.0
        let dx = -sin(rad) * radiusX * dirSign
        let dy = cos(rad) * radiusY * dirSign
        let tangent = hypot(dx, dy) > 0.0001 ? atan2(dy, dx) * 180.0 / .pi : 0.0
        return (x, y, tangent)
    }
}
