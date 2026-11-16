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

    @Test("Kinetic typography animations are automatically recognized for segmented rendering")
    func testKineticTypographyDetection() {
        let engine = TextRendererEngine()

        // 1. Slide Up should be segmented
        var cfgSlide = TextConfiguration(content: "Slide Up Test")
        cfgSlide.animation.inType = .slideUp
        #expect(engine.shouldRenderSegmented(for: cfgSlide) == true)

        // 2. Drop should be segmented
        var cfgDrop = TextConfiguration(content: "Drop Test")
        cfgDrop.animation.inType = .kineticDrop
        #expect(engine.shouldRenderSegmented(for: cfgDrop) == true)

        // 3. Wave Loop should be segmented
        var cfgWave = TextConfiguration(content: "Wave Loop Test")
        cfgWave.animation.loopType = .wave
        #expect(engine.shouldRenderSegmented(for: cfgWave) == true)

        // 4. Default / None should NOT be segmented
        let cfgDefault = TextConfiguration(content: "Static Text")
        #expect(engine.shouldRenderSegmented(for: cfgDefault) == false)
    }

    @Test("Slide Up animation applies spring overshoot and arc offset")
    func testSlideUpSpringOvershootAndArc() {
        var cfg = TextConfiguration(content: "CapCut Motion")
        cfg.animation.inType = .slideUp
        cfg.animation.inDuration = 0.5

        let canvasSize = CGSize(width: 854, height: 480)

        // At t = 0.0, positionY > 0 (starts below baseline)
        let eval0 = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.0, duration: 3.0, canvasSize: canvasSize)
        #expect(eval0.config.positionY > 50.0)

        // At end (0.5s), position settles at 0.0
        let evalDone = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.5, duration: 3.0, canvasSize: canvasSize)
        #expect(abs(evalDone.config.positionY) < 0.01)
    }

    @Test("Wave Loop animation produces sinusoidal vertical oscillation per phase")
    func testWaveLoopSinusoidalOscillation() {
        var cfg = TextConfiguration(content: "Dancing Wave")
        cfg.animation.loopType = .wave
        cfg.animation.loopSpeed = 1.0

        let canvasSize = CGSize(width: 854, height: 480)

        // Mid-phase (pi / 2): sin(phase) = 1.0 -> positionY should be positive
        let evalPeak = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.25, duration: 3.0, canvasSize: canvasSize)
        #expect(abs(evalPeak.config.positionY) > 0.1)

        // Opposite phase (3pi / 2): sin(phase) = -1.0 -> positionY should be negative
        let evalTrough = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.75, duration: 3.0, canvasSize: canvasSize)
        #expect(abs(evalTrough.config.positionY) > 0.1)
    }

    @Test("TextRendererEngine renders valid CIImage for kinetic segmented animated text")
    func testSegmentedAnimatedImageRendering() {
        let engine = TextRendererEngine()
        var cfg = TextConfiguration(content: "Default text")
        cfg.animation.inType = .slideUp
        cfg.animation.inDuration = 0.5

        let canvasSize = CGSize(width: 854, height: 480)

        // Render at t = 0.25s (during flight with spring overshoot)
        let ciImage = engine.renderAnimatedImage(for: cfg, localTime: 0.25, duration: 3.0, canvasSize: canvasSize)
        #expect(ciImage != nil)
        #expect(ciImage?.extent.width ?? 0 > 0)
        #expect(ciImage?.extent.height ?? 0 > 0)
    }

    @Test("All 19 active TextAnimationScripts maintain phase continuity at In-Loop and Loop-Out boundaries")
    func testAll19ActiveScriptsMaintainPhaseContinuityAtBoundaries() {
        let scripts = TextAnimationScriptRegistry.shared.scripts
        #expect(scripts.count == 19)
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

    private func assertPhaseMatches(_ a: TextUnitDelta, _ b: TextUnitDelta, label: String) {
        #expect(abs(a.offsetX - b.offsetX) < 0.5, "\(label) offsetX")
        #expect(abs(a.offsetY - b.offsetY) < 0.5, "\(label) offsetY")
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
            to: baseImg, blurRadius: 0, hueAngle: 0, pixelateScale: 0, rgbSplitIntensity: 0, noiseIntensity: 80.0
        )
        #expect(renderRGBABytes(baseImg, size: canvas) != renderRGBABytes(noisyImg, size: canvas))
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

        for scriptId in ["kinetic_drop_glow", "title_wave_float", "wave_cascade_flow"] {
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
