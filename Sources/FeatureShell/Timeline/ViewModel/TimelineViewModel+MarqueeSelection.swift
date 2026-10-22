import Foundation
import CoreGraphics
import CoreMedia
import Domain

extension TimelineViewModel {
    public func clipsIntersecting(rect: CGRect, topSpacerHeight: CGFloat) -> Set<UUID> {
        let standardized = rect.standardized
        let activeRect = CGRect(
            x: standardized.origin.x,
            y: standardized.origin.y,
            width: max(1.0, standardized.width),
            height: max(1.0, standardized.height)
        )

        var result = Set<UUID>()
        var currentY = topSpacerHeight

        for layer in layers {
            let lh = layerHeight(for: layer.kind)
            let layerRect = CGRect(x: 0, y: currentY, width: CGFloat.greatestFiniteMagnitude, height: lh)
            if activeRect.intersects(layerRect) {
                for clip in layer.clips {
                    let clipX = CGFloat(CMTimeGetSeconds(clip.timeRange.start)) * pixelsPerSecond
                    let clipW = max(28.0, CGFloat(CMTimeGetSeconds(clip.timeRange.duration)) * pixelsPerSecond)
                    let clipRect = CGRect(x: clipX, y: currentY, width: clipW, height: lh)
                    if activeRect.intersects(clipRect) {
                        result.insert(clip.id)
                    }
                }
            }
            currentY += lh
        }
        return result
    }

    public func updateMarqueeSelection(rect: CGRect, topSpacerHeight: CGFloat) {
        selectedClipIDs = clipsIntersecting(rect: rect, topSpacerHeight: topSpacerHeight)
    }
}
