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

@Suite("TextAnimationProCapCutTests")
@MainActor
struct TextAnimationProCapCutTests {
    @Test("TextAnimationConfiguration supports unified script defaults and timing modifiers")
    func testTextAnimationScopeAndStaggerDefaults() {
        let config = TextAnimationConfiguration()
        #expect(config.scope == .wholeBlock)
        #expect(config.staggerDirection == .forward)
        #expect(config.anchorPoint == .center)
        #expect(config.scriptId == "none")
        #expect(config.staggerDelay == 0.04)
        #expect(config.isMaskEnabled == false)
        #expect(config.isMotionBlurEnabled == true)
        #expect(config.isDefault == true)
    }

    @Test("KineticDrop and Slide unified scripts evaluate motion offsets seamlessly")
    func testDropAndBounceEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgDrop = TextConfiguration(content: "Drop")
        cfgDrop.animation.scriptId = "kinetic_drop_glow"
        let evalDrop = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 0.2, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalDrop.config.positionY) > 0.001 || evalDrop.config.opacity < 1.0)

        var cfgSlide = TextConfiguration(content: "Slide")
        cfgSlide.animation.scriptId = "slide_right_right"
        let evalSlide = TextAnimationEvaluator.evaluate(config: cfgSlide, localTime: 0.15, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalSlide.config.positionY) > 0.001 || abs(evalSlide.config.positionX) > 0.001 || evalSlide.config.opacity < 1.0)
    }

    @Test("Unified scripts evaluate Slide and TypewriterCursor smoothly")
    func testCapCutProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgMove = TextConfiguration(content: "Move")
        cfgMove.animation.scriptId = "slide_right_right"
        let evalMove = TextAnimationEvaluator.evaluate(config: cfgMove, localTime: 0.15, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalMove.config.positionX) > 0.5)

        var cfgType = TextConfiguration(content: "TypewriterAnimation")
        cfgType.animation.scriptId = "typewriter_cursor"
        let evalTypeHidden = TextAnimationEvaluator.evaluate(
            config: cfgType, localTime: 0.1, duration: 5.0, canvasSize: canvasSize, charIndex: 10, charCount: 19
        )
        #expect(evalTypeHidden.config.opacity == 0.0)
    }

    @Test("Unified scripts execute continuous Intro -> Loop -> Outro progression with integer loop cycles")
    func testLoopAnimationActiveBetweenInAndOut() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfg = TextConfiguration(content: "LoopTest")
        cfg.animation.scriptId = "wave_liquid_ripple"
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3, speed: 1.0)

        let evalIn = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.1, duration: 5.0, canvasSize: canvasSize)
        #expect(evalIn.config.opacity < 1.0)

        let evalMid = TextAnimationEvaluator.evaluate(config: cfg, localTime: 2.25, duration: 5.0, canvasSize: canvasSize)
        #expect(evalMid.config.opacity == 1.0)

        let evalOut = TextAnimationEvaluator.evaluate(config: cfg, localTime: 4.9, duration: 5.0, canvasSize: canvasSize)
        #expect(evalOut.config.opacity < 0.8)
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

    @Test("Per-Character unified script rendering generates valid CIImage with Shaders")
    func testSegmentedAndKaraokeRenderingProducesValidImage() {
        var config = TextConfiguration(content: "CAPCUT PRO VIBE")
        config.animation.scriptId = "kinetic_drop_glow"

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
              "inType": "FutureHologram2028"
            }
          }
        }
        """
        guard let decodedRemote = TextPreset.decode(from: futureSupabaseJSON) else {
            Issue.record("Failed to decode forward-compatible Supabase template JSON")
            return
        }
        #expect(decodedRemote.id == "supabase_remote_future_1")
        #expect(decodedRemote.category == .trending) // Safe fallback
        #expect(decodedRemote.config.animation.scriptId == "none") // Safe fallback on unknown key
    }

    @Test("Unified TextPreset adds a single undoable TextClip transaction onto the timeline")
    func testUnifiedPresetSingleClipInsertionAndUndo() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let libraryVM = TextLibraryViewModel(timelineViewModel: timelineVM)

        let preset = TextPreset(
            id: "unified_test_preset",
            name: "Unified Headline",
            description: "Test unified template",
            category: .trending,
            tags: ["news", "headline"],
            config: TextConfiguration(
                content: "BREAKING NEWS",
                fontSize: 64.0,
                background: TextBackgroundStyle(isEnabled: true, sourceKind: .solid, solidColorHex: "#EF4444")
            ),
            isSystem: false
        )

        libraryVM.addPresetToTimeline(preset)
        let textClips = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(textClips.count == 1)
        #expect(timelineVM.canUndo == true)

        _ = timelineVM.undo()
        let afterUndo = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(afterUndo.isEmpty)
    }

    @Test("Unified animation script can be selected and cleared back to none")
    func testInAndOutAnimationDeselectAndToggle() {
        var config = TextConfiguration()
        #expect(config.animation.scriptId == "none")

        let chosen = "kinetic_drop_glow"
        config.animation.scriptId = (config.animation.scriptId == chosen) ? "none" : chosen
        #expect(config.animation.scriptId == "kinetic_drop_glow")
        config.animation.scriptId = (config.animation.scriptId == chosen) ? "none" : chosen
        #expect(config.animation.scriptId == "none")
    }

    @Test("TimelineViewModel and ShellViewModel loop playback range and click stop callbacks")
    func testTextAnimationLoopRangePreviewAndStopCallbacks() {
        let shellVM = ShellViewModel(registry: TabRegistry())
        let clipRange = CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600))

        // Trigger loop range request (as done when selecting animation)
        shellVM.timelineViewModel.onLoopRangeRequested?(clipRange)
        #expect(shellVM.playbackEngine.loopRange == clipRange)

        // Trigger stop request (as done when clicking anywhere)
        shellVM.timelineViewModel.onStopPlaybackRequested?()
        #expect(shellVM.playbackEngine.loopRange == nil)

        // When loopRange is nil, onStopPlaybackRequested does not alter playing state if not in loop mode
        shellVM.playbackEngine.loopRange = nil
        shellVM.timelineViewModel.onStopPlaybackRequested?()
        #expect(shellVM.playbackEngine.loopRange == nil)
    }
}
