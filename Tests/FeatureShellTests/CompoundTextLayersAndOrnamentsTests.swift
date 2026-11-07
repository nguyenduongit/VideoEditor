import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("Unified Text Dual Stroke, Style & Background Compositing Tests")
@MainActor
struct CompoundTextLayersAndOrnamentsTests {

    @Test("Unified TextConfiguration Serialization & Roundtrip for Stroke, Style, Curved & Background")
    func testUnifiedTextConfigurationSerialization() throws {
        var config = TextConfiguration(
            content: "SPRING SALE",
            fontName: "Helvetica",
            fontSize: 54.0,
            textColorHex: "#FFFFFF",
            colorFillMode: .linearGradient,
            gradientColors: ["#FF2A85", "#FDE047"],
            gradientAngle: 60.0
        )

        config.innerStroke = TextStrokeStyle(
            isEnabled: true,
            width: 3.0,
            colorHex: "#FFD700",
            isGradient: true,
            gradientColors: ["#FFD700", "#FF2A85"],
            gradientAngle: 45.0
        )
        config.outerStroke = TextStrokeStyle(
            isEnabled: true,
            width: 6.0,
            colorHex: "#0F172A"
        )
        config.glow = TextGlowStyle(isEnabled: true, colorHex: "#38BDF8", intensity: 85.0, range: 18.0)
        config.shadow = TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 75.0, blur: 10.0, distance: 6.0, angleDegrees: -45.0)
        config.background = TextBackgroundStyle(
            isEnabled: true,
            sourceKind: .linearGradient,
            gradientColorsHex: ["#1E1B4B", "#312E81"],
            gradientAngleDegrees: 90.0,
            cornerRadius: 12.0,
            paddingX: 24.0,
            paddingY: 16.0,
            animateWithText: true
        )

        let json = try #require(config.encodeToJSON())
        let decoded = try #require(TextConfiguration.decode(from: json))

        #expect(decoded.content == "SPRING SALE")
        #expect(decoded.colorFillMode == .linearGradient)
        #expect(decoded.innerStroke.isGradient == true)
        #expect(decoded.outerStroke.isEnabled == true)
        #expect(decoded.outerStroke.width == 6.0)
        #expect(decoded.glow.intensity == 85.0)
        #expect(decoded.shadow.distance == 6.0)
        #expect(decoded.background.isEnabled == true)
        #expect(decoded.background.sourceKind == .linearGradient)
        #expect(decoded.background.paddingX == 24.0)
        #expect(decoded.background.animateWithText == true)
    }

    @Test("Legacy 3-Layer JSON Decodes Gracefully into New Single-Core TextConfiguration")
    func testLegacyJSONBackwardCompatibility() throws {
        let legacyJSON = """
        {
            "content": "Legacy Multi\\nLine",
            "fontName": "Helvetica",
            "fontSize": 48.0,
            "textColorHex": "#FFFFFF",
            "colorFillMode": "perWord",
            "hasStroke": true,
            "strokeColorHex": "#112233",
            "strokeWidth": 4.0,
            "hasBackground": true,
            "backgroundColorHex": "#FF0055",
            "backgroundPaddingX": 20.0,
            "isCurved": true,
            "curveAngle": 50.0
        }
        """

        let decoded = try #require(TextConfiguration.decode(from: legacyJSON))
        #expect(decoded.content == "Legacy Multi Line")
        #expect(decoded.colorFillMode == .solid)
        #expect(decoded.innerStroke.isEnabled == true)
        #expect(decoded.innerStroke.colorHex == "#112233")
        #expect(decoded.innerStroke.width == 4.0)
        #expect(decoded.background.isEnabled == true)
        #expect(decoded.background.solidColorHex == "#FF0055")
        #expect(decoded.background.paddingX == 20.0)
        #expect(decoded.curve.shape == .arc)
        #expect(decoded.curve.angleDegrees == 50.0)
    }

    @Test("TextRendererEngine Composites Inline SVG Background + Dual Stroke + Glow + Gradient Fill")
    func testTextRendererEngineBackgroundAndDualStrokeCompositing() {
        let engine = TextRendererEngine()
        var config = TextConfiguration(
            content: "TIẾNG VIỆT RỰC RỠ",
            fontName: "Helvetica",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            colorFillMode: .linearGradient,
            gradientColors: ["#EF4444", "#FDE047"]
        )
        config.innerStroke = TextStrokeStyle(isEnabled: true, width: 2.5, colorHex: "#FFFFFF")
        config.outerStroke = TextStrokeStyle(isEnabled: true, width: 5.0, colorHex: "#000000")
        config.background = TextBackgroundStyle(
            isEnabled: true,
            sourceKind: .inlineSVG,
            svgMarkup: "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 300 90\"><rect width=\"300\" height=\"90\" rx=\"20\" fill=\"#0F172A\"/></svg>",
            blendMode: .screen,
            paddingX: 20.0,
            paddingY: 12.0,
            animateWithText: false
        )

        let canvasSize = CGSize(width: 640, height: 360)
        let base = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: canvasSize))
        let out = engine.composite(config: config, over: base, localTime: 0.25, duration: 4.0, canvasSize: canvasSize)
        #expect(out.extent == CGRect(origin: .zero, size: canvasSize))

        for preset in TextPreset.creativeCatalog {
            let presetImg = engine.renderAnimatedImage(for: preset.config, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
            #expect(presetImg != nil, "Mẫu \(preset.id) phải kết xuất thành công")
        }
    }

    @Test("ClipCanvasGeometry computes accurate bounding box for Single-Line TextClip")
    func testTextClipBoundingBoxGeometry() throws {
        let config = TextConfiguration(
            content: "HEADLINE",
            fontName: "Helvetica",
            fontSize: 60.0,
            positionX: 25.0,
            positionY: -40.0,
            scale: 1.2,
            rotation: 10.0
        )
        let json = try #require(config.encodeToJSON())
        let clip = TimelineClip(
            name: "Headline Clip",
            kind: .text,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: [
                "textConfig": .string(json),
                "positionX": .number(25.0),
                "positionY": .number(-40.0),
                "scale": .number(1.2),
                "rotation": .number(10.0)
            ]
        )

        let geom = ClipCanvasGeometry.compute(for: clip, canvasSize: CGSize(width: 1920, height: 1080))
        #expect(geom.positionX == 25.0)
        #expect(geom.positionY == -40.0)
        #expect(geom.rotationDegrees == 10.0)
        #expect(geom.size.width > 60.0)
    }

    @Test("AI Agent Template In-Memory Registration")
    func testAgentTemplateInMemoryRegistration() {
        let agentPreset = TextPreset(
            id: "agent_badge_title",
            name: "Agent Badge Title",
            description: "Agent-authored unified text preset",
            category: .trending,
            config: TextConfiguration(
                content: "BREAKING",
                fontName: "Helvetica",
                fontSize: 64.0,
                textColorHex: "#FFF1F2",
                background: TextBackgroundStyle(isEnabled: true, sourceKind: .solid, solidColorHex: "#E11D48")
            )
        )

        let loader = TextTemplateLoader()
        loader.updateInMemoryPreset(agentPreset)

        let fetched = loader.loadAllTemplates().first { $0.id == "agent_badge_title" }
        #expect(fetched != nil)
        #expect(fetched?.config.background.isEnabled == true)
    }
}
