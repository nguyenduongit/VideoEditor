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
    @Test("TextAnimationConfiguration defaults to none and isDefault returns true")
    func testTextAnimationConfigurationDefaults() {
        let config = TextAnimationConfiguration()
        #expect(config.inType == .none)
        #expect(config.outType == .none)
        #expect(config.loopType == .none)
        #expect(config.inDuration == 1.0)
        #expect(config.outDuration == 1.0)
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
        config.animation.inType = .typewriter
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

    @Test("Pro In Animations evaluate transforms: SlideUp, WhipRight, KineticDrop")
    func testProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgSlide = TextConfiguration(content: "Slide Up")
        cfgSlide.animation.inType = .slideUp
        cfgSlide.animation.inDuration = 1.0
        let evalSlide0 = TextAnimationEvaluator.evaluate(config: cfgSlide, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalSlide0.config.positionY > 50.0)

        var cfgWhip = TextConfiguration(content: "Whip")
        cfgWhip.animation.inType = .whipRight
        cfgWhip.animation.inDuration = 1.0
        let evalWhip0 = TextAnimationEvaluator.evaluate(config: cfgWhip, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalWhip0.config.positionX < -50.0)

        var cfgDrop = TextConfiguration(content: "Drop")
        cfgDrop.animation.inType = .kineticDrop
        cfgDrop.animation.inDuration = 1.0
        let evalDrop0 = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalDrop0.config.positionY < -50.0)
    }

    @Test("Pro Out Animations evaluate exit transitions: DropDown, WhipOut")
    func testProOutAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)
        let dur = 4.0

        var cfgDrop = TextConfiguration(content: "Drop Down")
        cfgDrop.animation.outType = .dropDown
        cfgDrop.animation.outDuration = 1.0
        let evalDropEnd = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 4.0, duration: dur, canvasSize: canvasSize)
        #expect(evalDropEnd.config.positionY > 50.0)
        #expect(evalDropEnd.config.opacity <= 0.05)

        var cfgWhip = TextConfiguration(content: "Whip Out")
        cfgWhip.animation.outType = .whipOut
        cfgWhip.animation.outDuration = 1.0
        let evalWhipEnd = TextAnimationEvaluator.evaluate(config: cfgWhip, localTime: 4.0, duration: dur, canvasSize: canvasSize)
        #expect(evalWhipEnd.config.positionX > 50.0)
        #expect(evalWhipEnd.config.opacity <= 0.05)
    }

    @Test("Pro Loop Animations evaluate heart and shake effects")
    func testProLoopAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgShake = TextConfiguration(content: "Shake")
        cfgShake.animation.loopType = .shake
        cfgShake.animation.loopSpeed = 1.0
        let evalShake = TextAnimationEvaluator.evaluate(config: cfgShake, localTime: 0.35, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalShake.config.rotation) > 0.001 || abs(evalShake.config.positionX) > 0.001)

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
        config.animation.outType = .fadeOut
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

    @Test("Verify actual pixels of background and glow in rendered image")
    func testVerifyBackgroundAndGlowPixels() {
        var config = TextConfiguration(content: "TEST")
        config.textColorHex = "#FFFFFF"
        config.hasBackground = true
        config.backgroundColorHex = "#FF0000FF"
        config.backgroundPadding = 30.0

        let renderer = TextRendererEngine()
        let canvasSize = CGSize(width: 400, height: 200)

        // 1. Static render (no animation)
        guard let ciImg = renderer.renderAnimatedImage(for: config, localTime: 1.0, duration: 5.0, canvasSize: canvasSize) else {
            Issue.record("Failed to render static image")
            return
        }

        let rep = NSCIImageRep(ciImage: ciImg)
        let nsImg = NSImage(size: canvasSize)
        nsImg.addRepresentation(rep)
        guard let tiff = nsImg.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            Issue.record("Failed to create bitmap")
            return
        }

        // Check center or near background
        var foundRed = false
        for x in stride(from: 50, to: 350, by: 10) {
            for y in stride(from: 50, to: 150, by: 10) {
                if let color = bitmap.colorAt(x: x, y: y) {
                    if color.redComponent > 0.8 && color.greenComponent < 0.2 && color.blueComponent < 0.2 {
                        foundRed = true
                        break
                    }
                }
            }
            if foundRed { break }
        }
        print("STATIC FOUND RED BACKGROUND:", foundRed)

        // 2. Animated render (kinetic)
        config.animation.inType = .slideUp
        config.animation.inDuration = 0.5
        guard let ciAnim = renderer.renderAnimatedImage(for: config, localTime: 1.0, duration: 5.0, canvasSize: canvasSize) else {
            Issue.record("Failed to render anim image")
            return
        }
        let repAnim = NSCIImageRep(ciImage: ciAnim)
        let nsAnim = NSImage(size: canvasSize)
        nsAnim.addRepresentation(repAnim)
        guard let tiffAnim = nsAnim.tiffRepresentation,
              let bitmapAnim = NSBitmapImageRep(data: tiffAnim) else {
            Issue.record("Failed to create anim bitmap")
            return
        }
        var foundAnimRed = false
        for x in stride(from: 50, to: 350, by: 10) {
            for y in stride(from: 50, to: 150, by: 10) {
                if let color = bitmapAnim.colorAt(x: x, y: y) {
                    if color.redComponent > 0.8 && color.greenComponent < 0.2 && color.blueComponent < 0.2 {
                        foundAnimRed = true
                        break
                    }
                }
            }
            if foundAnimRed { break }
        }
        print("ANIM FOUND RED BACKGROUND:", foundAnimRed)

        // 3. Test Glow
        var glowConfig = TextConfiguration(content: "GLOW")
        glowConfig.textColorHex = "#000000"
        glowConfig.hasGlow = true
        glowConfig.glowColorHex = "#FF0000"
        glowConfig.glowRadius = 15.0

        // Static Glow
        guard let ciGlowStatic = renderer.renderAnimatedImage(for: glowConfig, localTime: 1.0, duration: 5.0, canvasSize: canvasSize) else {
            Issue.record("Failed to render static glow")
            return
        }
        let repGlow = NSCIImageRep(ciImage: ciGlowStatic)
        let nsGlow = NSImage(size: canvasSize)
        nsGlow.addRepresentation(repGlow)
        guard let tiffGlow = nsGlow.tiffRepresentation,
              let bitmapGlow = NSBitmapImageRep(data: tiffGlow) else {
            Issue.record("Failed to create glow bitmap")
            return
        }
        var foundStaticRedGlow = false
        for x in stride(from: 50, to: 350, by: 5) {
            for y in stride(from: 50, to: 150, by: 5) {
                if let color = bitmapGlow.colorAt(x: x, y: y) {
                    if color.redComponent > 0.4 && color.greenComponent < 0.2 && color.blueComponent < 0.2 {
                        foundStaticRedGlow = true
                        break
                    }
                }
            }
            if foundStaticRedGlow { break }
        }
        print("STATIC FOUND RED GLOW:", foundStaticRedGlow)

        // Anim Glow
        glowConfig.animation.inType = .slideUp
        glowConfig.animation.inDuration = 0.5
        guard let ciGlowAnim = renderer.renderAnimatedImage(for: glowConfig, localTime: 1.0, duration: 5.0, canvasSize: canvasSize) else {
            Issue.record("Failed to render anim glow")
            return
        }
        let repGlowAnim = NSCIImageRep(ciImage: ciGlowAnim)
        let nsGlowAnim = NSImage(size: canvasSize)
        nsGlowAnim.addRepresentation(repGlowAnim)
        guard let tiffGlowAnim = nsGlowAnim.tiffRepresentation,
              let bitmapGlowAnim = NSBitmapImageRep(data: tiffGlowAnim) else {
            Issue.record("Failed to create anim glow bitmap")
            return
        }
        var foundAnimRedGlow = false
        for x in stride(from: 50, to: 350, by: 5) {
            for y in stride(from: 50, to: 150, by: 5) {
                if let color = bitmapGlowAnim.colorAt(x: x, y: y) {
                    if color.redComponent > 0.4 && color.greenComponent < 0.2 && color.blueComponent < 0.2 {
                        foundAnimRedGlow = true
                        break
                    }
                }
            }
            if foundAnimRedGlow { break }
        }
        print("ANIM FOUND RED GLOW:", foundAnimRedGlow)
        #expect(foundRed == true, "Static text must render background")
        #expect(foundAnimRed == true, "Animated text must render background")
        #expect(foundStaticRedGlow == true, "Static text must render glow")
        #expect(foundAnimRedGlow == true, "Animated text must render glow")
    }
}


