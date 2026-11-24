import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
#if os(macOS)
import AppKit
#endif
@testable import Domain
@testable import FeatureShell

@Suite("TextAnimationEngineTests")
@MainActor
struct TextAnimationEngineTests {
    @Test("TextAnimationConfiguration defaults to unified script 'none' and isDefault returns true")
    func testTextAnimationConfigurationDefaults() {
        let config = TextAnimationConfiguration()
        #expect(config.scriptId == "none")
        #expect(config.hasScriptAnimation == false)
        #expect(config.scriptDuration == 5.0)
        #expect(config.scriptInDuration == 1.0)
        #expect(config.scriptLoopDuration == 3.0)
        #expect(config.scriptOutDuration == 1.0)
        #expect(config.scriptSpeed == 1.0)
        #expect(config.isTypewriterCursorVisible == true)
        #expect(config.motionEasing == .smooth)
        #expect(config.isDefault == true)
    }

    @Test("TextConfiguration decodes legacy JSON cleanly without animation keys")
    func testTextConfigurationBackwardCompatibility() {
        let legacyJSON = """
        {
            "content": "Tiêu đề cũ",
            "fontSize": 40.0,
            "textColorHex": "#FFFFFF",
            "fontName": "Helvetica"
        }
        """
        guard let decoded = TextConfiguration.decode(from: legacyJSON) else {
            Issue.record("Failed to decode legacy JSON")
            return
        }
        #expect(decoded.content == "Tiêu đề cũ")
        #expect(decoded.fontSize == 40.0)
        #expect(decoded.animation.isDefault == true)
        #expect(decoded.hasGlow == false)
        #expect(decoded.isBold == false)
        #expect(decoded.isItalic == false)
    }

    @Test("Typewriter unified script progresses per character with trailing cursor and smooth exit")
    func testTypewriterAnimationProgression() {
        var config = TextConfiguration(content: "Hello")
        config.animation.scriptId = "typewriter_cursor"
        config.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3, speed: 1.0)

        let canvasSize = CGSize(width: 1920, height: 1080)

        let evalFirstStart = TextAnimationEvaluator.evaluate(
            config: config, localTime: 0.05, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 5
        )
        #expect(evalFirstStart.overlay.trailingCursorOpacity > 0.5)

        let evalLastEarly = TextAnimationEvaluator.evaluate(
            config: config, localTime: 0.05, duration: 5.0, canvasSize: canvasSize, charIndex: 4, charCount: 5
        )
        #expect(evalLastEarly.config.opacity == 0.0)

