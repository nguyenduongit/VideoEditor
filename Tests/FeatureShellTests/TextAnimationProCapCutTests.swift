import Testing
import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
@testable import Domain
@testable import FeatureShell

@Suite("TextAnimationProCapCutTests")
@MainActor
struct TextAnimationProCapCutTests {
    @Test("TextAnimationConfiguration supports scope, combo, stagger direction, anchor and motion blur defaults")
    func testTextAnimationScopeAndStaggerDefaults() {
        let config = TextAnimationConfiguration()
        #expect(config.scope == .wholeBlock)
        #expect(config.staggerDirection == .forward)
        #expect(config.anchorPoint == .center)
        #expect(config.comboType == .none)
        #expect(config.staggerDelay == 0.04)
        #expect(config.rgbSplitIntensity == 0.0)
        #expect(config.lightSweepIntensity == 0.0)
        #expect(config.isMaskEnabled == false)
        #expect(config.isMotionBlurEnabled == true)
        #expect(config.isDefault == true)
    }

    @Test("Drop and Bounce In Animations calculate expected motion offsets and impact squash")
    func testDropAndBounceEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgDrop = TextConfiguration(content: "Drop")
        cfgDrop.animation.inType = .drop
        cfgDrop.animation.inDuration = 1.0
        let evalDrop = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalDrop.config.positionY) > 0.001)

        var cfgBounce = TextConfiguration(content: "Bounce")
        cfgBounce.animation.inType = .bounce
        cfgBounce.animation.inDuration = 1.0
        let evalBounce = TextAnimationEvaluator.evaluate(config: cfgBounce, localTime: 0.15, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalBounce.overlay.scaleX - evalBounce.overlay.scaleY) > 0.01)
    }

    @Test("CapCut Pro In Animations evaluate MoveIn, Unfold, 3D Flip and Wipe")
    func testCapCutProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgMove = TextConfiguration(content: "Move")
        cfgMove.animation.inType = .moveIn
        cfgMove.animation.inDuration = 1.0
        let evalMove = TextAnimationEvaluator.evaluate(config: cfgMove, localTime: 0.1, duration: 4.0, canvasSize: canvasSize)
        #expect(evalMove.config.positionX < 0.0)
        #expect(evalMove.overlay.motionBlurRadius > 1.0)

        var cfgUnfold = TextConfiguration(content: "Unfold")
        cfgUnfold.animation.inType = .unfold
        cfgUnfold.animation.inDuration = 1.0
        let evalUnfold = TextAnimationEvaluator.evaluate(config: cfgUnfold, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
        #expect(evalUnfold.overlay.scaleY < 1.0)

        var cfgFlip = TextConfiguration(content: "Flip")
        cfgFlip.animation.inType = .flip3D
        cfgFlip.animation.inDuration = 1.0
        let evalFlip = TextAnimationEvaluator.evaluate(config: cfgFlip, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalFlip.overlay.perspectiveX) > 0.05)

        var cfgWipe = TextConfiguration(content: "WipeAnimation")
        cfgWipe.animation.inType = .wipe
        cfgWipe.animation.inDuration = 1.0
        let evalWipe = TextAnimationEvaluator.evaluate(config: cfgWipe, localTime: 0.4, duration: 4.0, canvasSize: canvasSize)
        #expect(evalWipe.config.content.count < "WipeAnimation".count)
    }

    @Test("Loop Animation runs strictly between In completion and Out start")
    func testLoopAnimationActiveBetweenInAndOut() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfg = TextConfiguration(content: "LoopTest")
        cfg.animation.inType = .fadeIn
        cfg.animation.inDuration = 1.0
        cfg.animation.outType = .fadeOut
        cfg.animation.outDuration = 1.0
        cfg.animation.loopType = .pulse
        cfg.animation.loopSpeed = 1.0

        // At t = 0.5 (during In): loop blend is 0, scale unchanged by pulse
        let evalIn = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.5, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalIn.config.scale - 1.0) < 0.001)

        // At t = 2.25 (in middle window): loop is fully active
        let evalMid = TextAnimationEvaluator.evaluate(config: cfg, localTime: 2.25, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalMid.config.scale - 1.0) > 0.005)

        // At t = 4.8 (during Out): loop blend is 0
        let evalOut = TextAnimationEvaluator.evaluate(config: cfg, localTime: 4.8, duration: 5.0, canvasSize: canvasSize)
        #expect(evalOut.config.opacity < 0.5)
    }

    @Test("Stagger Direction calculates expected ordering for forward, backward and centerOut")
    func testStaggerDirectionOrdering() {
        let fwd0 = TextAnimationCurves.staggerOrderIndex(index: 0, count: 5, direction: .forward)
        let fwd4 = TextAnimationCurves.staggerOrderIndex(index: 4, count: 5, direction: .forward)
        #expect(fwd0 == 0.0)
        #expect(fwd4 == 4.0)

        let bwd0 = TextAnimationCurves.staggerOrderIndex(index: 0, count: 5, direction: .backward)
        let bwd4 = TextAnimationCurves.staggerOrderIndex(index: 4, count: 5, direction: .backward)
        #expect(bwd0 == 4.0)
        #expect(bwd4 == 0.0)

        let centerMid = TextAnimationCurves.staggerOrderIndex(index: 2, count: 5, direction: .centerOut)
        let centerEdge = TextAnimationCurves.staggerOrderIndex(index: 0, count: 5, direction: .centerOut)
        #expect(centerMid == 0.0)
        #expect(centerEdge == 2.0)
    }

    #if os(macOS)
    @Test("TextSegmentRenderer tokenizes words and characters accurately")
    func testTextSegmentTokenization() {
        let font = NSFont.systemFont(ofSize: 24)
        let sample = "Hello World"

        let (charTokens, charWidth) = TextSegmentRenderer.tokenize(
            content: sample, scope: .perCharacter, font: font, spacing: 0
        )
        #expect(charTokens.count == sample.count)
        #expect(charWidth > 0)

        let (wordTokens, wordWidth) = TextSegmentRenderer.tokenize(
            content: sample, scope: .perWord, font: font, spacing: 0
        )
        #expect(wordTokens.count >= 2)
        #expect(wordWidth > 0)
    }

    @Test("Per-Character animated rendering generates valid CIImage with Shaders")
    func testSegmentedAndKaraokeRenderingProducesValidImage() {
        var config = TextConfiguration(content: "CAPCUT PRO VIBE")
        config.animation.inType = .bounce
        config.animation.scope = .perCharacter
        config.animation.staggerDirection = .centerOut
        config.animation.staggerDelay = 0.05
        config.animation.rgbSplitIntensity = 3.0
        config.animation.lightSweepIntensity = 0.6

        let canvasSize = CGSize(width: 800, height: 500)
        let image = TextRendererEngine().renderAnimatedImage(
            for: config,
            localTime: 0.3,
            duration: 3.0,
            canvasSize: canvasSize
        )
        #expect(image != nil)
        if let image {
            #expect(image.extent.width > 0)
            #expect(image.extent.height > 0)
        }
    }
    #endif

    @Test("TextAnimationCurves spring overshoot returns correct bounds")
    func testSpringOvershootCurves() {
        let atStart = TextAnimationCurves.springOvershoot(0.0)
        #expect(abs(atStart) < 0.01)

        let atEnd = TextAnimationCurves.springOvershoot(1.0)
        #expect(abs(atEnd - 1.0) < 0.01)

        let mid = TextAnimationCurves.springOvershoot(0.8)
        #expect(mid > 0.9)
    }

    @Test("TextTemplateLoader loads online presets and supports Supabase forward-compatible payloads")
    func testTextTemplateLoaderAndSupabaseSync() {
        // Kiểm tra Forward Compatibility khi nhận JSON từ Supabase có hiệu ứng tương lai chưa tồn tại
        let futureSupabaseJSON = """
        {
          "id": "supabase_remote_future_1",
          "schemaVersion": 2,
          "name": "Mẫu Tương Lai Supabase",
          "description": "Đồng bộ từ bảng text_templates",
          "category": "Future AI Category",
          "defaultDuration": 3.5,
          "config": {
            "content": "REMOTE TEMPLATE",
            "fontName": "Impact",
            "fontSize": 60.0,
            "textColorHex": "#22D3EE",
            "hasGlow": true,
            "glowColorHex": "#06B6D4",
            "animation": {
              "inType": "FutureHologram2028",
              "comboType": "Karaoke Box"
            }
          }
        }
        """
        guard let decodedRemote = TextPreset.decode(from: futureSupabaseJSON) else {
            Issue.record("Failed to decode forward-compatible Supabase template JSON")
            return
        }
        #expect(decodedRemote.id == "supabase_remote_future_1")
        #expect(decodedRemote.category == .trending) // Fallback an toàn
        #expect(decodedRemote.config.animation.inType == .none) // Fallback an toàn khi gặp enum lạ
        #expect(decodedRemote.config.animation.comboType == .karaokeBox)
    }

    @Test("Multi-layer compound template adds both main and subLayer clips in single undoable transaction")
    func testCompoundMultiLayerTemplateInsertion() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let libraryVM = TextLibraryViewModel(timelineViewModel: timelineVM)

        var subConfig = TextConfiguration(content: "SUBTITLE", fontSize: 32.0)
        subConfig.positionY = 50.0
        let compound = TextPreset(
            id: "compound_test_preset",
            name: "Compound Headline",
            description: "Test compound template",
            category: .trending,
            tags: ["news", "headline"],
            config: TextConfiguration(content: "BREAKING NEWS", fontSize: 64.0),
            subLayers: [
                TextTemplateSubLayer(
                    name: "sub_1",
                    config: subConfig
                )
            ],
            isSystem: false
        )
        #expect(!compound.subLayers.isEmpty)

        libraryVM.addPresetToTimeline(compound)
        let textClips = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(textClips.count == 2)
        #expect(timelineVM.canUndo == true)

        _ = timelineVM.undo()
        let afterUndo = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(afterUndo.isEmpty)
    }

    @Test("In, Out and Loop animations can be deselected or toggled back to none")
    func testInAndOutAnimationDeselectAndToggle() {
        var config = TextConfiguration()
        #expect(config.animation.inType == .none)
        #expect(config.animation.outType == .none)
        #expect(config.animation.loopType == .none)

        // Select In: slideUp
        let inSelected: TextInAnimationType = .slideUp
        config.animation.inType = (config.animation.inType == inSelected || inSelected == .none) ? .none : inSelected
        #expect(config.animation.inType == .slideUp)
        config.animation.inType = (config.animation.inType == inSelected || inSelected == .none) ? .none : inSelected
        #expect(config.animation.inType == .none)

        // Select Out: fadeOut
        let outSelected: TextOutAnimationType = .fadeOut
        config.animation.outType = (config.animation.outType == outSelected || outSelected == .none) ? .none : outSelected
        #expect(config.animation.outType == .fadeOut)
        config.animation.outType = (config.animation.outType == outSelected || outSelected == .none) ? .none : outSelected
        #expect(config.animation.outType == .none)

        // Select Loop: pulse
        let loopSelected: TextLoopAnimationType = .pulse
        config.animation.loopType = (config.animation.loopType == loopSelected || loopSelected == .none) ? .none : loopSelected
        #expect(config.animation.loopType == .pulse)
        config.animation.loopType = (config.animation.loopType == loopSelected || loopSelected == .none) ? .none : loopSelected
        #expect(config.animation.loopType == .none)
    }
}
