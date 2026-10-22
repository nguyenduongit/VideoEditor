import Foundation
import CoreMedia

/// A precise rational time representation (value / timescale) for serializable project scripts.
/// Eliminates cumulative floating-point errors (e.g. 29.97, 23.976 fps) and guarantees safe JSON coding.
public struct RationalTime: Codable, Sendable, Hashable, Equatable, Comparable {
    public let value: Int64
    public let timescale: Int32

    public init(value: Int64, timescale: Int32 = TimeRational.defaultFPS) {
        self.value = value
        self.timescale = max(1, timescale)
    }

    public init(cmTime: CMTime) {
        let ts = cmTime.timescale > 1 ? cmTime.timescale : TimeRational.defaultFPS
        let val = cmTime.timescale > 1 ? cmTime.value : (cmTime.value * Int64(TimeRational.defaultFPS))
        self.value = val
        self.timescale = ts
    }

    public var cmTime: CMTime {
        CMTime(value: value, timescale: timescale)
    }

    public var seconds: Double {
        timescale > 0 ? Double(value) / Double(timescale) : 0
    }

    public static let zero = RationalTime(value: 0, timescale: TimeRational.defaultFPS)

    public static func < (lhs: RationalTime, rhs: RationalTime) -> Bool {
        lhs.cmTime < rhs.cmTime
    }

    public static func + (lhs: RationalTime, rhs: RationalTime) -> RationalTime {
        RationalTime(cmTime: lhs.cmTime + rhs.cmTime)
    }

    public static func - (lhs: RationalTime, rhs: RationalTime) -> RationalTime {
        RationalTime(cmTime: lhs.cmTime - rhs.cmTime)
    }
}

/// A precise rational time range (start and duration) for serializable project scripts.
public struct RationalTimeRange: Codable, Sendable, Hashable, Equatable {
    public let start: RationalTime
    public let duration: RationalTime

    public init(start: RationalTime, duration: RationalTime) {
        self.start = start
        self.duration = duration
    }

    public init(cmTimeRange: CMTimeRange) {
        self.start = RationalTime(cmTime: cmTimeRange.start)
        self.duration = RationalTime(cmTime: cmTimeRange.duration)
    }

    public var cmTimeRange: CMTimeRange {
        CMTimeRange(start: start.cmTime, duration: duration.cmTime)
    }

    public var end: RationalTime {
        start + duration
    }

    public static let zero = RationalTimeRange(start: .zero, duration: .zero)
}