        let evalLoopMid = TextAnimationEvaluator.evaluate(
            config: config, localTime: 2.0, duration: 5.0, canvasSize: canvasSize, charIndex: 4, charCount: 5
        )
        #expect(evalLoopMid.config.opacity == 1.0)
    }

    @Test("Fade and Slide unified scripts interpolate opacity and position across phases")
    func testFadeInAndSlideUpEvaluation() {
        var configFade = TextConfiguration(content: "Test Fade")
        configFade.animation.scriptId = "fade_soft_glow"
        configFade.animation.applyUnifiedScriptTiming(baseLoopSeconds: 2, speed: 1.0)

        let canvasSize = CGSize(width: 1000, height: 1000)
        let evalFade0 = TextAnimationEvaluator.evaluate(config: configFade, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalFade0.config.opacity == 0.0)

        let evalFadeMid = TextAnimationEvaluator.evaluate(config: configFade, localTime: 2.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalFadeMid.config.opacity > 0.9)

        var configSlide = TextConfiguration(content: "Test Slide")
        configSlide.animation.scriptId = "smooth_word_glide"
        configSlide.animation.applyUnifiedScriptTiming(baseLoopSeconds: 2, speed: 1.0)

        let evalSlide0 = TextAnimationEvaluator.evaluate(config: configSlide, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalSlide0.config.positionY) > 0.0 || evalSlide0.config.opacity < 1.0)

        let evalSlideDone = TextAnimationEvaluator.evaluate(config: configSlide, localTime: 2.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalSlideDone.config.opacity > 0.95)
    }

    @Test("Unified kinetic scripts evaluate intro transforms cleanly")
    func testProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgDrop = TextConfiguration(content: "Drop")
        cfgDrop.animation.scriptId = "kinetic_drop_glow"
        let evalDrop = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 0.15, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 4)
        #expect(abs(evalDrop.config.positionY) > 1.0 || evalDrop.config.opacity < 1.0)

        var cfgWhip = TextConfiguration(content: "Whip")
        cfgWhip.animation.scriptId = "whip_echo_slam"
        let evalWhip = TextAnimationEvaluator.evaluate(config: cfgWhip, localTime: 0.1, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 4)
        #expect(abs(evalWhip.config.positionX) > 1.0 || evalWhip.overlay.echoCount > 0)
    }

    @Test("Unified scripts evaluate outro transitions smoothly back to exit")
    func testProOutAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)
        let dur = 5.0

        var cfgDrop = TextConfiguration(content: "Drop Down")
        cfgDrop.animation.scriptId = "kinetic_drop_glow"
        let evalDropEnd = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 5.0, duration: dur, canvasSize: canvasSize, charIndex: 0, charCount: 8)
        #expect(evalDropEnd.config.opacity <= 0.05)

        var cfgWhip = TextConfiguration(content: "Whip Out")
        cfgWhip.animation.scriptId = "whip_echo_slam"
        let evalWhipEnd = TextAnimationEvaluator.evaluate(config: cfgWhip, localTime: 5.0, duration: dur, canvasSize: canvasSize, charIndex: 0, charCount: 8)
        #expect(evalWhipEnd.config.opacity <= 0.05)
    }

    @Test("Unified wave & liquid pulse scripts animate continuously during loop window")
    func testProLoopAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgWave = TextConfiguration(content: "Wave")
        cfgWave.animation.scriptId = "title_wave_float"
        let evalWave = TextAnimationEvaluator.evaluate(config: cfgWave, localTime: 1.25, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 4)
        #expect(abs(evalWave.config.positionY) > 0.1 || abs(evalWave.config.rotation) > 0.1)

        var cfgPulse = TextConfiguration(content: "Pulse")
        cfgPulse.animation.scriptId = "liquid_wave_pulse"
        let evalPulse = TextAnimationEvaluator.evaluate(config: cfgPulse, localTime: 1.35, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 5)
        #expect(evalPulse.overlay.scaleX != 1.0 || evalPulse.config.positionY != 0.0)
    }

    @Test("Motion Easing curves produce bounded ease values")
    func testMotionEasingCurves() {
        #expect(TextAnimationCurves.apply(progress: 0.0, easing: .smooth) == 0.0)
        #expect(TextAnimationCurves.apply(progress: 1.0, easing: .smooth) == 1.0)
        #expect(TextAnimationCurves.apply(progress: 0.0, easing: .bounce) == 0.0)
        #expect(TextAnimationCurves.apply(progress: 1.0, easing: .bounce) == 1.0)
        #expect(TextAnimationCurves.apply(progress: 0.0, easing: .elastic) == 0.0)
        #expect(TextAnimationCurves.apply(progress: 1.0, easing: .elastic) == 1.0)
    }

    @Test("TextRendererEngine renders valid animated CIImage with glow and unified script")
    func testTextRendererEngineRendering() {
        var config = TextConfiguration(content: "AWESOME MOTION")
        config.isBold = true
        config.hasGlow = true
        config.glowColorHex = "#00FFFF"
        config.glowRadius = 12.0
        config.animation.scriptId = "fade_soft_glow"

        let canvasSize = CGSize(width: 600, height: 400)
        let image = TextRendererEngine().renderAnimatedImage(
            for: config,
            localTime: 0.6,
            duration: 5.0,
            canvasSize: canvasSize
        )
        #expect(image != nil)
        if let image {
            #expect(image.extent.width > 0)
            #expect(image.extent.height > 0)
        }
    }

    @Test("Verify actual pixels of background and glow in rendered image")
    func testVerifyBackgroundAndGlowPixels() {
        var config = TextConfiguration(content: "TEST")
        config.textColorHex = "#FFFFFF"
        config.hasBackground = true
        config.backgroundColorHex = "#FF0000FF"
        config.backgroundPadding = 30.0

        let renderer = TextRendererEngine()
        let canvasSize = CGSize(width: 400, height: 200)

        guard let ciImg = renderer.renderAnimatedImage(for: config, localTime: 1.0, duration: 5.0, canvasSize: canvasSize),
              let ciAnim = {
                  var animCfg = config
                  animCfg.animation.scriptId = "smooth_word_glide"
                  return renderer.renderAnimatedImage(for: animCfg, localTime: 1.2, duration: 5.0, canvasSize: canvasSize)
              }() else {
            Issue.record("Failed to render background images")
            return
        }
        #expect(containsDominantRed(in: ciImg, canvasSize: canvasSize, threshold: 0.8), "Static text must render background")
        #expect(containsDominantRed(in: ciAnim, canvasSize: canvasSize, threshold: 0.8), "Animated text must render background")

        var glowConfig = TextConfiguration(content: "GLOW")
        glowConfig.textColorHex = "#000000"
        glowConfig.hasGlow = true
        glowConfig.glowColorHex = "#FF0000"
        glowConfig.glowRadius = 15.0

        guard let ciGlowStatic = renderer.renderAnimatedImage(for: glowConfig, localTime: 1.0, duration: 5.0, canvasSize: canvasSize),
              let ciGlowAnim = {
                  var animGlow = glowConfig
                  animGlow.animation.scriptId = "smooth_word_glide"
                  return renderer.renderAnimatedImage(for: animGlow, localTime: 1.2, duration: 5.0, canvasSize: canvasSize)
              }() else {
            Issue.record("Failed to render glow images")
            return
        }
        #expect(containsDominantRed(in: ciGlowStatic, canvasSize: canvasSize, threshold: 0.4), "Static text must render glow")
        #expect(containsDominantRed(in: ciGlowAnim, canvasSize: canvasSize, threshold: 0.4), "Animated text must render glow")
    }

    private func containsDominantRed(in ciImage: CIImage, canvasSize: CGSize, threshold: CGFloat) -> Bool {
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImg = NSImage(size: canvasSize)
        nsImg.addRepresentation(rep)
        guard let tiff = nsImg.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return false }
        for x in stride(from: 50, to: 350, by: 5) {
            for y in stride(from: 50, to: 150, by: 5) {
                if let color = bitmap.colorAt(x: x, y: y),
                   color.redComponent > threshold && color.greenComponent < 0.2 && color.blueComponent < 0.2 {
                    return true
                }
            }
        }
        return false
    }
}


