import Foundation
import CoreGraphics
import CoreMedia
import Domain

/// Represents the geometric footprint and orientation of a visual clip in canvas coordinates.
/// Complies with R3.1, R4.3, and R7.5 of AGENTS.md.
public struct ClipCanvasGeometry: Sendable {
    public let center: CGPoint
    public let size: CGSize
    public let rotationDegrees: Double
    public let positionX: Double
    public let positionY: Double

    public init(
        center: CGPoint,
        size: CGSize,
        rotationDegrees: Double,
        positionX: Double,
        positionY: Double
    ) {
        self.center = center
        self.size = size
        self.rotationDegrees = rotationDegrees
        self.positionX = positionX
        self.positionY = positionY
    }

    /// Computes the canvas geometry for a given timeline clip against a target canvas render size.
    public static func compute(
        for clip: TimelineClip,
        canvasSize: CGSize
    ) -> ClipCanvasGeometry {
        let meta: VideoTrackMetadata
        if let url = clip.mediaURL, let cached = VideoMetadataCache.shared.metadata(for: url) {
            meta = cached
        } else {
            meta = VideoTrackMetadata(transform: .identity, naturalSize: canvasSize)
        }

        let oriented = meta.naturalSize.applying(meta.transform)
        let srcW = max(1.0, abs(oriented.width))
        let srcH = max(1.0, abs(oriented.height))

        let baseScale = min(canvasSize.width / srcW, canvasSize.height / srcH)
        let userScale = clip.properties["scale"]?.asNumber ?? 1.0
        let userPosX = clip.properties["positionX"]?.asNumber ?? 0.0
        let userPosY = clip.properties["positionY"]?.asNumber ?? 0.0
        let userRotation = clip.properties["rotation"]?.asNumber ?? 0.0

        let finalScale = max(0.01, baseScale * userScale)
        let clipW = srcW * finalScale
        let clipH = srcH * finalScale

        return ClipCanvasGeometry(
            center: CGPoint(x: userPosX, y: userPosY),
            size: CGSize(width: clipW, height: clipH),
            rotationDegrees: userRotation,
            positionX: userPosX,
            positionY: userPosY
        )
    }

    /// Converts a screen point to canvas-relative coordinates (X, Y) matching preview rendering.
    public static func canvasPoint(
        from screenPoint: CGPoint,
        canvasSize: CGSize,
        viewSize: CGSize
    ) -> (x: Double, y: Double) {
        let scale = max(0.001, viewSize.width / max(1.0, canvasSize.width))
        let x = Double((screenPoint.x - viewSize.width / 2.0) / scale)
        let y = Double((screenPoint.y - viewSize.height / 2.0) / scale)
        return (x, y)
    }

    /// Converts canvas center-relative position (X, Y) to on-screen CGPoint in viewport coordinates.
    public static func screenCenter(
        positionX: Double,
        positionY: Double,
        canvasSize: CGSize,
        viewSize: CGSize
    ) -> CGPoint {
        let scale = max(0.001, viewSize.width / max(1.0, canvasSize.width))
        return CGPoint(
            x: viewSize.width / 2.0 + CGFloat(positionX) * scale,
            y: viewSize.height / 2.0 + CGFloat(positionY) * scale
        )
    }

    /// Checks if a canvas-relative coordinate (x, y) falls inside the clip's rotated boundary.
    public func contains(canvasPoint: (x: Double, y: Double)) -> Bool {
        let dx = canvasPoint.x - positionX
        let dy = canvasPoint.y - positionY

        let lx: Double
        let ly: Double
        if abs(rotationDegrees) > 0.001 {
            let rad = rotationDegrees * .pi / 180.0
            lx = dx * cos(rad) + dy * sin(rad)
            ly = -dx * sin(rad) + dy * cos(rad)
        } else {
            lx = dx
            ly = dy
        }

        let halfW = Double(size.width) / 2.0
        let halfH = Double(size.height) / 2.0
        return abs(lx) <= halfW && abs(ly) <= halfH
    }
}

/// Hit-testing service traversing timeline layers according to Z-order visual stacking.
public struct PreviewHitTester: Sendable {
    /// Finds the top-most visual clip intersecting the provided screen point at currentTime.
    public static func findTopMostClip(
        layers: [TimelineLayer],
        currentTime: CMTime,
        canvasSize: CGSize,
        screenPoint: CGPoint,
        viewSize: CGSize
    ) -> TimelineClip? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let canvasPt = ClipCanvasGeometry.canvasPoint(
            from: screenPoint,
            canvasSize: canvasSize,
            viewSize: viewSize
        )

        for layer in layers {
            // Audio layers and hidden/locked layers are excluded from preview direct manipulation
            guard !layer.isHidden, !layer.isLocked, layer.kind != .audio else { continue }

            for clip in layer.clips {
                let start = clip.timeRange.start
                let end = clip.timeRange.end
                let isActive: Bool
                if clip.timeRange.duration == .zero {
                    isActive = false
                } else if currentTime == end {
                    isActive = true
                } else {
                    isActive = (currentTime >= start && currentTime < end)
                }
                guard isActive else { continue }

                let geom = ClipCanvasGeometry.compute(for: clip, canvasSize: canvasSize)
                if geom.contains(canvasPoint: canvasPt) {
                    return clip
                }
            }
        }
        return nil
    }
}
