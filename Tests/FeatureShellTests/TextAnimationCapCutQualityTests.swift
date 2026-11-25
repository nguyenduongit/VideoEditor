import Testing
import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
@testable import Domain
@testable import FeatureShell

@Suite("TextAnimationCapCutQualityTests")
@MainActor
struct TextAnimationCapCutQualityTests {

    @Test("Unified script scope determines segmented vs whole-block rendering")
    func testKineticTypographyDetection() {
        let engine = TextRendererEngine()

        var cfgWave = TextConfiguration(content: "Wave Float Test")
        cfgWave.animation.scriptId = "title_wave_float"
        #expect(engine.shouldRenderSegmented(for: cfgWave) == true)

        var cfgDrop = TextConfiguration(content: "Drop Test")
        cfgDrop.animation.scriptId = "kinetic_drop_glow"
        #expect(engine.shouldRenderSegmented(for: cfgDrop) == true)

        var cfgTypewriter = TextConfiguration(content: "Typewriter Test")
        cfgTypewriter.animation.scriptId = "typewriter_cursor"
        #expect(engine.shouldRenderSegmented(for: cfgTypewriter) == true)

        var cfgFade = TextConfiguration(content: "Cinematic Fade Test")
        cfgFade.animation.scriptId = "fade_cinematic"
        #expect(engine.shouldRenderSegmented(for: cfgFade) == false)

        let cfgDefault = TextConfiguration(content: "Static Text")
        #expect(engine.shouldRenderSegmented(for: cfgDefault) == false)
    }

    @Test("Slide Right script evaluates continuous Intro -> Loop -> Outro motion")
    func testSlideUpSpringOvershootAndArc() {
        var cfg = TextConfiguration(content: "CapCut Motion")
        cfg.animation.scriptId = "slide_right_right"
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 2, speed: 1.0)

        let canvasSize = CGSize(width: 854, height: 480)

