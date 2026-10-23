import Testing
import Foundation
@testable import Domain

@Suite("AdjustmentConfigurationTests")
struct AdjustmentConfigurationTests {
    @Test("Default AdjustmentConfiguration is neutral")
    func testDefaultConfigIsNeutral() {
        let config = AdjustmentConfiguration()
        #expect(config.isNeutral)
        #expect(config.basic.isNeutral)
        #expect(config.hsl.isNeutral)
    }

    @Test("JSON serialization and deserialization roundtrip")
    func testJSONRoundtrip() throws {
        var hsl = HSLAdjustments()
        hsl.orange = HSLChannel(hue: -12.0, saturation: 25.0, luminance: 10.0)
        hsl.blue = HSLChannel(hue: 5.0, saturation: -30.0, luminance: -5.0)

        let original = AdjustmentConfiguration(
            basic: BasicGradingParameters(
                temp: 20.0,
                tint: -5.0,
                saturation: 15.0,
                exposure: 5.0,
                contrast: 10.0,
                highlight: -15.0,
                shadow: 20.0,
                white: 8.0,
                black: -6.0,
                brilliance: 12.0
            ),
            hsl: hsl
        )

        #expect(!original.isNeutral)

        guard let json = original.encodeToJSON() else {
            Issue.record("Failed to encode to JSON")
            return
        }

        guard let decoded = AdjustmentConfiguration.decode(from: json) else {
            Issue.record("Failed to decode from JSON")
            return
        }

        #expect(decoded == original)
        #expect(decoded.basic.temp == 20.0)
        #expect(decoded.basic.shadow == 20.0)
        #expect(decoded.hsl.orange.saturation == 25.0)
        #expect(decoded.hsl.blue.saturation == -30.0)
    }

    @Test("HSL subscript indexing correctly accesses all 8 channels")
    func testHSLSubscript() {
        var hsl = HSLAdjustments()
        hsl[0] = HSLChannel(hue: 10, saturation: 20, luminance: 30) // red
        hsl[1] = HSLChannel(hue: 11, saturation: 21, luminance: 31) // orange
        hsl[2] = HSLChannel(hue: 12, saturation: 22, luminance: 32) // yellow
        hsl[3] = HSLChannel(hue: 13, saturation: 23, luminance: 33) // green
        hsl[4] = HSLChannel(hue: 14, saturation: 24, luminance: 34) // cyan
        hsl[5] = HSLChannel(hue: 15, saturation: 25, luminance: 35) // blue
        hsl[6] = HSLChannel(hue: 16, saturation: 26, luminance: 36) // purple
        hsl[7] = HSLChannel(hue: 17, saturation: 27, luminance: 37) // magenta

        #expect(hsl.red.hue == 10)
        #expect(hsl.orange.hue == 11)
        #expect(hsl.yellow.hue == 12)
        #expect(hsl.green.hue == 13)
        #expect(hsl.cyan.hue == 14)
        #expect(hsl.blue.hue == 15)
        #expect(hsl.purple.hue == 16)
        #expect(hsl.magenta.hue == 17)

        #expect(hsl[0].hue == 10)
        #expect(hsl[7].hue == 17)
    }

    @Test("AdjustmentPreset contains Default and built-in templates")
    func testPresetTemplates() {
        #expect(AdjustmentPreset.default.config.isNeutral)
        #expect(AdjustmentPreset.templates.count == 8)

        let names = AdjustmentPreset.templates.map(\.name)
        #expect(names.contains("Điện ảnh"))
        #expect(names.contains("Hoàng hôn"))
        #expect(names.contains("Băng giá"))
        #expect(names.contains("Hàn Quốc"))
        #expect(names.contains("Cổ điển"))
        #expect(names.contains("Cyberpunk"))
        #expect(names.contains("Rực rỡ"))
        #expect(names.contains("Đen trắng"))
    }
}
