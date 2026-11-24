import Foundation
import CoreMedia
import CoreGraphics
import CoreImage
import AVFoundation
#if os(macOS)
import AppKit
#endif
import Testing
import Domain
@testable import FeatureShell

@Suite("TextIntegrationTests")
@MainActor
struct TextIntegrationTests {
    @Test func testTextPresetLibraryInitialState() {
        let vm = TextLibraryViewModel(timelineViewModel: nil)
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.filteredPresetsWithDefaultFirst.first?.id == "default")
        #expect(vm.defaultPreset.name == "Default Text")
        #expect(vm.defaultPreset.config.content == "Text")
    }

    @Test func testTextConfigurationJSONSerialization() {
        var config = TextConfiguration()
        config.content = "Xin chào Việt Nam"
        config.fontName = "Impact"
        config.fontSize = 64.0
        config.textColorHex = "#FFCC00"
        config.isBold = true
        config.isItalic = true
        config.alignment = .right
        config.hasStroke = true
        config.strokeColorHex = "#000000"
        config.strokeWidth = 3.5
        config.hasShadow = true
        config.shadowRadius = 8.0
        config.hasBackground = true
        config.backgroundColorHex = "#FF0000CC"
        config.positionX = 120.0
        config.positionY = -45.0
        config.scale = 1.25
        config.rotation = 15.0
        config.opacity = 0.85

        guard let json = config.encodeToJSON() else {
            Issue.record("Failed to encode TextConfiguration")
            return
        }

        guard let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Failed to decode TextConfiguration")
            return
        }

        #expect(decoded.content == "Xin chào Việt Nam")
        #expect(decoded.fontName == "Impact")
        #expect(decoded.fontSize == 64.0)
        #expect(decoded.textColorHex == "#FFCC00")
        #expect(decoded.isBold == true)
        #expect(decoded.isItalic == true)
        #expect(decoded.alignment == .right)
        #expect(decoded.hasStroke == true)
        #expect(decoded.strokeWidth == 3.5)
        #expect(decoded.hasShadow == true)
        #expect(decoded.shadowRadius == 8.0)
        #expect(decoded.hasBackground == true)
        #expect(decoded.backgroundColorHex == "#FF0000CC")
        #expect(decoded.positionX == 120.0)
        #expect(decoded.positionY == -45.0)
        #expect(decoded.scale == 1.25)
        #expect(decoded.rotation == 15.0)
        #expect(decoded.opacity == 0.85)
    }

    @Test func testAddTextClipToTimelineAndUndoRedo() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let libraryVM = TextLibraryViewModel(timelineViewModel: timelineVM)

        let preset = TextPreset.templates[0]
        libraryVM.addPresetToTimeline(preset)

        #expect(!timelineVM.layers.isEmpty)
        let textLayer = timelineVM.layers.first { $0.kind == .text }
        #expect(textLayer != nil)
        #expect(textLayer?.clips.count == 1)

        guard let clip = textLayer?.clips.first else {
            Issue.record("No text clip found on timeline")
            return
        }

        #expect(clip.kind == .text)
        #expect(clip.name == preset.config.content)
        #expect(clip.properties["textConfig"] != nil)
        #expect(clip.properties["textContent"]?.asString == preset.config.content)
        #expect(timelineVM.selectedClipIDs.contains(clip.id))
        #expect(timelineVM.canUndo == true)

        let undoSuccess = timelineVM.undo()
        #expect(undoSuccess == true)
        let textLayerAfterUndo = timelineVM.layers.first { $0.kind == .text }
        #expect(textLayerAfterUndo?.clips.isEmpty ?? true)

        let redoSuccess = timelineVM.redo()
        #expect(redoSuccess == true)
        let textLayerAfterRedo = timelineVM.layers.first { $0.kind == .text }
        #expect(textLayerAfterRedo?.clips.count == 1)
    }

    @Test func testTextRendererEngineDrawsImageAndMeasures() {
        let canvasSize = CGSize(width: 1920, height: 1080)
        var config = TextConfiguration()
        config.content = "Test Typography Render"
        config.fontSize = 54.0
        config.hasStroke = true
        config.strokeWidth = 2.0
        config.hasShadow = true
        config.hasBackground = true

        let size = TextRendererEngine().measureSize(for: config, canvasSize: canvasSize)
        #expect(size.width > 50.0)
        #expect(size.height > 20.0)

        let ciImage = TextRendererEngine().renderImage(for: config, canvasSize: canvasSize)
        #expect(ciImage != nil)
        #expect(ciImage?.extent.size == canvasSize)
    }

    @Test func testInspectorTabsForTextClip() {
        let registry = ClipPropertyRegistry()
        let tabs = registry.tabs(for: .text)
        #expect(tabs == ["Text", "Appearance", "Background", "Animation"])

        let timelineVM = TimelineViewModel(initialLayers: [])
        timelineVM.addTextClip(named: "Tiêu đề", config: TextConfiguration(content: "Tiêu đề"))
        guard let clip = timelineVM.layers.flatMap(\.clips).first(where: { $0.kind == .text }) else {
            Issue.record("No text clip found")
            return
        }

        timelineVM.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.selectedClip?.id == clip.id)
        #expect(inspectorVM.availableTabs == ["Text", "Appearance", "Background", "Animation"])
        #expect(inspectorVM.effectiveTab == "Text")
    }

    @Test func testTimelineCompositionBuilderWithTextLayer() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        #expect(!TimelineCompositionBuilder.hasActiveMask(in: timelineVM.layers))

        timelineVM.addTextClip(named: "Watermark", config: TextConfiguration(content: "Watermark"))
        #expect(TimelineCompositionBuilder.hasActiveMask(in: timelineVM.layers))
    }

    @Test func testGeneratePreviewFrameArtifact() {
        let canvasSize = CGSize(width: 1280, height: 720)
        var headline = TextConfiguration(content: "TIÊU ĐỀ VIDEO ĐẸP", fontSize: 64.0, isBold: true)
        headline.positionY = -60

        var subtitle = TextConfiguration(content: "Phụ đề mẫu chuẩn TikTok / YouTube", fontSize: 32.0)
        subtitle.hasBackground = true
        subtitle.positionY = 160

        guard let img1 = TextRendererEngine().renderImage(for: headline, canvasSize: canvasSize),
              let img2 = TextRendererEngine().renderImage(for: subtitle, canvasSize: canvasSize) else {
            Issue.record("Failed to render preview images")
            return
        }

        let bg = CIImage(color: CIColor(red: 0.12, green: 0.13, blue: 0.15)).cropped(to: CGRect(origin: .zero, size: canvasSize))
        let composed = img2.composited(over: img1.composited(over: bg))

        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(composed, from: CGRect(origin: .zero, size: canvasSize)) else { return }
        #if os(macOS)
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let outPath = "/Users/nguyenquocduong/.gemini/antigravity-ide/brain/30d534ac-1ef1-43bb-b540-7ba32ad384ba/rendered_text_frame.png"
            try? pngData.write(to: URL(fileURLWithPath: outPath))
        }
        #endif
    }

    @Test func testTextClipDragSyncsGeometryAndRenderEngine() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        timelineVM.addTextClip(named: "MoveMe", config: TextConfiguration(content: "MoveMe", positionX: 0, positionY: 0))
        guard let clip = timelineVM.layers.flatMap(\.clips).first(where: { $0.kind == .text }) else {
            Issue.record("No text clip found")
            return
        }

        timelineVM.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        // Simulate dragging text on canvas
        inspectorVM.updateLiveValue(key: "positionX", value: 150.0)
        inspectorVM.updateLiveValue(key: "positionY", value: -250.0)

        // Verify live properties on clip
        guard let updatedClip = timelineVM.clip(by: clip.id) else {
            Issue.record("Clip not found after update")
            return
        }
        #expect(updatedClip.properties["positionX"]?.asNumber == 150.0)
        #expect(updatedClip.properties["positionY"]?.asNumber == -250.0)

        // Verify bounding box geometry
        let canvasSize = CGSize(width: 1920, height: 1080)
        let geom = ClipCanvasGeometry.compute(for: updatedClip, canvasSize: canvasSize)
        #expect(geom.positionX == 150.0)
        #expect(geom.positionY == -250.0)

        // Verify composition instructions pass the updated coordinates to render engine
        let composition = AVMutableComposition()
        let customComp = TimelineCompositionBuilder.buildMaskVideoComposition(
            for: timelineVM.layers,
            composition: composition,
            layerTrackIDs: [:],
            aspectRatio: .ratio16x9,
            duration: CMTime(value: 5, timescale: 1)
        )
        guard let instruction = customComp?.instructions.first as? TimelineCustomVideoCompositionInstruction,
              let textInfo = instruction.layerInfos.first(where: { $0.isText }) else {
            Issue.record("No text instruction found")
            return
        }

        #expect(textInfo.textConfig?.positionX == 150.0)
        #expect(textInfo.textConfig?.positionY == -250.0)
    }

    @Test func testTextColorSwatchesAndPresetColorMatching() {
        let swatches = TextColorSwatchesRow.defaultSwatches
        #expect(swatches.count == 14)
        #expect(swatches.contains("#FDE047"))
        #expect(swatches.contains("#F97316"))
        #expect(swatches.contains("#06B6D4"))
        #expect(swatches.contains("#EF4444"))

        var neonConfig = TextConfiguration(content: "NEON", fontSize: 48)
        neonConfig.textColorHex = "#FDE047"
        neonConfig.shadowColorHex = "#F97316"
        let sampleNeon = TextPreset(
            id: "neon_yellow",
            name: "Neon Vàng",
            description: "Mẫu test neon",
            config: neonConfig
        )
        let loader = TextTemplateLoader()
        loader.updateInMemoryPreset(sampleNeon)

        let neon = loader.loadAllTemplates().first { $0.id == "neon_yellow" }
        #expect(neon != nil)
        #expect(neon?.config.textColorHex == "#FDE047")
        #expect(neon?.config.shadowColorHex == "#F97316")

        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FDE047", selectedHex: "#FDE047"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FDE047", selectedHex: "#fde047"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FDE047", selectedHex: "#FDE047FF"))

        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FDE047", selectedHex: "#FFF566"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#FDE047", selectedHex: "#FFEA00"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#F97316", selectedHex: "#FF7A45"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#06B6D4", selectedHex: "#36CFC9"))
        #expect(TextColorSwatchesRow.isColorMatching(swatchHex: "#EF4444", selectedHex: "#CF1322"))

        let isMatched = swatches.contains { TextColorSwatchesRow.isColorMatching(swatchHex: $0, selectedHex: "#FFF1B8") }
        #expect(!isMatched)
    }

    @Test func testFourPillarsPropertiesAndSerialization() {
        var cfg = TextConfiguration(content: "Architecture 4 Pillars")
        cfg.skewX = 15.0
        cfg.skewY = -8.0
        cfg.blurRadius = 6.0
        cfg.glitchIntensity = 45.0
        cfg.noiseIntensity = 20.0
        cfg.innerStroke.width = 3.0
        cfg.outerStroke.width = 6.0

        guard let json = cfg.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Failed to serialize or deserialize 4 pillars TextConfiguration")
            return
        }

        #expect(decoded.skewX == 15.0)
        #expect(decoded.skewY == -8.0)
        #expect(decoded.blurRadius == 6.0)
        #expect(decoded.glitchIntensity == 45.0)
        #expect(decoded.noiseIntensity == 20.0)
        #expect(decoded.innerStroke.width == 3.0)
        #expect(decoded.outerStroke.width == 6.0)
    }

    @Test func testScriptDrivenContinuousAnimationEvaluation() {
        let registry = TextAnimationScriptRegistry.shared
        #expect(TextAnimationCategory.allCases == [.fade, .slide, .pop, .wave, .typewriter, .threeD])
        #expect(TextTemplateCategory.assignableCases == [.title, .sub, .music])
        #expect(registry.scripts.count == 34)
        #expect(registry.scripts(in: .wave).count >= 5)
        #expect(registry.scripts(in: .fade).count >= 6)
        #expect(registry.scripts(in: .slide).count == 8)
        #expect(registry.scripts(in: .pop).count >= 5)
        #expect(registry.scripts(in: .typewriter).count == 5)
        #expect(registry.scripts(in: .threeD).count >= 4)
        #expect(registry.script(for: "wave_cascade_flow") != nil)
        #expect(registry.script(for: "karaoke_box_pop")?.id == "karaoke_glow_flow")
        #expect(registry.script(for: "line_cascade_rise")?.id == "slide_up_up")

        guard let titleWave = registry.script(for: "title_wave_float") else {
            Issue.record("Missing title_wave_float script")
            return
        }
        #expect(titleWave.category == .wave)
        #expect(titleWave.tag == .wave)
        #expect(titleWave.defaultInDuration == 1.0)
        #expect(titleWave.defaultLoopDuration == 3.0)
        #expect(titleWave.defaultOutDuration == 1.0)
        #expect(titleWave.defaultDuration == 5.0)
        #expect(titleWave.loopCycleDuration == 1.0)

        let baseCfg = TextConfiguration(content: "TITLE")
        for idx in 0..<5 {
            let endIn = titleWave.evaluatePhase(base: baseCfg, phase: .intro(progress: 1.0), unitIndex: idx, unitTotal: 5)
            let startLoop = titleWave.evaluatePhase(base: baseCfg, phase: .loop(time: 0.0, cycleProgress: 0.0), unitIndex: idx, unitTotal: 5)
            let endLoop = titleWave.evaluatePhase(base: baseCfg, phase: .loop(time: 3.0, cycleProgress: 1.0), unitIndex: idx, unitTotal: 5)
            let startOut = titleWave.evaluatePhase(base: baseCfg, phase: .outro(progress: 0.0), unitIndex: idx, unitTotal: 5)

            #expect(abs(endIn.offsetX - startLoop.offsetX) < 1e-9)
            #expect(abs(endIn.offsetY - startLoop.offsetY) < 1e-9)
            #expect(abs(endIn.scaleX - startLoop.scaleX) < 1e-9)
            #expect(abs(endIn.scaleY - startLoop.scaleY) < 1e-9)
            #expect(abs(endIn.rotation - startLoop.rotation) < 1e-9)
            #expect(abs(endIn.opacity - startLoop.opacity) < 1e-9)

            #expect(abs(startLoop.offsetY - endLoop.offsetY) < 1e-9)
            #expect(abs(endLoop.offsetX - startOut.offsetX) < 1e-9)
            #expect(abs(endLoop.offsetY - startOut.offsetY) < 1e-9)
            #expect(abs(endLoop.scaleX - startOut.scaleX) < 1e-9)
            #expect(abs(endLoop.scaleY - startOut.scaleY) < 1e-9)
            #expect(abs(endLoop.rotation - startOut.rotation) < 1e-9)
            #expect(abs(endLoop.opacity - startOut.opacity) < 1e-9)
        }

        guard let neonScript = registry.script(for: "neon_color_shift") else {
            Issue.record("Missing neon_color_shift script")
            return
        }

        #expect(neonScript.scope == .perCharacter)
        var cfg = TextConfiguration(content: "HELLO")
        cfg.textColorHex = "#38BDF8"
        cfg.innerStroke = TextStrokeStyle(isEnabled: true, width: 3.0, colorHex: "#0F172A")
        cfg.animation.scriptId = "neon_color_shift"
        cfg.animation.scriptDuration = 2.0
        #expect(cfg.animation.hasScriptAnimation)

        // Evaluate at mid-progress: User Fill & Stroke must be 100% preserved without color clash
        let evalMid = TextAnimationEvaluator.evaluate(
            config: cfg,
            localTime: 1.0,
            duration: 2.0,
            canvasSize: CGSize(width: 1920, height: 1080),
            charIndex: 0,
            charCount: 5
        )

        #expect(evalMid.config.textColorHex == "#38BDF8")
        #expect(evalMid.config.innerStroke.width == 3.0)
        #expect(evalMid.config.innerStroke.colorHex == "#0F172A")
        #expect(evalMid.config.opacity > 0.5)

        // Verify the 4 new rendering primitives across themes
        var hingeCfg = cfg
        hingeCfg.animation.scriptId = "pop_up_hinge_3d"
        let hingeEval = TextAnimationEvaluator.evaluate(
            config: hingeCfg, localTime: 0.35, duration: 5.0, canvasSize: CGSize(width: 1280, height: 720), charIndex: 0, charCount: 5
        )
        #expect(hingeEval.config.animation.anchorPoint == .bottom)

        var slideMotionCfg = cfg
        slideMotionCfg.animation.scriptId = "slide_left_right"
        let slideMotionEval = TextAnimationEvaluator.evaluate(
            config: slideMotionCfg, localTime: 0.20, duration: 5.0, canvasSize: CGSize(width: 1280, height: 720)
        )
        #expect(slideMotionEval.overlay.motionBlurRadius > 0.5)

        var focusCfg = cfg
        focusCfg.animation.scriptId = "blur_focus_dissolve"
        let focusEval = TextAnimationEvaluator.evaluate(
            config: focusCfg, localTime: 0.35, duration: 5.0, canvasSize: CGSize(width: 1280, height: 720), charIndex: 0, charCount: 5
        )
        #expect(focusEval.overlay.trackingEmDelta > 0.05)

        var curtainCfg = cfg
        curtainCfg.animation.scriptId = "curtain_baseline_rise"
        let curtainEval = TextAnimationEvaluator.evaluate(
            config: curtainCfg, localTime: 0.35, duration: 5.0, canvasSize: CGSize(width: 1280, height: 720), charIndex: 0, charCount: 2
        )
        #expect(curtainEval.overlay.clipRevealY > 0.0 && curtainEval.overlay.clipRevealY < 1.0)

        // Render with TextRendererEngine at 60fps
        let engine = TextRendererEngine()
        let frameImg = engine.renderAnimatedImage(
            for: curtainCfg,
            localTime: 0.35,
            duration: 5.0,
            canvasSize: CGSize(width: 1280, height: 720)
        )
        #expect(frameImg != nil)
    }

    @Test func testScriptThreePhaseTransitionsAndDurations() {
        var cfg = TextConfiguration(content: "UNIFIED")
        cfg.animation.scriptId = "neon_color_shift"
        cfg.animation.scriptInDuration = 1.0
        cfg.animation.scriptLoopDuration = 3.0
        cfg.animation.scriptOutDuration = 1.0
        cfg.animation.scriptDuration = 5.0

        guard let json = cfg.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Failed to serialize 3-phase animation durations")
            return
        }

        #expect(decoded.animation.scriptInDuration == 1.0)
        #expect(decoded.animation.scriptLoopDuration == 3.0)
        #expect(decoded.animation.scriptOutDuration == 1.0)

        var scaledCfg = cfg
        scaledCfg.animation.scriptId = "title_wave_float"
        scaledCfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3, speed: 1.2)
        #expect(scaledCfg.animation.scriptBaseLoopSeconds == 3)
        #expect(abs(scaledCfg.animation.scriptInDuration - 1.2) < 1e-6)
        #expect(abs(scaledCfg.animation.scriptLoopDuration - 3.6) < 1e-6)
        #expect(abs(scaledCfg.animation.scriptOutDuration - 1.2) < 1e-6)
        #expect(abs(scaledCfg.animation.scriptDuration - 6.0) < 1e-6)

        let canvas = CGSize(width: 1920, height: 1080)
        // Intro phase
        let evalIntro = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.5, duration: 5.0, canvasSize: canvas)
        #expect(evalIntro.config.opacity > 0.0)

        // Loop phase (at boundary t = 1.0)
        let evalLoopStart = TextAnimationEvaluator.evaluate(config: cfg, localTime: 1.0, duration: 5.0, canvasSize: canvas)
        #expect(evalLoopStart.config.opacity == 1.0)

        // Outro phase (at t = 4.5)
        let evalOutro = TextAnimationEvaluator.evaluate(config: cfg, localTime: 4.5, duration: 5.0, canvasSize: canvas)
        #expect(evalOutro.config.opacity <= 1.0)
    }

    @Test func testVideoReferencedThreeScriptAnimationsAndBasicDefaultPreset() {
        let registry = TextAnimationScriptRegistry.shared
        #expect(registry.script(for: "typewriter_cursor") != nil)
        #expect(registry.script(for: "kinetic_drop_glow") != nil)
        #expect(registry.script(for: "curved_arc_roller") != nil)

        // Basic preset is hardcoded local and cannot be modified
        let loader = TextTemplateLoader()
        let templates = loader.loadAllTemplates()
        #expect(templates.first?.id == "default")
        #expect(templates.first?.isSystem == true)
        #expect(templates.first?.canBeModified(by: "any-user") == false)

        // Evaluate Video Sample 1: Typewriter Cursor
        var cfg1 = TextConfiguration(content: "Form Space")
        cfg1.animation.scriptId = "typewriter_cursor"
        let eval1Active = TextAnimationEvaluator.evaluate(config: cfg1, localTime: 0.22, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 2, charCount: 9)
        #expect(eval1Active.overlay.trailingCursorOpacity == 1.0)
        let eval1 = TextAnimationEvaluator.evaluate(config: cfg1, localTime: 1.0, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 0, charCount: 10)
        #expect(eval1.config.opacity == 1.0)

        // Evaluate Video Sample 2: Kinetic Drop Glow (Arc Toss + Cascade Drop preserves User Fill & Stroke)
        var cfg2 = TextConfiguration(content: "Text")
        cfg2.textColorHex = "#F59E0B"
        cfg2.innerStroke = TextStrokeStyle(isEnabled: true, width: 2.5, colorHex: "#B45309")
        cfg2.animation.scriptId = "kinetic_drop_glow"
        let eval2Toss = TextAnimationEvaluator.evaluate(config: cfg2, localTime: 0.35, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 2, charCount: 4)
        #expect(eval2Toss.config.positionY < -20.0)
        #expect(abs(eval2Toss.config.rotation) > 1.0)
        let eval2 = TextAnimationEvaluator.evaluate(config: cfg2, localTime: 0.8, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 0, charCount: 4)
        #expect(eval2.config.textColorHex == "#F59E0B")
        #expect(eval2.config.innerStroke.width == 2.5)
        #expect(eval2.config.innerStroke.colorHex == "#B45309")

        // Evaluate Video Sample 3: Curved Wave Path Roller ("hello, june")
        var cfg3 = TextConfiguration(content: "hello, june")
        cfg3.animation.scriptId = "curved_arc_roller"
        let eval3Left = TextAnimationEvaluator.evaluate(config: cfg3, localTime: 1.2, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 1, charCount: 10)
        let eval3Right = TextAnimationEvaluator.evaluate(config: cfg3, localTime: 1.2, duration: 5.0, canvasSize: CGSize(width: 720, height: 720), charIndex: 8, charCount: 10)
        #expect(eval3Left.config.opacity > 0.0)
        #expect(eval3Left.config.positionY != eval3Right.config.positionY)
        #expect(abs(eval3Left.config.rotation) > 0.5 || abs(eval3Right.config.rotation) > 0.5)
    }

    @Test("Integer-cycle Loop & symmetric In=Out split, Auto/2-Bar Beat Sync, Text clip preservation, and Audio BPM compositor injection")
    func testIntegerLoopSymmetricEdgesAndTextBeatSync() {
        // 1. Odd timeline duration (5.47s) in free time scale -> exact integer cycles + symmetric R/2 edges
        let freeAnim = TextAnimationConfiguration(scriptId: "title_wave_float", scriptSpeed: 1.0)
        let freePhases = freeAnim.resolvedPhases(forClipDuration: 5.47, baseCycleSeconds: 1.0)
        #expect(freePhases.cycleCount == 4)
        #expect(abs(freePhases.loopDuration - 4.0) < 0.001)
        #expect(abs(freePhases.inDuration - 0.735) < 0.001)
        #expect(abs(freePhases.outDuration - 0.735) < 0.001)

        // 2. Beat Sync @ 128 BPM: 7.35s selects 1 Bar (3×1.875s = 5.625s); 8.80s upgrades cleanly to 2 Bars (2×3.75s = 7.50s)
        var beatAnim = TextAnimationConfiguration(scriptId: "title_wave_float", isBeatSyncEnabled: true, beatBPM: 128.0, beatBarMode: .auto)
        let barPhases735 = beatAnim.resolvedPhases(forClipDuration: 7.35, baseCycleSeconds: 1.0)
        #expect(barPhases735.cycleCount == 3)
        #expect(barPhases735.beatsPerCycle == 4)
        #expect(abs(barPhases735.loopDuration - 5.625) < 0.001)
        #expect(abs(barPhases735.inDuration - barPhases735.outDuration) < 0.0001)
        #expect(abs(barPhases735.inDuration - 0.8625) < 0.001)

        let barPhases880 = beatAnim.resolvedPhases(forClipDuration: 8.80, baseCycleSeconds: 1.0)
        #expect(barPhases880.cycleCount == 2)
        #expect(barPhases880.beatsPerCycle == 8)
        #expect(abs(barPhases880.loopDuration - 7.50) < 0.001)
        #expect(abs(barPhases880.inDuration - 0.65) < 0.001)
        #expect(abs(barPhases880.outDuration - 0.65) < 0.001)

        beatAnim.beatBarMode = .oneBeat
        let oneBeatPhases = beatAnim.resolvedPhases(forClipDuration: 3.0, baseCycleSeconds: 1.0)
        #expect(oneBeatPhases.beatsPerCycle == 1)
        #expect(oneBeatPhases.cycleLabel == "\(oneBeatPhases.cycleCount)×1 Beat")

        // 3. Committing TextConfiguration animation must NEVER overwrite Timeline clip length
        let customDur = CMTime(seconds: 7.35, preferredTimescale: 600)
        var initialCfg = TextConfiguration(content: "Preserve My Length")
        let textClip = TimelineClip(
            name: "Text",
            kind: .text,
            timeRange: CMTimeRange(start: .zero, duration: customDur),
            properties: ["textConfig": .string(initialCfg.encodeToJSON() ?? "")]
        )
        let textLayer = TimelineLayer(name: "Text 1", kind: .text, clips: [textClip])
        let timelineVM = TimelineViewModel(initialLayers: [textLayer])
        timelineVM.selectClip(textClip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        initialCfg.animation.scriptId = "title_wave_float"
        initialCfg.animation.updateTimingForSpeed(1.2, clipDuration: 7.35, baseCycleSeconds: 1.0)
        inspectorVM.updateTextConfiguration(initialCfg, commit: true)
        let afterDur = timelineVM.clip(by: textClip.id)?.timeRange.duration.seconds ?? 0.0
        #expect(abs(afterDur - 7.35) < 0.01)

        // 5. All Slide category scripts genuinely translate across full Preview canvas dimensions
        let slideScripts = TextAnimationScriptRegistry.shared.scripts(in: .slide)
        #expect(slideScripts.count == 8)
        let smallCanvas = CGSize(width: 640, height: 360)
        let largeCanvas = CGSize(width: 1920, height: 1080)
        for slideScript in slideScripts {
            var scfg = TextConfiguration(content: "Hello\nWorld")
            scfg.animation.scriptId = slideScript.id
            let evalSmall = TextAnimationEvaluator.evaluate(config: scfg, localTime: 0.0, duration: 5.0, canvasSize: smallCanvas)
            let evalLarge = TextAnimationEvaluator.evaluate(config: scfg, localTime: 0.0, duration: 5.0, canvasSize: largeCanvas)
            let magSmall = hypot(evalSmall.config.positionX, evalSmall.config.positionY)
            let magLarge = hypot(evalLarge.config.positionX, evalLarge.config.positionY)
            #expect(magSmall > 250.0, "Slide script \(slideScript.id) did not start off-screen on 640x360: \(magSmall)")
            #expect(magLarge > magSmall * 2.5, "Slide script \(slideScript.id) must scale travel with Preview canvasSize")
        }
        #expect(TextAnimationScriptRegistry.shared.script(for: "elastic_flip_3d")?.category == .threeD)
        #expect(TextAnimationScriptRegistry.shared.script(for: "pendulum_hinge_swing")?.category == .wave)
        #expect(TextAnimationScriptRegistry.shared.script(for: "curtain_baseline_rise")?.category == .fade)

        // 6. GPU shader & pure-motion scripts wire perspective3D, motionBlur, pixelate, liquidWave, slice displacement without altering colors
        let renderEngine = TextRendererEngine()
        let shaderProbeCases: [(String, Double)] = [
            ("three_d_tumble_drop", 0.25),
            ("three_d_swinging_door", 0.25),
            ("three_d_depth_rush", 0.25),
            ("slide_center_split", 0.45),
            ("fx_pixel_dissolve", 0.20),
            ("slide_directional_whip", 0.20),
            ("slide_zipper_cross", 0.25),
            ("wave_flag_flutter", 1.25),
            ("wave_liquid_ripple", 1.25),
            ("glitch_crt_slice_tear", 0.15)
        ]
        for (sid, probeT) in shaderProbeCases {
            var pcfg = TextConfiguration(content: "GPU FX")
            pcfg.animation.scriptId = sid
            let img = renderEngine.renderAnimatedImage(for: pcfg, localTime: probeT, duration: 5.0, canvasSize: smallCanvas)
            #expect(img != nil, "Failed rendering pure-motion script \(sid)")
        }
        var splitCfg = TextConfiguration(content: "SPLIT")
        splitCfg.animation.scriptId = "slide_center_split"
        #expect(TextAnimationEvaluator.evaluate(config: splitCfg, localTime: 0.4, duration: 5.0, canvasSize: smallCanvas).overlay.clipRevealX < 0.99)
        var pxCfg = TextConfiguration(content: "PIXEL")
        pxCfg.animation.scriptId = "fx_pixel_dissolve"
        #expect(TextAnimationEvaluator.evaluate(config: pxCfg, localTime: 0.2, duration: 5.0, canvasSize: smallCanvas).pixelateScale > 1.0)
        var perspCfg = TextConfiguration(content: "3D")
        perspCfg.animation.scriptId = "three_d_tumble_drop"
        #expect(abs(TextAnimationEvaluator.evaluate(config: perspCfg, localTime: 0.2, duration: 5.0, canvasSize: smallCanvas).overlay.perspectiveX) > 0.05)

        // 4. TimelineCompositionBuilder.makeTextRenderInfo injects detected Audio BPM (with audio clip speed) when Beat Sync is enabled
        let period128 = 60.0 / 128.0
        let beatMarkers = (0..<24).map { i in
            AudioBeatMarker(sourceTime: CMTime(seconds: Double(i) * period128, preferredTimescale: 600), kind: .major)
        }
        let audioBeatCfg = AudioBeatConfiguration(mode: .majorOnly, markers: beatMarkers, isVisible: false)
        var audioClip = TimelineClip(
            name: "BGM",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600)),
            properties: [
                AudioBeatConfiguration.propertyKey: .string(audioBeatCfg.encodeToJSON() ?? ""),
                "speed": .number(1.25)
            ]
        )
        audioClip.properties["volume"] = .number(1.0)
        let audioLayer = TimelineLayer(name: "Audio 1", kind: .audio, clips: [audioClip])

        var syncedTextCfg = TextConfiguration(content: "Beat Synced")
        syncedTextCfg.animation.scriptId = "title_wave_float"
        syncedTextCfg.animation.isBeatSyncEnabled = true
        syncedTextCfg.animation.beatBPM = 120.0
        let syncedTextClip = TimelineClip(
            name: "Synced Text",
            kind: .text,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)),
            properties: ["textConfig": .string(syncedTextCfg.encodeToJSON() ?? "")]
        )
        let syncedTextLayer = TimelineLayer(name: "Text 1", kind: .text, clips: [syncedTextClip])
        let renderInfo = TimelineCompositionBuilder.makeTextRenderInfo(
            layer: syncedTextLayer,
            range: syncedTextClip.timeRange,
            allLayers: [syncedTextLayer, audioLayer]
        )
        #expect(renderInfo?.textConfig?.animation.beatBPM == 160.0)
    }
}