        let evalIntro = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.1, duration: 4.0, canvasSize: canvasSize)
        #expect(evalIntro.config.opacity <= 1.0)

        let evalMid = TextAnimationEvaluator.evaluate(config: cfg, localTime: 2.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalMid.config.opacity > 0.9)

        let evalOutro = TextAnimationEvaluator.evaluate(config: cfg, localTime: 3.9, duration: 4.0, canvasSize: canvasSize)
        #expect(evalOutro.config.opacity < 0.9)
    }

    @Test("Title Wave Float script produces sinusoidal oscillation in continuous loop phase")
    func testWaveLoopSinusoidalOscillation() {
        var cfg = TextConfiguration(content: "Dancing Wave")
        cfg.animation.scriptId = "title_wave_float"
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3, speed: 1.0)

        let canvasSize = CGSize(width: 854, height: 480)

        let evalPeak = TextAnimationEvaluator.evaluate(config: cfg, localTime: 1.25, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalPeak.config.positionY) > 0.1)

        let evalTrough = TextAnimationEvaluator.evaluate(config: cfg, localTime: 1.75, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalTrough.config.positionY) > 0.1)
    }

    @Test("TextRendererEngine renders valid CIImage for unified kinetic segmented script")
    func testSegmentedAnimatedImageRendering() {
        let engine = TextRendererEngine()
        var cfg = TextConfiguration(content: "Default text")
        cfg.animation.scriptId = "kinetic_drop_glow"
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 2, speed: 1.0)

        let canvasSize = CGSize(width: 854, height: 480)

        let ciImage = engine.renderAnimatedImage(for: cfg, localTime: 0.35, duration: 4.0, canvasSize: canvasSize)
        #expect(ciImage != nil)
        #expect(ciImage?.extent.width ?? 0 > 0)
        #expect(ciImage?.extent.height ?? 0 > 0)
    }

    @Test("All 34 curated pure-motion TextAnimationScripts maintain phase continuity at In-Loop and Loop-Out boundaries")
    func testAll19ActiveScriptsMaintainPhaseContinuityAtBoundaries() {
        let scripts = TextAnimationScriptRegistry.shared.scripts
        #expect(scripts.count == 34)
        let base = TextConfiguration(content: "Hello", fontSize: 60.0)
        let unitTotal = 4

        for script in scripts {
            for unitIndex in 0..<unitTotal {
                let introEnd = script.evaluatePhase(base: base, phase: .intro(progress: 1.0), unitIndex: unitIndex, unitTotal: unitTotal)
                let loopStart = script.evaluatePhase(base: base, phase: .loop(time: 0.0, cycleProgress: 0.0), unitIndex: unitIndex, unitTotal: unitTotal)
                assertPhaseMatches(introEnd, loopStart, label: "\(script.id) In->Loop u=\(unitIndex)")

                let loopEnd = script.evaluatePhase(base: base, phase: .loop(time: 3.0, cycleProgress: 1.0), unitIndex: unitIndex, unitTotal: unitTotal)
                let outroStart = script.evaluatePhase(base: base, phase: .outro(progress: 0.0), unitIndex: unitIndex, unitTotal: unitTotal)
                assertPhaseMatches(loopEnd, outroStart, label: "\(script.id) Loop->Out u=\(unitIndex)")
            }
        }
    }

    @Test("Removed glitch/color script IDs resolve to nil and legacy JSON safely falls back to none")
    func testLegacyGlitchAndColorScriptsRemovedSafely() throws {
        let removedIDs = [
            "glitch_rgb_pop", "glitch_crt_slice_tear", "glitch_signal_tear",
            "hologram_scan_beam", "vhs_tracking_drift", "quantum_teleport_flicker",
            "cyber_shutter_slice", "neon_color_shift", "neon_cyber_shift",
            "rainbow_flow", "fx_chromatic_vapor", "cyber_glitch_pop"
        ]
        for id in removedIDs {
            #expect(TextAnimationScriptRegistry.shared.script(for: id) == nil, "Removed script \(id) must not remain in registry")
        }

        let legacyGlitchJSON = """
        {
            "content": "Legacy Glitch",
            "glitchIntensity": 80.0,
            "animation": {
                "inType": "TVGlitch",
                "loopType": "Flicker",
                "rgbSplitIntensity": 12.0,
                "lightSweepIntensity": 0.9,
                "highlightColorHex": "#00FF00"
            }
        }
        """
        let decoded = try #require(TextConfiguration.decode(from: legacyGlitchJSON))
        #expect(decoded.content == "Legacy Glitch")
        #expect(decoded.animation.scriptId == "none")
        #expect(decoded.animation.isDefault == true)
    }

    @Test("Breakthrough Metal GPU shaders, path trim, scramble, and 3D carousel render visibly on plain white text")
    func testBreakthroughMetalAndVectorScriptsRenderCleanly() throws {
        let engine = TextRendererEngine()
        let canvas = CGSize(width: 480, height: 240)
        let staticCfg = TextConfiguration(content: "SPARK", fontSize: 56.0, textColorHex: "#FFFFFF", isBold: true)
        let staticBytes = renderRGBABytes(try #require(engine.renderAnimatedImage(for: staticCfg, localTime: 0.0, duration: 5.0, canvasSize: canvas)), size: canvas)

        let breakthroughIDs: [(String, Double)] = [
            ("typewriter_neon_draw", 0.45),
            ("typewriter_cipher_decode", 0.35),
            ("three_d_card_carousel", 0.35),
            ("fade_diagonal_slash", 0.42),
            ("slide_center_split", 0.42),
            ("pop_collision_slam", 0.36),
            ("fx_pixel_dissolve", 0.25),
            ("wave_liquid_ripple", 1.25)
        ]

        for (scriptId, sampleT) in breakthroughIDs {
            var cfg = staticCfg
            cfg.animation.scriptId = scriptId
            let img = try #require(engine.renderAnimatedImage(for: cfg, localTime: sampleT, duration: 5.0, canvasSize: canvas), "Nil render for \(scriptId)")
            #expect(img.extent.size == canvas)
            let bytes = renderRGBABytes(img, size: canvas)
            #expect(bytes != staticBytes, "\(scriptId) must produce visibly animated output on default white text")
        }
    }

    @Test("Follow Text Animation moves background with script, and multi-line Per Line + Gaussian Blur scripts render cleanly")
    func testAnimateWithTextBackgroundAndMultilinePerLineRendering() throws {
        let engine = TextRendererEngine()
        let canvas = CGSize(width: 640, height: 360)

        // 1. Background with animateWithText = true must change frame pixels over animation time
        var followCfg = TextConfiguration(content: "FollowBox", fontSize: 56.0)
        followCfg.textColorHex = "#00000000"
        followCfg.background = TextBackgroundStyle(
            isEnabled: true, sourceKind: .solid, solidColorHex: "#EF4444",
            paddingX: 20, paddingY: 12, animateWithText: true
        )
        followCfg.animation.scriptId = "beat_pulse_slam"
        let followT0 = try #require(engine.renderAnimatedImage(for: followCfg, localTime: 0.15, duration: 5.0, canvasSize: canvas))
        let followT1 = try #require(engine.renderAnimatedImage(for: followCfg, localTime: 1.50, duration: 5.0, canvasSize: canvas))
        #expect(renderRGBABytes(followT0, size: canvas) != renderRGBABytes(followT1, size: canvas))

        // 2. Multi-line content preserves newline and Per Line scope tokenizes distinct Y lines
        var multiCfg = TextConfiguration(content: "First Line\nSecond Line", fontSize: 48.0)
        multiCfg.animation.scriptId = "slide_up_up"
        multiCfg.animation.scopeOverride = .perLine
        multiCfg.animation.scriptIntensity = 1.4
        multiCfg.animation.isBeatSyncEnabled = true
        multiCfg.animation.beatBPM = 128.0
        #expect(multiCfg.content.contains("\n"))
        #expect(engine.shouldRenderSegmented(for: multiCfg) == true)

        let font = NSFont.systemFont(ofSize: 48.0)
        let (lineTokens, _) = TextSegmentRenderer.tokenize(
            content: multiCfg.content, scope: .perLine, font: font, spacing: 0.0, alignment: .center
        )
        #expect(lineTokens.count == 2)
        #expect(lineTokens[0].relativeY > lineTokens[1].relativeY)

        let multiImg = engine.renderAnimatedImage(for: multiCfg, localTime: 0.45, duration: 5.0, canvasSize: canvas)
        #expect(multiImg != nil)

        // 3. Optical blur & Karaoke scripts render non-empty animated frames
        for specialScriptId in ["blur_focus_dissolve", "karaoke_glow_flow"] {
            var spCfg = TextConfiguration(content: "Pro Upgrade", fontSize: 52.0)
            spCfg.animation.scriptId = specialScriptId
            let img = engine.renderAnimatedImage(for: spCfg, localTime: 0.4, duration: 5.0, canvasSize: canvas)
            #expect(img != nil, "Failed to render \(specialScriptId)")
        }
    }

    private func assertPhaseMatches(_ a: TextUnitDelta, _ b: TextUnitDelta, label: String) {
        #expect(abs(a.offsetX - b.offsetX) < 0.5, "\(label) offsetX")
        #expect(abs(a.offsetY - b.offsetY) < 0.5, "\(label) offsetY")
        #expect(abs(a.canvasOffsetXRatio - b.canvasOffsetXRatio) < 0.01, "\(label) canvasOffsetXRatio")
        #expect(abs(a.canvasOffsetYRatio - b.canvasOffsetYRatio) < 0.01, "\(label) canvasOffsetYRatio")
        #expect(abs(a.scaleX - b.scaleX) < 0.02, "\(label) scaleX")
        #expect(abs(a.scaleY - b.scaleY) < 0.02, "\(label) scaleY")
        #expect(abs(a.rotation - b.rotation) < 0.5, "\(label) rotation")
        #expect(abs(a.opacity - b.opacity) < 0.05, "\(label) opacity")
    }

    @Test("Fixed envelope background expands for animation/style and remains stationary across time")
    func testFixedEnvelopeBackgroundExpandsForAnimationAndStaysStatic() throws {
        let engine = TextRendererEngine()
        let base = TextConfiguration(content: "WaveBox", fontSize: 60.0)
        let staticEnv = engine.measureBackgroundEnvelopeBounds(for: base)

        var waveCfg = base
        waveCfg.animation.scriptId = "title_wave_float"
        waveCfg.background = TextBackgroundStyle(isEnabled: true, sourceKind: .solid, solidColorHex: "#FF0000", paddingX: 20, paddingY: 12)
        waveCfg.textColorHex = "#00000000"
        #expect(waveCfg.background.animateWithText == false)
        let waveEnv = engine.measureBackgroundEnvelopeBounds(for: waveCfg)
        #expect(waveEnv.height > staticEnv.height)

        var glowCfg = base
        glowCfg.glow = TextGlowStyle(isEnabled: true, colorHex: "#00FFAA", intensity: 90, range: 24)
        let glowEnv = engine.measureBackgroundEnvelopeBounds(for: glowCfg)
        #expect(glowEnv.width > staticEnv.width && glowEnv.height > staticEnv.height)

        let canvas = CGSize(width: 640, height: 360)
        let imgT0 = try #require(engine.renderAnimatedImage(for: waveCfg, localTime: 0.15, duration: 5.0, canvasSize: canvas))
        let imgT1 = try #require(engine.renderAnimatedImage(for: waveCfg, localTime: 1.45, duration: 5.0, canvasSize: canvas))
        #expect(renderRGBABytes(imgT0, size: canvas) == renderRGBABytes(imgT1, size: canvas))
    }

    @Test("Noise grain shader modifies rendered text pixels when noiseIntensity is enabled")
    func testNoiseGrainFilterModifiesImageWhenEnabled() throws {
        let engine = TextRendererEngine()
        let canvas = CGSize(width: 320, height: 180)
        let cfg = TextConfiguration(content: "Grain", fontSize: 64.0, textColorHex: "#808080")
        let baseImg = try #require(engine.renderAnimatedImage(for: cfg, localTime: 0.0, duration: 4.0, canvasSize: canvas))
        let noisyImg = TextShaderFilterEngine.applyFilters(
            to: baseImg, blurRadius: 0, pixelateScale: 0, noiseIntensity: 80.0
        )
        #expect(renderRGBABytes(baseImg, size: canvas) != renderRGBABytes(noisyImg, size: canvas))
    }

    @Test("Static glow halo decays smoothly outward without blocky ghost rings or non-monotonic spikes")
    func testGlowHaloDecaysSmoothlyWithoutBlockyGhostRings() throws {
        let canvas = CGSize(width: 1280, height: 720)
        let glyphRect = CGRect(x: 635, y: 310, width: 10, height: 100)
        let glyphImg = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
            .cropped(to: glyphRect)
            .composited(over: CIImage.clear.cropped(to: CGRect(origin: .zero, size: canvas)))
            .cropped(to: CGRect(origin: .zero, size: canvas))

        let glow = TextGlowStyle(isEnabled: true, colorHex: "#FFFFFF", intensity: 90.0, range: 16.0)
        let bloomed = TextShaderFilterEngine.applyFilters(
            to: glyphImg, blurRadius: 0, pixelateScale: 0, glow: glow
        )
        let bytes = renderRGBABytes(bloomed, size: canvas)
        let w = Int(canvas.width)
        let midY = 360

        // Sample alpha moving outward to the right of the 10px stroke (from x = 647 to x = 710)
        var prevAlpha = Double(bytes[(midY * w + 646) * 4 + 3]) / 255.0
        for x in 647...710 {
            let alpha = Double(bytes[(midY * w + x) * 4 + 3]) / 255.0
            #expect(alpha <= prevAlpha + 0.015, "Non-monotonic ghost box jump at x=\(x): prev=\(prevAlpha), curr=\(alpha)")
            prevAlpha = alpha
        }
        // Halo right outside the glyph edge (x = 649) must be smooth and visible
        let nearAlpha = Double(bytes[(midY * w + 649) * 4 + 3]) / 255.0
        #expect(nearAlpha > 0.05, "Expected visible smooth bloom near glyph edge, got \(nearAlpha)")
    }

    @Test("Fixed background envelope contains animated intro and loop tokens at 00:00:00:44")
    func testBackgroundEnvelopeContainsIntroAndLoopTokensAtPlayhead044() {
        let engine = TextRendererEngine()
        var cfg = TextConfiguration(content: "Title Glow", fontSize: 72.0)
        cfg.glow = TextGlowStyle(isEnabled: true, colorHex: "#FF8800", intensity: 85, range: 20)
        cfg.background = TextBackgroundStyle(
            isEnabled: true, sourceKind: .solid, solidColorHex: "#7ED321", paddingX: 20, paddingY: 14
        )
        let canvas = CGSize(width: 1920, height: 1080)
        let core = engine.measureCoreGlyphBounds(for: cfg)

        for scriptId in ["kinetic_drop_glow", "title_wave_float", "ripple_drop_wave"] {
            cfg.animation.scriptId = scriptId
            let envelope = engine.measureBackgroundEnvelopeBounds(for: cfg)
            let halfBoxH = envelope.height * 0.5 + CGFloat(cfg.background.paddingY)
            for charIdx in 0..<9 {
                let ev = TextAnimationEvaluator.evaluate(
                    config: cfg, localTime: 44.0 / 60.0, duration: 5.0,
                    canvasSize: canvas, charIndex: charIdx, charCount: 9
                )
                let reachY = abs(CGFloat(ev.config.positionY)) + core.height * CGFloat(ev.overlay.scaleY) * 0.5
                #expect(reachY <= halfBoxH, "Script \(scriptId) char \(charIdx) reachY=\(reachY) > halfBoxH=\(halfBoxH)")
            }
        }
    }

    private func renderRGBABytes(_ image: CIImage, size: CGSize) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        ctx.render(image, toBitmap: &bytes, rowBytes: w * 4, bounds: CGRect(origin: .zero, size: size), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
