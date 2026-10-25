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

    @Test("WaveBounce and SpringDrop calculate expected motion offsets and impact squash")
    func testWaveBounceAndSpringDropEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgWave = TextConfiguration(content: "Wave")
        cfgWave.animation.inType = .waveBounce
        cfgWave.animation.inDuration = 1.0
        let evalWave = TextAnimationEvaluator.evaluate(config: cfgWave, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalWave.config.positionY) > 0.001)

        var cfgDrop = TextConfiguration(content: "Drop")
        cfgDrop.animation.inType = .springDrop
        cfgDrop.animation.inDuration = 1.0
        let evalDrop0 = TextAnimationEvaluator.evaluate(config: cfgDrop, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalDrop0.config.positionY < 0.0)
        #expect(evalDrop0.overlay.scaleY > evalDrop0.overlay.scaleX)
    }

    @Test("CapCut Pro In Animations evaluate Squash & Stretch, Skew, Motion Blur and 3D Perspective")
    func testCapCutProInAnimationsEvaluation() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgJelly = TextConfiguration(content: "Jelly")
        cfgJelly.animation.inType = .elasticJellyIn
        cfgJelly.animation.inDuration = 1.0
        let evalJelly = TextAnimationEvaluator.evaluate(config: cfgJelly, localTime: 0.15, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalJelly.overlay.scaleX - evalJelly.overlay.scaleY) > 0.05)

        var cfgWhip = TextConfiguration(content: "Whip")
        cfgWhip.animation.inType = .whipPanLeft
        cfgWhip.animation.inDuration = 1.0
        let evalWhip = TextAnimationEvaluator.evaluate(config: cfgWhip, localTime: 0.1, duration: 4.0, canvasSize: canvasSize)
        #expect(evalWhip.config.positionX < 0.0)
        #expect(evalWhip.overlay.skewX != 0.0)
        #expect(evalWhip.overlay.motionBlurRadius > 5.0)

        var cfgOrigami = TextConfiguration(content: "Origami")
        cfgOrigami.animation.inType = .origamiUnfold
        cfgOrigami.animation.inDuration = 1.0
        let evalOrigami = TextAnimationEvaluator.evaluate(config: cfgOrigami, localTime: 0.2, duration: 4.0, canvasSize: canvasSize)
        #expect(evalOrigami.overlay.perspectiveX < -0.1)
    }

    @Test("Cinema Tracking Expand and Collapse modify character spacing correctly")
    func testCinemaTrackingExpandAndCollapse() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgExpand = TextConfiguration(content: "Cinema", characterSpacing: 2.0)
        cfgExpand.animation.inType = .trackingExpand
        cfgExpand.animation.inDuration = 1.0
        let evalExpand0 = TextAnimationEvaluator.evaluate(config: cfgExpand, localTime: 0.0, duration: 4.0, canvasSize: canvasSize)
        #expect(evalExpand0.config.characterSpacing < 2.0)

        let evalExpandDone = TextAnimationEvaluator.evaluate(config: cfgExpand, localTime: 1.0, duration: 4.0, canvasSize: canvasSize)
        #expect(abs(evalExpandDone.config.characterSpacing - 2.0) < 0.01)
    }

    @Test("Combo Animation pendulum, zoomShake, elasticJelly and cyberScanline animate continuously")
    func testComboAnimationPendulumAndZoomShake() {
        let canvasSize = CGSize(width: 1000, height: 1000)

        var cfgPendulum = TextConfiguration(content: "Pendulum")
        cfgPendulum.animation.comboType = .pendulum
        let evalPendulum = TextAnimationEvaluator.evaluate(config: cfgPendulum, localTime: 1.0, duration: 5.0, canvasSize: canvasSize)
        #expect(abs(evalPendulum.config.rotation) > 0.001 || abs(evalPendulum.config.positionX) > 0.001)

        var cfgShake = TextConfiguration(content: "Shake")
        cfgShake.animation.comboType = .zoomShake
        let evalShake = TextAnimationEvaluator.evaluate(config: cfgShake, localTime: 2.5, duration: 5.0, canvasSize: canvasSize)
        #expect(evalShake.config.scale > 1.0)

        var cfgScan = TextConfiguration(content: "Cyber")
        cfgScan.animation.comboType = .cyberScanline
        let evalScan = TextAnimationEvaluator.evaluate(config: cfgScan, localTime: 0.5, duration: 5.0, canvasSize: canvasSize)
        #expect(evalScan.overlay.lightSweepPhase >= 0.0)
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

    @Test("Per-Character and Karaoke Box animated rendering generates valid CIImage with Shaders")
    func testSegmentedAndKaraokeRenderingProducesValidImage() {
        var config = TextConfiguration(content: "CAPCUT PRO VIBE")
        config.animation.inType = .elasticJellyIn
        config.animation.scope = .perCharacter
        config.animation.staggerDirection = .centerOut
        config.animation.staggerDelay = 0.05
        config.animation.rgbSplitIntensity = 3.0
        config.animation.lightSweepIntensity = 0.6

        let canvasSize = CGSize(width: 800, height: 500)
        let image = TextRendererEngine.shared.renderAnimatedImage(
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

        var karaokeConfig = TextConfiguration(content: "KARAOKE BOX ACTIVE")
        karaokeConfig.animation.comboType = .karaokeBox
        karaokeConfig.animation.highlightColorHex = "#FDE047"
        let karaokeImg = TextRendererEngine.shared.renderAnimatedImage(
            for: karaokeConfig,
            localTime: 1.2,
            duration: 3.0,
            canvasSize: canvasSize
        )
        #expect(karaokeImg != nil)
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

    @Test("TextTemplateLoader loads all 19 standalone JSON scripts and supports Supabase forward-compatible payloads")
    func testTextTemplateLoaderAndSupabaseSync() {
        let loaded = TextTemplateLoader.shared.reload()
        #expect(loaded.count >= 19)

        let karaokeBox = loaded.first { $0.id == "karaoke_tiktok_box" }
        #expect(karaokeBox != nil)
        #expect(karaokeBox?.category == .karaoke)
        #expect(karaokeBox?.config.animation.comboType == .karaokeBox)

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

        guard let compound = libraryVM.templatePresets.first(where: { $0.id == "breaking_news_live" }) else {
            Issue.record("Missing breaking_news_live template")
            return
        }
        #expect(!compound.subLayers.isEmpty)

        libraryVM.addPresetToTimeline(compound)
        let textClips = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(textClips.count == 2)
        #expect(timelineVM.canUndo == true)

        _ = timelineVM.undo()
        let afterUndo = timelineVM.layers.flatMap(\.clips).filter { $0.kind == .text }
        #expect(afterUndo.isEmpty)
    }
}
