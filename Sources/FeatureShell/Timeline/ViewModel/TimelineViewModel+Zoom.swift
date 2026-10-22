import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public var basePixelsPerSecond: CGFloat {
        let durationSec = CMTimeGetSeconds(totalDuration)
        return TimelineZoom.basePPS(for: durationSec, viewportWidth: viewportWidth)
    }

    public var minPixelsPerSecond: CGFloat {
        TimelineZoom.minPPS(basePPS: basePixelsPerSecond)
    }

    public var maxPixelsPerSecond: CGFloat {
        TimelineZoom.maxPPS(basePPS: basePixelsPerSecond)
    }

    public var zoomPercentageText: String {
        TimelineZoom.percentageString(for: pixelsPerSecond, basePPS: basePixelsPerSecond)
    }

    public func zoomIn() {
        pixelsPerSecond = TimelineZoom.zoomIn(from: pixelsPerSecond, basePPS: basePixelsPerSecond)
    }

    public func zoomOut() {
        pixelsPerSecond = TimelineZoom.zoomOut(from: pixelsPerSecond, basePPS: basePixelsPerSecond)
    }

    public func resetZoom() {
        pixelsPerSecond = basePixelsPerSecond
    }

    public func applyZoomDelta(_ delta: CGFloat) {
        pixelsPerSecond = TimelineZoom.zoomWithDelta(current: pixelsPerSecond, delta: delta, basePPS: basePixelsPerSecond)
    }

    public func setZoomPixelsPerSecond(_ pps: CGFloat) {
        pixelsPerSecond = TimelineZoom.clamp(pps: pps, basePPS: basePixelsPerSecond)
    }

    public func updateViewportWidth(_ width: CGFloat) {
        guard width > 0, width != viewportWidth else { return }
        let wasAt100 = abs(pixelsPerSecond - basePixelsPerSecond) < 0.5
        viewportWidth = width
        if wasAt100 {
            pixelsPerSecond = basePixelsPerSecond
        }
    }
}
