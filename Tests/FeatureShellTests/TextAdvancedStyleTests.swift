import Foundation
import CoreMedia
import CoreGraphics
import CoreImage
import Testing
import Domain
@testable import FeatureShell

@Suite("TextAdvancedStyleTests")
struct TextAdvancedStyleTests {
    @Test func testTextConfigurationAdvancedPropertiesSerialization() {
        var config = TextConfiguration()
        config.content = "CLASSIC GRADIENT"
        config.isGradient = true
        config.gradientColors = ["#FFFBEB", "#FDE047"]
        config.gradientAngle = 45.0
        config.hasOuterStroke = true
        config.outerStrokeColorHex = "#DC2626"
        config.outerStrokeWidth = 8.0
        config.glow = TextGlowStyle(isEnabled: true, colorHex: "#F59E0B", intensity: 90.0, range: 16.0)
        config.shadow = TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 80.0, blur: 10.0, distance: 6.0, angleDegrees: -60.0)
        config.textColorHex = "NONE"

        guard let json = config.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Failed to serialize or deserialize TextConfiguration with advanced properties")
            return
        }

        #expect(decoded.isGradient == true)
        #expect(decoded.gradientColors == ["#FFFBEB", "#FDE047"])
        #expect(decoded.gradientAngle == 45.0)
        #expect(decoded.hasOuterStroke == true)
        #expect(decoded.outerStrokeColorHex == "#DC2626")
        #expect(decoded.outerStrokeWidth == 8.0)
        #expect(decoded.glow.isEnabled == true)
        #expect(decoded.glow.intensity == 90.0)
        #expect(decoded.shadow.distance == 6.0)
        #expect(decoded.textColorHex == "NONE")
    }

    @Test func testRenderImageWithGradientAndShadowProducesValidCIImage() {
        var config = TextConfiguration(content: "GOLD CINEMA", fontSize: 60.0)
        config.isGradient = true
        config.gradientColors = ["#FFFBEB", "#D97706"]
        config.shadow = TextShadowStyle(isEnabled: true, colorHex: "#3B1E04", opacity: 85.0, blur: 6.0, distance: 8.0, angleDegrees: -45.0)

        let canvasSize = CGSize(width: 1920, height: 1080)
        let image = TextRendererEngine().renderImage(for: config, canvasSize: canvasSize)
        #expect(image != nil)
        #expect((image?.extent.width ?? 0) > 0)
        #expect((image?.extent.height ?? 0) > 0)
    }

    @Test func testRenderImageWithOuterStrokeStickerEffect() {
        var config = TextConfiguration(content: "STICKER", fontSize: 50.0)
        config.hasStroke = true
        config.strokeColorHex = "#FFFFFF"
        config.strokeWidth = 3.0
        config.hasOuterStroke = true
        config.outerStrokeColorHex = "#DC2626"
        config.outerStrokeWidth = 6.0

        let canvasSize = CGSize(width: 1920, height: 1080)
        let measured = TextRendererEngine().measureSize(for: config, canvasSize: canvasSize)
        #expect(measured.width > 100.0)
        #expect(measured.height > 40.0)

        let image = TextRendererEngine().renderImage(for: config, canvasSize: canvasSize)
        #expect(image != nil)
    }

    @Test func testHollowNeonTextRendering() {
        var config = TextConfiguration(content: "DJ NIGHT", fontSize: 54.0)
        config.textColorHex = "NONE"
        config.hasStroke = true
        config.strokeColorHex = "#38BDF8"
        config.strokeWidth = 2.0
        config.hasGlow = true
        config.glowColorHex = "#0284C7"
        config.glowRadius = 14.0

        let canvasSize = CGSize(width: 1920, height: 1080)
        let image = TextRendererEngine().renderImage(for: config, canvasSize: canvasSize)
        #expect(image != nil)
    }

    @Test func testOnlinePresetsViaRemoteSyncAreDiscoverableAndValid() {
        var remoteConfig = TextConfiguration(content: "ONLINE GOLD", fontSize: 52.0)
        remoteConfig.isGradient = true
        remoteConfig.gradientColors = ["#FFFBEB", "#F59E0B"]
        remoteConfig.glow = TextGlowStyle(isEnabled: true, colorHex: "#F59E0B", intensity: 75.0, range: 12.0)

        let onlinePreset = TextPreset(
            id: "online_gold_master",
            name: "Gold Hoàng Gia Online",
            description: "Mẫu chữ trực tuyến từ Supabase",
            category: .trending,
            tags: ["gold", "online", "pro"],
            previewBadge: "PRO",
            config: remoteConfig,
            isSystem: false
        )

        guard let jsonString = onlinePreset.encodeToJSON() else {
            Issue.record("Failed to encode online preset to JSON")
            return
        }

        let loader = TextTemplateLoader()
        let presets = loader.mergeSupabaseTemplateScripts([jsonString])
        let found = presets.first { $0.id == "online_gold_master" }
        #expect(found != nil, "Preset loaded from Supabase online payload must be available in TextTemplateLoader")
        #expect(found?.name == "Gold Hoàng Gia Online")
        #expect(found?.config.isGradient == true)

        let canvasSize = CGSize(width: 1920, height: 1080)
        if let config = found?.config {
            let rendered = TextRendererEngine().renderImage(for: config, canvasSize: canvasSize)
            #expect(rendered != nil)
        }
    }
}
