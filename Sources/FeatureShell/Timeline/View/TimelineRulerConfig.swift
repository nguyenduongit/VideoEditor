import Foundation
import CoreGraphics

public struct RulerIntervalConfig: Sendable, Equatable {
    public let majorSeconds: Double
    public let subTicks: Int

    public init(majorSeconds: Double, subTicks: Int) {
        self.majorSeconds = majorSeconds
        self.subTicks = subTicks
    }
}

public enum TimelineRulerConfig {
    public static let minPixelDistance: CGFloat = 70.0

    public static let standardIntervals: [RulerIntervalConfig] = [
        RulerIntervalConfig(majorSeconds: 1.0, subTicks: 4),     // 1s
        RulerIntervalConfig(majorSeconds: 2.0, subTicks: 4),     // 2s
        RulerIntervalConfig(majorSeconds: 5.0, subTicks: 5),     // 5s
        RulerIntervalConfig(majorSeconds: 10.0, subTicks: 5),    // 10s
        RulerIntervalConfig(majorSeconds: 15.0, subTicks: 3),    // 15s
        RulerIntervalConfig(majorSeconds: 30.0, subTicks: 6),    // 30s
        RulerIntervalConfig(majorSeconds: 60.0, subTicks: 6),    // 1m (60s)
        RulerIntervalConfig(majorSeconds: 120.0, subTicks: 4),   // 2m (120s)
        RulerIntervalConfig(majorSeconds: 300.0, subTicks: 5),   // 5m (300s)
        RulerIntervalConfig(majorSeconds: 600.0, subTicks: 5),   // 10m (600s)
        RulerIntervalConfig(majorSeconds: 900.0, subTicks: 3),   // 15m (900s)
        RulerIntervalConfig(majorSeconds: 1800.0, subTicks: 6),  // 30m (1800s)
        RulerIntervalConfig(majorSeconds: 3600.0, subTicks: 6),  // 1h (3600s)
        RulerIntervalConfig(majorSeconds: 7200.0, subTicks: 4)   // 2h (7200s)
    ]

    public static func bestInterval(for pixelsPerSecond: CGFloat, minPixelDistance: CGFloat = minPixelDistance) -> RulerIntervalConfig {
        guard pixelsPerSecond > 0 else {
            return standardIntervals.last ?? RulerIntervalConfig(majorSeconds: 60.0, subTicks: 6)
        }
        for interval in standardIntervals {
            let px = CGFloat(interval.majorSeconds) * pixelsPerSecond
            if px >= minPixelDistance {
                return interval
            }
        }
        return standardIntervals.last ?? RulerIntervalConfig(majorSeconds: 7200.0, subTicks: 4)
    }

    public static func formatRulerTime(seconds: Double) -> String {
        let totalSec = max(0, Int(round(seconds)))
        let hrs = totalSec / 3600
        let mins = (totalSec % 3600) / 60
        let secs = totalSec % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
}
