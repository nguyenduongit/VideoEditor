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
        #expect(vm.selectedSubTab == .default)
        #expect(vm.defaultPreset.id == "default")
        #expect(vm.defaultPreset.name == "Văn bản mặc định")
        #expect(vm.defaultPreset.config.content == "Văn bản")
        #expect(vm.templatePresets.count >= 8)

        let headline = vm.templatePresets.first { $0.id == "headline_bold" }
        #expect(headline != nil)
        #expect(headline?.config.isBold == true)

        let subtitle = vm.templatePresets.first { $0.id == "subtitle_box" }
        #expect(subtitle != nil)
        #expect(subtitle?.config.hasBackground == true)
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

        let size = TextRendererEngine.shared.measureSize(for: config, canvasSize: canvasSize)
        #expect(size.width > 50.0)
        #expect(size.height > 20.0)

        let ciImage = TextRendererEngine.shared.renderImage(for: config, canvasSize: canvasSize)
        #expect(ciImage != nil)
        #expect(ciImage?.extent.size == canvasSize)
    }

    @Test func testInspectorTabsForTextClip() {
        let tabs = ClipPropertyRegistry.shared.tabs(for: .text)
        #expect(tabs == ["Text", "Style", "Animation"])

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
        #expect(inspectorVM.availableTabs == ["Text", "Style", "Animation"])
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
        var headline = TextPreset.templates.first { $0.id == "headline_bold" }!.config
        headline.content = "TIÊU ĐỀ VIDEO ĐẸP"
        headline.positionY = -60

        var subtitle = TextPreset.templates.first { $0.id == "subtitle_box" }!.config
        subtitle.content = "Phụ đề mẫu chuẩn TikTok / YouTube"
        subtitle.positionY = 160

        guard let img1 = TextRendererEngine.shared.renderImage(for: headline, canvasSize: canvasSize),
              let img2 = TextRendererEngine.shared.renderImage(for: subtitle, canvasSize: canvasSize) else {
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
        #expect(swatches.count == 9)
        #expect(swatches.contains("#FDE047"))
        #expect(swatches.contains("#F97316"))
        #expect(swatches.contains("#06B6D4"))
        #expect(swatches.contains("#EF4444"))

        let neon = TextPreset.templates.first { $0.id == "neon_yellow" }
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
}
