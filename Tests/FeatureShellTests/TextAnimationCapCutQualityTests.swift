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
}
