import Testing
import Foundation
import CoreGraphics
@testable import FeatureShell

@Suite("MaskOnScreenOverlayTests")
struct MaskOnScreenOverlayTests {
    @Test("MaskOnScreenMath computes uniform scale accurately")
    func testScaleComputation() {
        let canvas = CGSize(width: 1920, height: 1080)
        let view = CGSize(width: 960, height: 540)
        let s = MaskOnScreenMath.scale(canvasSize: canvas, viewSize: view)
        #expect(abs(s - 0.5) < 0.001)

        // Degenerate size handling
        let sZero = MaskOnScreenMath.scale(canvasSize: .zero, viewSize: view)
        #expect(sZero > 0.0)
    }

    @Test("Screen center and canvas position roundtrip preserves exact coordinates")
    func testScreenCenterAndCanvasPositionRoundtrip() {
        let canvas = CGSize(width: 1920, height: 1080)
        let view = CGSize(width: 640, height: 360)

        // Center origin (0, 0) must land on screen center
        let screenCenter = MaskOnScreenMath.screenCenter(positionX: 0, positionY: 0, canvasSize: canvas, viewSize: view)
        #expect(screenCenter.x == 320.0)
        #expect(screenCenter.y == 180.0)

        // Offset position
        let initialX = 145.0
        let initialY = -75.0
        let pt = MaskOnScreenMath.screenCenter(positionX: initialX, positionY: initialY, canvasSize: canvas, viewSize: view)
        let roundtrip = MaskOnScreenMath.canvasPosition(screenPoint: pt, canvasSize: canvas, viewSize: view)

        #expect(abs(roundtrip.x - initialX) < 0.001)
        #expect(abs(roundtrip.y - initialY) < 0.001)
    }

    @Test("Rotation angle calculation produces exact cardinal degrees")
    func testRotationAngleDegrees() {
        let center = CGPoint(x: 200, y: 200)

        // Point straight above center corresponds to 0° rotation
        let topPoint = CGPoint(x: 200, y: 100)
        let topAngle = MaskOnScreenMath.rotationAngleDegrees(from: center, to: topPoint)
        #expect(abs(topAngle) < 0.001)

        // Point straight to the right corresponds to 90° rotation
        let rightPoint = CGPoint(x: 300, y: 200)
        let rightAngle = MaskOnScreenMath.rotationAngleDegrees(from: center, to: rightPoint)
        #expect(abs(rightAngle - 90.0) < 0.001)

        // Point straight to the left corresponds to -90° rotation
        let leftPoint = CGPoint(x: 100, y: 200)
        let leftAngle = MaskOnScreenMath.rotationAngleDegrees(from: center, to: leftPoint)
        #expect(abs(leftAngle - (-90.0)) < 0.001)
    }

    @Test("Rotate point and unrotate point correctly cycles coordinates")
    func testRotateAndUnrotatePoint() {
        let center = CGPoint(x: 100, y: 100)
        let initialPoint = CGPoint(x: 150, y: 100) // 50px right of center

        // Rotate by 90° clockwise
        let rotated = MaskOnScreenMath.rotatePoint(initialPoint, around: center, angleDegrees: 90.0)
        #expect(abs(rotated.x - 100.0) < 0.001)
        #expect(abs(rotated.y - 150.0) < 0.001)

        // Unrotate back
        let restored = MaskOnScreenMath.unrotatePoint(rotated, around: center, angleDegrees: 90.0)
        #expect(abs(restored.x - initialPoint.x) < 0.001)
        #expect(abs(restored.y - initialPoint.y) < 0.001)
    }

    @Test("Clamp helper safely constrains values within bounds")
    func testClampHelper() {
        #expect(MaskOnScreenMath.clamp(50.0, min: 0.0, max: 100.0) == 50.0)
        #expect(MaskOnScreenMath.clamp(-10.0, min: 0.0, max: 100.0) == 0.0)
        #expect(MaskOnScreenMath.clamp(150.0, min: 0.0, max: 100.0) == 100.0)
    }

    @Test("Radius resize calculation tracks mouse position exactly in unrotated space")
    func testRadiusResizeCalculationTracking() {
        let center = CGPoint(x: 300, y: 300)
        let scale: CGFloat = 0.5
        let rotation: Double = 31.02

        // Simulate mouse positioned at local X distance = 128px (screen) from center
        let localScreenTarget = CGPoint(x: center.x + 128.0, y: center.y)
        let rotatedMouseLocation = MaskOnScreenMath.rotatePoint(localScreenTarget, around: center, angleDegrees: rotation)

        let unrotated = MaskOnScreenMath.unrotatePoint(rotatedMouseLocation, around: center, angleDegrees: rotation)
        let computedRadiusX = abs(unrotated.x - center.x) / scale
        #expect(abs(computedRadiusX - 256.0) < 0.001, "Computed radius on canvas must track mouse target 1:1 (128 / 0.5 = 256)")
    }
}
