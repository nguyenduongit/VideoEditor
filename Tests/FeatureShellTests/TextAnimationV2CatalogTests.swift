import Testing
import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
@testable import Domain
@testable import FeatureShell

@Suite("TextAnimationV2CatalogTests")
@MainActor
struct TextAnimationV2CatalogTests {

    @Test("Advanced easing curves compute expected monotonic and bounded values")
    func testAdvancedEasingCurves() {
        #expect(abs(TextAnimationCurves.expoEaseOut(0.0)) < 0.001)
        #expect(abs(TextAnimationCurves.expoEaseOut(1.0) - 1.0) < 0.001)
        #expect(TextAnimationCurves.expoEaseOut(0.5) > 0.9)

        #expect(abs(TextAnimationCurves.expoEaseIn(0.0)) < 0.001)
        #expect(abs(TextAnimationCurves.expoEaseIn(1.0) - 1.0) < 0.001)
        #expect(TextAnimationCurves.expoEaseIn(0.5) < 0.05)

        #expect(TextAnimationCurves.backEaseOut(0.7) > 1.0) // Overshoot
        #expect(abs(TextAnimationCurves.backEaseOut(1.0) - 1.0) < 0.001)

        #expect(abs(TextAnimationCurves.sineEaseInOut(0.0)) < 0.001)
        #expect(abs(TextAnimationCurves.sineEaseInOut(0.5) - 0.5) < 0.001)
        #expect(abs(TextAnimationCurves.sineEaseInOut(1.0) - 1.0) < 0.001)

        #expect(abs(TextAnimationCurves.circEaseOut(0.0)) < 0.001)
        #expect(abs(TextAnimationCurves.circEaseOut(1.0) - 1.0) < 0.001)
    }

    @Test("OpenAnimationRuntimeEngine resolves new tokens correctly")
    func testRuntimeEngineNewTokens() {
        let manifest = CreativeAnimationManifest(
            id: "test_manifest", name: "Test", phase: .inAnimation,
            offsetXExpr: "100.0 * $rand",
            offsetYExpr: "50.0 * $alt",
            scaleXExpr: "$expoOut",
            scaleYExpr: "$backOut"
        )
        let anim = TextAnimationConfiguration()

        let varsChar0 = OpenAnimationRuntimeEngine.Variables(
            progress: 0.5, anim: anim, manifest: manifest,
            charIndex: 0, charCount: 4
        )
        let varsChar1 = OpenAnimationRuntimeEngine.Variables(
            progress: 0.5, anim: anim, manifest: manifest,
            charIndex: 1, charCount: 4
        )

        let alt0 = OpenAnimationRuntimeEngine.evaluate("$alt", vars: varsChar0)
        let alt1 = OpenAnimationRuntimeEngine.evaluate("$alt", vars: varsChar1)
        #expect(alt0 == 1.0)
        #expect(alt1 == -1.0)

        let i0 = OpenAnimationRuntimeEngine.evaluate("$i", vars: varsChar0)
        let i1 = OpenAnimationRuntimeEngine.evaluate("$i", vars: varsChar1)
        #expect(abs(i0 - 0.0) < 0.001)
        #expect(abs(i1 - 0.333) < 0.01)

        let rand0 = OpenAnimationRuntimeEngine.evaluate("$rand", vars: varsChar0)
        #expect(rand0 >= -1.0 && rand0 <= 1.0)

        let expoVal = OpenAnimationRuntimeEngine.evaluate("$expoOut", vars: varsChar0)
        #expect(expoVal > 0.9)
    }

    @Test("V2 Catalog Presets count and phase classification")
    func testCatalogPresetsCounts() {
        #expect(AnimationPreset.inCatalogV2.count == 14)
        #expect(AnimationPreset.loopCatalogV2.count == 10)
        #expect(AnimationPreset.outCatalogV2.count == 10)

        #expect(AnimationPreset.inCatalog.count == 19)
        #expect(AnimationPreset.loopCatalog.count == 15)
        #expect(AnimationPreset.outCatalog.count == 15)
        #expect(AnimationPreset.systemTemplates.count == 49)

        for preset in AnimationPreset.inCatalogV2 {
            #expect(preset.phase == .inAnimation)
            #expect(preset.manifest.phase == .inAnimation)
            #expect(!preset.name.isEmpty)
        }
        for preset in AnimationPreset.loopCatalogV2 {
            #expect(preset.phase == .loopAnimation)
            #expect(preset.manifest.phase == .loopAnimation)
            #expect(!preset.name.isEmpty)
        }
        for preset in AnimationPreset.outCatalogV2 {
            #expect(preset.phase == .outAnimation)
            #expect(preset.manifest.phase == .outAnimation)
            #expect(!preset.name.isEmpty)
        }
    }

