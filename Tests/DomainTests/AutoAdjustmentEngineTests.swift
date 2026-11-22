import Testing
import Foundation
@testable import Domain

@Suite("AutoAdjustmentEngine Tests")
struct AutoAdjustmentEngineTests {

    @Test("Dark frame telemetry increases exposure and lifts shadows/blacks")
    func testDarkFrameTelemetry() {
        let engine = AutoAdjustmentEngine()
        let darkTelemetry = ColorTelemetryProfile(
            averageLuma: 0.20,
            blackPoint: 0.01,
            whitePoint: 0.70,
            dynamicRange: 0.69,
            shadowClippingRatio: 0.12,
            highlightClippingRatio: 0.0,
            averageSaturation: 0.14
        )

        let result = engine.computeAdjustment(from: darkTelemetry, style: .neutral)

        #expect(result.basic.exposure >= 10.0)
        #expect(result.basic.shadow >= 20.0)
        #expect(result.basic.black >= 10.0)
        #expect(result.basic.white > 0.0)
        #expect(result.basic.saturation > 0.0)
        #expect(result.basic.brilliance > 0.0)
    }

    @Test("Overexposed frame telemetry reduces exposure and pulls down highlights")
    func testOverexposedFrameTelemetry() {
        let engine = AutoAdjustmentEngine()
        let brightTelemetry = ColorTelemetryProfile(
            averageLuma: 0.85,
            blackPoint: 0.35,
            whitePoint: 0.99,
            dynamicRange: 0.64,
            shadowClippingRatio: 0.0,
            highlightClippingRatio: 0.15,
            averageSaturation: 0.35
        )

        let result = engine.computeAdjustment(from: brightTelemetry, style: .neutral)

        #expect(result.basic.exposure < 0.0)
        #expect(result.basic.highlight < 0.0)
        // High blackPoint (0.35 > 0.28) pulls black down to restore depth instead of lifting it
        #expect(result.basic.black < 0.0)
        #expect(result.basic.shadow <= 0.0)
    }

    @Test("Already converged Clean Airy Daylight frame telemetry stays near zero adjustment")
    func testAlreadyConvergedCleanAiryFrameTelemetry() {
        let engine = AutoAdjustmentEngine()
        let convergedTelemetry = ColorTelemetryProfile(
            averageLuma: 0.61,
            blackPoint: 0.28,
            whitePoint: 0.96,
            dynamicRange: 0.68,
            shadowClippingRatio: 0.0,
            highlightClippingRatio: 0.0,
            meanRed: 0.60,
            meanGreen: 0.60,
            meanBlue: 0.56,
            suggestedTempOffset: 0.0,
            suggestedTintOffset: 0.0,
            averageSaturation: 0.24
        )

        let result = engine.computeAdjustment(from: convergedTelemetry, style: .neutral)

        #expect(abs(result.basic.exposure) <= 2.0)
        #expect(abs(result.basic.shadow) <= 3.0)
        #expect(abs(result.basic.black) <= 2.0)
        #expect(abs(result.basic.temp) <= 2.0)
    }

    @Test("Symmetric white balance corrects both warm and cool casts proportionally")
    func testSymmetricWhiteBalanceCorrection() {
        let engine = AutoAdjustmentEngine()
        let coolTelemetry = ColorTelemetryProfile(
            meanRed: 0.48, meanGreen: 0.55, meanBlue: 0.58,
            suggestedTempOffset: 40.0,
            suggestedTintOffset: -30.0
        )
        let warmTelemetry = ColorTelemetryProfile(
            meanRed: 0.60, meanGreen: 0.55, meanBlue: 0.48,
            suggestedTempOffset: -40.0,
            suggestedTintOffset: 30.0
        )

        let coolResult = engine.computeAdjustment(from: coolTelemetry, style: .neutral)
        let warmResult = engine.computeAdjustment(from: warmTelemetry, style: .neutral)

        #expect(coolResult.basic.temp >= 20.0)
        #expect(warmResult.basic.temp <= -20.0)
        #expect(coolResult.basic.tint <= -10.0)
        #expect(warmResult.basic.tint >= 10.0)
    }

    @Test("Soft and Airy style adds extra shadow/black lift and scales proportionally with intensity")
    func testSoftAndAiryStyleAndIntensity() {
        let engine = AutoAdjustmentEngine()
        let baseTelemetry = ColorTelemetryProfile(
            averageLuma: 0.50,
            blackPoint: 0.15,
            whitePoint: 0.90,
            dynamicRange: 0.75
        )

        let neutral = engine.computeAdjustment(from: baseTelemetry, style: .neutral, intensity: 1.0)
        let fullAiry = engine.computeAdjustment(from: baseTelemetry, style: .softAndAiry, intensity: 1.0)
        let halfAiry = engine.computeAdjustment(from: baseTelemetry, style: .softAndAiry, intensity: 0.5)

        #expect(fullAiry.basic.exposure > neutral.basic.exposure)
        #expect(fullAiry.basic.shadow > neutral.basic.shadow)
        #expect(fullAiry.basic.black > neutral.basic.black)
        #expect(halfAiry.basic.shadow == (fullAiry.basic.shadow * 0.5).rounded())
        #expect(halfAiry.basic.black == (fullAiry.basic.black * 0.5).rounded())
    }
}
