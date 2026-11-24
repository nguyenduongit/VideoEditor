import Foundation
import CoreGraphics
import Domain

/// Shared geometric reveal clipping masks (`rect`, `centerSplitX/Y`, `diagonalSlash`, `irisCircle`)
/// used by both whole-block and per-unit text renderers.
public enum TextMaskClipHelper: Sendable {
    public static func applyMask(
        bounds: CGRect,
        clipRevealX: Double,
        clipRevealY: Double,
        mode: TextMaskShapeMode,
        in context: CGContext
    ) {
        let rx = CGFloat(max(0.0, min(1.0, clipRevealX)))
        let ry = CGFloat(max(0.0, min(1.0, clipRevealY)))
        guard rx < 0.999 || ry < 0.999 else { return }

        switch mode {
        case .rect:
            let w = bounds.width * rx
            let h = bounds.height * ry
            context.clip(to: CGRect(x: bounds.minX, y: bounds.minY, width: w, height: h))

        case .centerSplitX:
            let w = bounds.width * rx
            let h = bounds.height * ry
            let rect = CGRect(x: bounds.midX - w * 0.5, y: bounds.midY - h * 0.5, width: w, height: h)
            context.clip(to: rect)

        case .centerSplitY:
            let w = bounds.width * rx
            let h = bounds.height * ry
            let rect = CGRect(x: bounds.midX - w * 0.5, y: bounds.midY - h * 0.5, width: w, height: h)
            context.clip(to: rect)

        case .diagonalSlash:
            let p = min(rx, ry)
            let slant = bounds.height * 0.38
            let span = bounds.width + slant
            let rightEdge = (bounds.minX - slant * 0.5) + span * p
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.minX - slant, y: bounds.minY))
            path.addLine(to: CGPoint(x: rightEdge, y: bounds.minY))
            path.addLine(to: CGPoint(x: rightEdge + slant, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX - slant, y: bounds.maxY))
            path.closeSubpath()
            context.addPath(path)
            context.clip()

        case .irisCircle:
            let p = min(rx, ry)
            let maxR = hypot(bounds.width * 0.5, bounds.height * 0.5) * 1.05
            let r = max(0.5, maxR * p)
            let circleRect = CGRect(x: bounds.midX - r, y: bounds.midY - r, width: r * 2.0, height: r * 2.0)
            context.addEllipse(in: circleRect)
            context.clip()
        }
    }
}
