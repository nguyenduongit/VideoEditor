import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("TextAnimationEngineTests")
@MainActor
struct TextAnimationEngineTests {
    @Test("TextAnimationConfiguration defaults to none and isDefault returns true")
    func testTextAnimationConfigurationDefaults() {
        let config = TextAnimationConfiguration()
        #expect(config.inType == .none)
        #expect(config.outType == .none)
        #expect(config.loopType == .none)
        #expect(config.inDuration == 0.5)
        #expect(config.outDuration == 0.5)
        #expect(config.loopSpeed == 1.0)
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
        #expect(decoded.isUnderline == false)
        #expect(decoded.isStrikethrough == false)
        #expect(decoded.isAllCaps == false)
    }

    @Test("Typewriter animation generates substring progression with optional cursor")
    func testTypewriterAnimationProgression() {
        var config = TextConfiguration(content: "Hello World")
        config.animation.inType = .typewriter1
        config.animation.inDuration = 1.0
        config.animation.isTypewriterCursorVisible = true

        let canvasSize = CGSize(width: 1920, height: 1080)

        let eval0 = TextAnimationEvaluator.evaluate(config: config, localTime: 0.0, duration: 5.0, canvasSize: canvasSize)
        #expect(eval0.config.content == "|")

        let evalHalf = TextAnimationEvaluator.evaluate(config: config, localTime: 0.5, duration: 5.0, canvasSize: canvasSize)
        #expect(evalHalf.config.content.hasPrefix("Hello"))
        #expect(evalHalf.config.content.hasSuffix("|"))

        let evalFull = TextAnimationEvaluator.evaluate(config: config, localTime: 1.0, duration: 5.0, canvasSize: canvasSize)
        #expect(evalFull.config.content == "Hello World")
    }

    @Test("FadeIn and SlideUp animations interpolate opacity and position correctly")
    func testFadeInAndSlideUpEvaluation() {
        var configFade = TextConfiguration(content: "Test Fade")
        configFade.animation.inType = .fadeIn
        configFade.animation.inDuration = 1.0

        let canvasSize = CGSize(width: 1000, height: 1000)
        let evalFade0 = TextAnimationEvaluator.evaluate(config: configFade, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalFade0.config.opacity == 0.0)

        let evalFadeHalf = TextAnimationEvaluator.evaluate(config: configFade, localTime: 0.5, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalFadeHalf.config.opacity - 0.5) < 0.001)

        var configSlide = TextConfiguration(content: "Test Slide")
        configSlide.animation.inType = .slideUp
        configSlide.animation.inDuration = 1.0

        let evalSlide0 = TextAnimationEvaluator.evaluate(config: configSlide, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalSlide0.config.positionY > 0.0)

        let evalSlideDone = TextAnimationEvaluator.evaluate(config: configSlide, localTime: 1.0, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalSlideDone.config.positionY - 0.0) < 0.001)
    }

    @Test("Pro In Animations evaluate transforms: SlideDown, SpinIn, LightStreak")
    func testProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgFly = TextConfiguration(content: "Fly In")
        cfgFly.animation.inType = .slideDown
        cfgFly.animation.inDuration = 1.0
        let evalFly0 = TextAnimationEvaluator.evaluate(config: cfgFly, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalFly0.config.positionY < -100.0)

        var cfgVortex = TextConfiguration(content: "Vortex")
        cfgVortex.animation.inType = .spinIn
        cfgVortex.animation.inDuration = 1.0
        let evalVortex0 = TextAnimationEvaluator.evaluate(config: cfgVortex, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalVortex0.config.rotation >= 350.0)
        #expect(evalVortex0.config.scale <= 0.05)

        var cfgGlitch = TextConfiguration(content: "Glitch")
        cfgGlitch.animation.inType = .glitch
        cfgGlitch.animation.inDuration = 1.0
        let evalGlitch0 = TextAnimationEvaluator.evaluate(config: cfgGlitch, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalGlitch0.rgbSplitIntensity > 0.0)
        #expect(evalGlitch0.overlay.glitchSliceIntensity > 0.0)
    }

    @Test("Pro Out Animations evaluate exit transitions: SpinOut, Dissolve")
    func testProOutAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)
        let dur = 4.0

        var cfgPixel = TextConfiguration(content: "Pixel")
        cfgPixel.animation.outType = .dissolve
        cfgPixel.animation.outDuration = 1.0
        let evalPixelEnd = TextAnimationEvaluator.evaluate(config: cfgPixel, localTime: 4.0, duration: dur, canvasSize: canvasSize)
        #expect(evalPixelEnd.pixelateScale >= 25.0)
        #expect(evalPixelEnd.config.opacity == 0.0)

        var cfgSpiral = TextConfiguration(content: "Spiral")
        cfgSpiral.animation.outType = .spinOut
        cfgSpiral.animation.outDuration = 1.0
        let evalSpiralEnd = TextAnimationEvaluator.evaluate(config: cfgSpiral, localTime: 4.0, duration: dur, canvasSize: canvasSize)
        #expect(evalSpiralEnd.config.rotation >= 350.0)
        #expect(evalSpiralEnd.config.scale <= 0.05)
    }

    @Test("Pro Loop Animations evaluate heart and wobble effects")
    func testProLoopAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgQuake = TextConfiguration(content: "Quake")
        cfgQuake.animation.loopType = .wobble
        cfgQuake.animation.loopSpeed = 1.0
        let evalQuake = TextAnimationEvaluator.evaluate(config: cfgQuake, localTime: 0.35, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalQuake.config.rotation) > 0.001 || abs(evalQuake.config.positionX) > 0.001)

        var cfgHeart = TextConfiguration(content: "Heart")
        cfgHeart.animation.loopType = .pulse
        let evalHeart = TextAnimationEvaluator.evaluate(config: cfgHeart, localTime: 0.25, duration: 5.0, canvasSize: canvasSize)
        #expect(evalHeart.config.scale > 1.0)
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

    @Test("TextRendererEngine renders valid animated CIImage with pixelation and glow")
    func testTextRendererEngineRendering() {
        var config = TextConfiguration(content: "Awesome Motion")
        config.isAllCaps = true
        config.isUnderline = true
        config.hasGlow = true
        config.glowColorHex = "#00FFFF"
        config.glowRadius = 12.0
        config.animation.outType = .dissolve
        config.animation.outDuration = 1.0

        let canvasSize = CGSize(width: 600, height: 400)
        let image = TextRendererEngine().renderAnimatedImage(
            for: config,
            localTime: 2.8,
            duration: 3.0,
            canvasSize: canvasSize
        )
        #expect(image != nil)
        if let image {
            #expect(image.extent.width > 0)
            #expect(image.extent.height > 0)
        }
    }
}
