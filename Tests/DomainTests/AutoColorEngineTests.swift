import Testing
import Foundation
@testable import Domain

@Suite("AutoColorEngine Tests")
struct AutoColorEngineTests {

    @Test("Dark frame telemetry increases exposure and lifts shadows/blacks")
    func testDarkFrameTelemetry() {
        let engine = AutoColorEngine()
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
        let engine = AutoColorEngine()
        let brightTelemetry = ColorTelemetryProfile(
            averageLuma: 0.85,
            blackPoint: 0.15,
            whitePoint: 0.99,
            dynamicRange: 0.84,
            shadowClippingRatio: 0.0,
            highlightClippingRatio: 0.15,
            averageSaturation: 0.35
        )

        let result = engine.computeAdjustment(from: brightTelemetry, style: .neutral)

        #expect(result.basic.exposure < 0.0)
        #expect(result.basic.highlight < 0.0)
        // High blackPoint (0.15) should pull black down to restore depth instead of lifting it
        #expect(result.basic.black < 0.0)
        #expect(result.basic.shadow == 0.0)
    }

    @Test("Balanced mid-tone frame telemetry keeps neutral parameters at zero without washing out blacks")
    func testBalancedFrameTelemetry() {
        let engine = AutoColorEngine()
        let balancedTelemetry = ColorTelemetryProfile(
            averageLuma: 0.50,
            blackPoint: 0.05,
            whitePoint: 0.90,
            dynamicRange: 0.85,
            shadowClippingRatio: 0.0,
            highlightClippingRatio: 0.0,
            suggestedTempOffset: 0.0,
            suggestedTintOffset: 0.0,
            averageSaturation: 0.28
        )

        let result = engine.computeAdjustment(from: balancedTelemetry, style: .neutral)

        #expect(result.basic.exposure == 0.0)
        #expect(result.basic.shadow == 0.0)
        #expect(result.basic.black == 0.0)
        #expect(result.basic.highlight == 0.0)
        #expect(result.basic.temp == 0.0)
        #expect(result.basic.tint == 0.0)
    }

    @Test("Symmetric white balance corrects both warm and cool casts without fixed warm bias")
    func testSymmetricWhiteBalanceCorrection() {
        let engine = AutoColorEngine()
        let coolTelemetry = ColorTelemetryProfile(
            suggestedTempOffset: 40.0,
            suggestedTintOffset: -30.0
        )
        let warmTelemetry = ColorTelemetryProfile(
            suggestedTempOffset: -40.0,
            suggestedTintOffset: 30.0
        )

        let coolResult = engine.computeAdjustment(from: coolTelemetry, style: .neutral)
        let warmResult = engine.computeAdjustment(from: warmTelemetry, style: .neutral)

        #expect(coolResult.basic.temp == 18.0)
        #expect(warmResult.basic.temp == -18.0)
        #expect(coolResult.basic.tint == -11.0)
        #expect(warmResult.basic.tint == 11.0)
    }

    @Test("Soft and Airy style adds gentle shadow/black lift and scales with intensity")
    func testSoftAndAiryStyleAndIntensity() {
        let engine = AutoColorEngine()
        let balancedTelemetry = ColorTelemetryProfile(
            averageLuma: 0.50,
            blackPoint: 0.05,
            whitePoint: 0.90,
            dynamicRange: 0.85
        )

        let fullAiry = engine.computeAdjustment(from: balancedTelemetry, style: .softAndAiry, intensity: 1.0)
        let halfAiry = engine.computeAdjustment(from: balancedTelemetry, style: .softAndAiry, intensity: 0.5)

        #expect(fullAiry.basic.exposure == 3.0)
        #expect(fullAiry.basic.shadow == 18.0)
        #expect(fullAiry.basic.black == 10.0)
        #expect(halfAiry.basic.shadow == 9.0)
        #expect(halfAiry.basic.black == 5.0)
    }
}
