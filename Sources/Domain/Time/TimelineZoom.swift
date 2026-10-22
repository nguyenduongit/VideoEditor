import Foundation

public enum TimelineZoom {
    public static let defaultPPS: CGFloat = 60.0
    public static let trailingPadding: CGFloat = 100.0
    public static let minZoomRatio: CGFloat = 0.25
    public static let defaultMaxZoomMultiplier: CGFloat = 16.0
    public static let absoluteMinFramePPS: CGFloat = 600.0

    public static func basePPS(for totalDurationSeconds: Double, viewportWidth: CGFloat) -> CGFloat {
        guard totalDurationSeconds > 0 else { return defaultPPS }
        let availableWidth = max(100.0, viewportWidth - trailingPadding)
        let calculated = availableWidth / CGFloat(totalDurationSeconds)
        return max(0.1, calculated)
    }

    public static func minPPS(basePPS: CGFloat = defaultPPS) -> CGFloat {
        max(0.01, basePPS * minZoomRatio)
    }

    public static func maxPPS(basePPS: CGFloat = defaultPPS) -> CGFloat {
        max(absoluteMinFramePPS, basePPS * defaultMaxZoomMultiplier)
    }

    public static func clamp(pps: CGFloat, basePPS: CGFloat = defaultPPS) -> CGFloat {
        let minVal = minPPS(basePPS: basePPS)
        let maxVal = maxPPS(basePPS: basePPS)
        return min(maxVal, max(minVal, pps))
    }

    public static func zoomIn(from current: CGFloat, basePPS: CGFloat = defaultPPS) -> CGFloat {
        let step = max(0.5, basePPS * 0.15)
        return clamp(pps: current + step, basePPS: basePPS)
    }

    public static func zoomOut(from current: CGFloat, basePPS: CGFloat = defaultPPS) -> CGFloat {
        let step = max(0.5, basePPS * 0.15)
        return clamp(pps: current - step, basePPS: basePPS)
    }

    public static func zoomWithDelta(current: CGFloat, delta: CGFloat, basePPS: CGFloat = defaultPPS) -> CGFloat {
        let factor = max(0.1, 1.0 + (delta * 0.03))
        let newPPS = current * factor
        return clamp(pps: newPPS, basePPS: basePPS)
    }

    public static func anchoredScrollOffset(
        currentScrollOffset: CGFloat,
        cursorXInViewport: CGFloat,
        oldPPS: CGFloat,
        newPPS: CGFloat,
        newContentWidth: CGFloat,
        viewportWidth: CGFloat
    ) -> CGFloat {
        guard oldPPS > 0 else { return currentScrollOffset }
        let targetOffset = (currentScrollOffset + cursorXInViewport) * (newPPS / oldPPS) - cursorXInViewport
        let maxScroll = max(0, newContentWidth - viewportWidth)
        return max(0, min(maxScroll, targetOffset))
    }

    public static func percentage(for pps: CGFloat, basePPS: CGFloat = defaultPPS) -> Int {
        guard basePPS > 0 else { return 100 }
        let pct = (pps / basePPS) * 100.0
        return max(1, Int(round(pct)))
    }

    public static func percentageString(for pps: CGFloat, basePPS: CGFloat = defaultPPS) -> String {
        "\(percentage(for: pps, basePPS: basePPS))%"
    }
}
