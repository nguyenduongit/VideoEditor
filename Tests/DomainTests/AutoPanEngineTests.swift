import Testing
import Foundation
@testable import Domain

@Suite("AutoPanEngineTests")
struct AutoPanEngineTests {
    @Test("maxPanOffset returns 0 when video fits within or is smaller than canvas width")
    func testMaxPanOffsetWhenVideoFitsCanvas() {
        // Video displayed width 1080 on canvas 1080 -> 0 overflow
        let maxPan = AutoPanEngine.maxPanOffset(videoWidth: 1080, scale: 1.0, canvasWidth: 1080)
        #expect(maxPan == 0.0)

        // Video displayed width 800 on canvas 1080 -> 0 overflow
        let maxPanSmaller = AutoPanEngine.maxPanOffset(videoWidth: 800, scale: 1.0, canvasWidth: 1080)
        #expect(maxPanSmaller == 0.0)
    }

    @Test("maxPanOffset calculates exact symmetrical overflow when video is wider than canvas")
    func testMaxPanOffsetWhenVideoWiderThanCanvas() {
        // 1920 width video on 1080 width canvas (e.g. 16:9 in 9:16)
        // Overflow = 1920 - 1080 = 840. Symmetrical each side = 420.
        let maxPan = AutoPanEngine.maxPanOffset(videoWidth: 1920, scale: 1.0, canvasWidth: 1080)
        #expect(abs(maxPan - 420.0) < 0.001)

        // Scaled up 1.5x on 1000 width canvas: 1000 * 1.5 = 1500. (1500 - 1000) / 2 = 250.
        let maxPanScaled = AutoPanEngine.maxPanOffset(videoWidth: 1000, scale: 1.5, canvasWidth: 1000)
        #expect(abs(maxPanScaled - 250.0) < 0.001)
    }

    @Test("clampPanOffset strictly clamps within max safe bounds preventing black bars")
    func testClampPanOffset() {
        let videoW = 1920.0
        let canvasW = 1080.0
        // maxPan is 420.0
        #expect(abs(AutoPanEngine.clampPanOffset(100.0, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW) - 100.0) < 0.001)
        #expect(abs(AutoPanEngine.clampPanOffset(-250.0, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW) - (-250.0)) < 0.001)

        // Beyond boundary: must clamp to exactly 420.0 and -420.0
        #expect(abs(AutoPanEngine.clampPanOffset(600.0, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW) - 420.0) < 0.001)
        #expect(abs(AutoPanEngine.clampPanOffset(-800.0, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW) - (-420.0)) < 0.001)
    }

    @Test("computePanOffset centers subject along the vertical center axis")
    func testComputePanOffsetCentering() {
        let videoW = 1920.0
        let canvasW = 1080.0

        // Subject in center (0.5) -> pan offset is 0.0
        let centerPan = AutoPanEngine.computePanOffset(subjectNormalizedX: 0.5, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW)
        #expect(abs(centerPan) < 0.001)

        // Subject at 0.3 (left of video): raw pan = -(0.3 - 0.5) * 1920 = +384.0 (shift right)
        let leftPan = AutoPanEngine.computePanOffset(subjectNormalizedX: 0.3, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW)
        #expect(abs(leftPan - 384.0) < 0.001)

        // Subject at 0.7 (right of video): raw pan = -(0.7 - 0.5) * 1920 = -384.0 (shift left)
        let rightPan = AutoPanEngine.computePanOffset(subjectNormalizedX: 0.7, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW)
        #expect(abs(rightPan - (-384.0)) < 0.001)

        // Subject at extreme edge (0.05): raw pan = +864.0 -> clamped to 420.0 (no black bar)
        let extremeLeftPan = AutoPanEngine.computePanOffset(subjectNormalizedX: 0.05, videoWidth: videoW, scale: 1.0, canvasWidth: canvasW)
        #expect(abs(extremeLeftPan - 420.0) < 0.001)
    }

    @Test("interpolatedNormalizedX smoothly blends between keyframes across time")
    func testInterpolatedNormalizedX() {
        let keyframes = [
            AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.2),
            AutoPanKeyframe(timeSeconds: 2.0, normalizedX: 0.8)
        ]

