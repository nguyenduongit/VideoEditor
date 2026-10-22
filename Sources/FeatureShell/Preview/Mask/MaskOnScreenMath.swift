import Foundation
import CoreGraphics

/// Mathematical transformations between canvas render space and on-screen preview viewport.
/// Complies with R3.1 of AGENTS.md.
public struct MaskOnScreenMath: Sendable {
    /// Computes the uniform scaling factor from canvas render resolution to screen viewport size.
    public static func scale(canvasSize: CGSize, viewSize: CGSize) -> CGFloat {
        max(0.001, viewSize.width / max(1.0, canvasSize.width))
    }

    /// Converts canvas center-relative position (X, Y) to on-screen CGPoint in viewport coordinates.
    public static func screenCenter(
        positionX: Double,
        positionY: Double,
        canvasSize: CGSize,
        viewSize: CGSize
    ) -> CGPoint {
        let s = scale(canvasSize: canvasSize, viewSize: viewSize)
        return CGPoint(
            x: viewSize.width / 2.0 + CGFloat(positionX) * s,
            y: viewSize.height / 2.0 - CGFloat(positionY) * s
        )
    }

    /// Converts an on-screen CGPoint back into canvas center-relative coordinates (X, Y).
    public static func canvasPosition(
        screenPoint: CGPoint,
        canvasSize: CGSize,
        viewSize: CGSize
    ) -> (x: Double, y: Double) {
        let s = scale(canvasSize: canvasSize, viewSize: viewSize)
        let x = Double((screenPoint.x - viewSize.width / 2.0) / s)
        let y = Double(-(screenPoint.y - viewSize.height / 2.0) / s)
        return (x, y)
    }

    /// Calculates the rotation angle in degrees from center point towards the dragged handle position.
    public static func rotationAngleDegrees(from center: CGPoint, to currentPoint: CGPoint) -> Double {
        let dx = currentPoint.x - center.x
        let dy = currentPoint.y - center.y
        let radians = atan2(dy, dx) + .pi / 2.0
        var deg = Double(radians * 180.0 / .pi)
        while deg > 180.0 { deg -= 360.0 }
        while deg < -180.0 { deg += 360.0 }
        return deg
    }

    /// Rotates a point around a pivot point by given angle in degrees.
    public static func rotatePoint(_ point: CGPoint, around center: CGPoint, angleDegrees: Double) -> CGPoint {
        let rad = CGFloat(angleDegrees * .pi / 180.0)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = cos(rad)
        let sinA = sin(rad)
        return CGPoint(
            x: center.x + dx * cosA - dy * sinA,
            y: center.y + dx * sinA + dy * cosA
        )
    }

    /// Un-rotates a point around a pivot point back to unrotated orientation.
    public static func unrotatePoint(_ point: CGPoint, around center: CGPoint, angleDegrees: Double) -> CGPoint {
        rotatePoint(point, around: center, angleDegrees: -angleDegrees)
    }

    /// Helper to clamp a double value within inclusive bounds.
    public static func clamp(_ val: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.min(maxVal, Swift.max(minVal, val))
    }
}