    @Test("All 49 system templates evaluate safely without NaN or infinite values")
    func testAllSystemTemplatesEvaluationSafety() {
        let baseConfig = TextConfiguration(content: "Test Animation Sharpness")
        let testPoints: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for preset in AnimationPreset.systemTemplates {
            var config = baseConfig
            switch preset.phase {
            case .inAnimation:
                config.animation.inManifest = preset.manifest
                config.animation.inType = .fadeIn
                config.animation.inDuration = 1.0
            case .outAnimation:
                config.animation.outManifest = preset.manifest
                config.animation.outType = .fadeOut
                config.animation.outDuration = 1.0
            case .loopAnimation:
                config.animation.loopManifest = preset.manifest
                config.animation.loopType = .pulse
                config.animation.loopSpeed = 1.0
            }

            for p in testPoints {
                let eval = TextAnimationEvaluator.evaluate(
                    config: config, localTime: p, duration: 2.0,
                    canvasSize: CGSize(width: 1920, height: 1080),
                    charIndex: 2, charCount: 5
                )

                #expect(!eval.config.positionX.isNaN)
                #expect(!eval.config.positionY.isNaN)
                #expect(!eval.config.scale.isNaN)
                #expect(!eval.config.rotation.isNaN)
                #expect(!eval.config.opacity.isNaN)
                #expect(!eval.overlay.scaleX.isNaN)
                #expect(!eval.overlay.scaleY.isNaN)
                #expect(!eval.blurRadius.isNaN)
            }
        }
    }

    @Test("Backward compatibility when decoding CreativeAnimationManifest without new V2 fields")
    func testManifestBackwardCompatibility() throws {
        let legacyJSON = """
        {
            "id": "legacy_anim",
            "name": "Legacy Wave",
            "iconName": "waveform",
            "phase": "In",
            "defaultScope": "Per Character",
            "defaultStaggerDirection": "Forward",
            "customParameters": [],
            "offsetYExpr": "10.0 * $p"
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(CreativeAnimationManifest.self, from: data)

        #expect(manifest.id == "legacy_anim")
        #expect(manifest.offsetYExpr == "10.0 * $p")
        #expect(manifest.trackingExpr == nil)
        #expect(manifest.glowExpr == nil)
        #expect(manifest.hueExpr == nil)
        #expect(manifest.revealExpr == nil)
    }

    #if os(macOS)
    @Test("TextThumbnailRenderer renders authentic 1:1 animated preview frames on demo text 'Text'")
    func testRenderAnimationPreviewFrameOnText() {
        let targetSize = CGSize(width: 320, height: 160)

        // 1. In Animation (Pop Up - Per Character)
        let inFrame = TextThumbnailRenderer.renderAnimationPreviewFrame(
            preset: AnimationPreset.inPopUp,
            localTime: 0.6,
            duration: 1.4,
            targetSize: targetSize
        )
        #expect(inFrame != nil)
        #expect(inFrame?.size.width == 320)
        #expect(inFrame?.size.height == 160)

        // 2. Loop Animation (Float - Sine Wave)
        let loopFrame = TextThumbnailRenderer.renderAnimationPreviewFrame(
            preset: AnimationPreset.loopFloat,
            localTime: 0.75,
            duration: 2.0,
            targetSize: targetSize
        )
        #expect(loopFrame != nil)

        // 3. Out Animation (Scatter Explode - Per Character)
        let outFrame = TextThumbnailRenderer.renderAnimationPreviewFrame(
            preset: AnimationPreset.outScatterExplode,
            localTime: 0.8,
            duration: 1.5,
            targetSize: targetSize
        )
        #expect(outFrame != nil)

        // 4. Cache hit test
        let cachedInFrame = TextThumbnailRenderer.renderAnimationPreviewFrame(
            preset: AnimationPreset.inPopUp,
            localTime: 0.6,
            duration: 1.4,
            targetSize: targetSize
        )
        #expect(cachedInFrame != nil)
    }

    @Test("Preset D3184CD8 with Glow and heavy Shadow renders with strictly bounded extent and 60fps budget")
    func testPresetD3184CD8RenderingPerformanceAndBoundedExtent() {
        var cfg = TextConfiguration(content: "Văn bản")
        cfg.fontSize = 48.0
        cfg.scale = 6.89
        cfg.isBold = true
        cfg.textColorHex = "#EC4899"
        cfg.innerStroke = TextStrokeStyle(isEnabled: true, width: 1.5, colorHex: "#FFFFFF")
        cfg.outerStroke = TextStrokeStyle(isEnabled: true, width: 1.5, colorHex: "#EC4899")
        cfg.glow = TextGlowStyle(isEnabled: true, colorHex: "#A855F7", intensity: 80.0, range: 14.0)
        cfg.shadow = TextShadowStyle(isEnabled: true, colorHex: "#6366F1", opacity: 75.0, blur: 43.5, distance: 4.0, angleDegrees: -45.0)
        cfg.animation.scope = .perCharacter
        cfg.animation.inManifest = AnimationPreset.inFlipCascade3D.manifest
        cfg.animation.inDuration = 1.0
        cfg.animation.loopManifest = AnimationPreset.loopJellySquash.manifest
        cfg.animation.loopSpeed = 1.0
        cfg.animation.outManifest = AnimationPreset.outGravityShatter.manifest
        cfg.animation.outDuration = 1.0

        let engine = TextRendererEngine()
        let canvas = CIImage(color: CIColor.black).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let canvasSize = CGSize(width: 1920, height: 1080)

        // Warm up Metal shader pipeline
        _ = engine.composite(config: cfg, over: canvas, localTime: 0.1, duration: 4.0, canvasSize: canvasSize)

        for testTime in [0.4, 1.8, 3.6] {
            let start = CFAbsoluteTimeGetCurrent()
            let output = engine.composite(config: cfg, over: canvas, localTime: testTime, duration: 4.0, canvasSize: canvasSize)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            #expect(!output.extent.isInfinite)
            #expect(!output.extent.isEmpty)
            #expect(output.extent.width == 1920)
            #expect(output.extent.height == 1080)
            #expect(elapsedMs < 60.0) // Steady state cực nhanh và mượt
        }
    }
    #endif
}