        // At t=0 -> 0.2, at t=2 -> 0.8
        #expect(abs(AutoPanEngine.interpolatedNormalizedX(at: 0.0, keyframes: keyframes) - 0.2) < 0.001)
        #expect(abs(AutoPanEngine.interpolatedNormalizedX(at: 2.0, keyframes: keyframes) - 0.8) < 0.001)

        // At t=1.0 (midpoint) -> should be 0.5
        let mid = AutoPanEngine.interpolatedNormalizedX(at: 1.0, keyframes: keyframes)
        #expect(abs(mid - 0.5) < 0.001)

        // Before start and after end
        #expect(abs(AutoPanEngine.interpolatedNormalizedX(at: -1.0, keyframes: keyframes) - 0.2) < 0.001)
        #expect(abs(AutoPanEngine.interpolatedNormalizedX(at: 5.0, keyframes: keyframes) - 0.8) < 0.001)
    }

    @Test("catmullRom interpolation yields smooth curve with continuous velocity")
    func testCatmullRomSpline() {
        // Points: p0=0.2, p1=0.4, p2=0.6, p3=0.8
        let v0 = AutoPanEngine.catmullRom(p0: 0.2, p1: 0.4, p2: 0.6, p3: 0.8, t: 0.0)
        #expect(abs(v0 - 0.4) < 0.001)

        let v1 = AutoPanEngine.catmullRom(p0: 0.2, p1: 0.4, p2: 0.6, p3: 0.8, t: 1.0)
        #expect(abs(v1 - 0.6) < 0.001)

        let vMid = AutoPanEngine.catmullRom(p0: 0.2, p1: 0.4, p2: 0.6, p3: 0.8, t: 0.5)
        #expect(abs(vMid - 0.5) < 0.001)
    }

    @Test("smoothKeyframesGaussian dampens alternating jitter noise across passes")
    func testGaussianSmoothing() {
        // High frequency jitter: 0.3, 0.7, 0.3, 0.7
        let noisy = [
            AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.3),
            AutoPanKeyframe(timeSeconds: 1.0, normalizedX: 0.7),
            AutoPanKeyframe(timeSeconds: 2.0, normalizedX: 0.3),
            AutoPanKeyframe(timeSeconds: 3.0, normalizedX: 0.7)
        ]

        let smoothed = AutoPanEngine.smoothKeyframesGaussian(noisy, passes: 2)
        #expect(smoothed.count == 4)

        // After 2 passes of Gaussian 1-2-1 filter, internal values are significantly dampened towards 0.5
        #expect(smoothed[1].normalizedX < 0.65)
        #expect(smoothed[2].normalizedX > 0.35)
    }

    @Test("AutoPanConfiguration JSON serialization and deserialization roundtrip")
    func testConfigurationSerialization() {
        let keyframes = [
            AutoPanKeyframe(timeSeconds: 0.5, normalizedX: 0.42, confidence: 0.95),
            AutoPanKeyframe(timeSeconds: 1.5, normalizedX: 0.65, confidence: 0.88)
        ]
        let original = AutoPanConfiguration(isEnabled: true, zoom: 1.35, smoothness: 0.75, keyframes: keyframes)

        guard let encoded = original.encodeToString() else {
            Issue.record("Failed to encode AutoPanConfiguration")
            return
        }
        guard let decoded = AutoPanConfiguration.decode(from: encoded) else {
            Issue.record("Failed to decode AutoPanConfiguration")
            return
        }

        #expect(decoded.isEnabled == true)
        #expect(abs(decoded.zoom - 1.35) < 0.001)
        #expect(abs(decoded.smoothness - 0.75) < 0.001)
        #expect(decoded.keyframes.count == 2)
        #expect(abs(decoded.keyframes[0].timeSeconds - 0.5) < 0.001)
        #expect(abs(decoded.keyframes[0].normalizedX - 0.42) < 0.001)

        // Backward compatibility: JSON without zoom property defaults to 1.0
        let legacyJSON = "{\"isEnabled\":true,\"smoothness\":0.5,\"keyframes\":[]}"
        let legacyDecoded = AutoPanConfiguration.decode(from: legacyJSON)
        #expect(legacyDecoded != nil)
        #expect(abs((legacyDecoded?.zoom ?? 0.0) - 1.0) < 0.001)
    }
}
