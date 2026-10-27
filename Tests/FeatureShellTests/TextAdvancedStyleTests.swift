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
        config.content = "CLASSIC 3D"
        config.isGradient = true
        config.gradientColors = ["#FFFBEB", "#FDE047", "#D97706"]
        config.gradientAngle = 45.0
        config.hasExtrusion = true
        config.extrusionDepth = 12.0
        config.extrusionAngle = -60.0
        config.extrusionColorHex = "#581C87"
        config.hasOuterStroke = true
        config.outerStrokeColorHex = "#DC2626"
        config.outerStrokeWidth = 8.0
        config.isHollow = true

        guard let json = config.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Failed to serialize or deserialize TextConfiguration with advanced properties")
            return
        }

        #expect(decoded.isGradient == true)
        #expect(decoded.gradientColors == ["#FFFBEB", "#FDE047", "#D97706"])
        #expect(decoded.gradientAngle == 45.0)
        #expect(decoded.hasExtrusion == true)
        #expect(decoded.extrusionDepth == 12.0)
        #expect(decoded.extrusionAngle == -60.0)
        #expect(decoded.extrusionColorHex == "#581C87")
        #expect(decoded.hasOuterStroke == true)
        #expect(decoded.outerStrokeColorHex == "#DC2626")
        #expect(decoded.outerStrokeWidth == 8.0)
        #expect(decoded.isHollow == true)
    }

    @Test func testRenderImageWithExtrusionAndGradientProducesValidCIImage() {
        var config = TextConfiguration(content: "GOLD 3D", fontSize: 60.0)
        config.isGradient = true
        config.gradientColors = ["#FFFBEB", "#FDE047", "#D97706", "#78350F"]
        config.hasExtrusion = true
        config.extrusionDepth = 10.0
        config.extrusionColorHex = "#3B1E04"

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
        config.isHollow = true
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
        var remoteConfig = TextConfiguration(content: "ONLINE 3D", fontSize: 52.0)
        remoteConfig.isGradient = true
        remoteConfig.gradientColors = ["#FFFBEB", "#F59E0B"]
        remoteConfig.hasExtrusion = true
        remoteConfig.extrusionDepth = 8.0
        remoteConfig.extrusionColorHex = "#78350F"

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
