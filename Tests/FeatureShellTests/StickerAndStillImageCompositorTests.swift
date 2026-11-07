import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@preconcurrency import AVFoundation
#if os(macOS)
import AppKit
#endif
import Domain
import Infrastructure
@testable import FeatureShell

@Suite("Sticker SVG/GIF Engine & Still Image Compositor Tests")
@MainActor
struct StickerAndStillImageCompositorTests {

    @Test("StickerPreset built-in SVG catalog encodes/decodes cleanly and renders crisp CIImage at 3x scale with Animation")
    func svgStickerSerializationAndCrispRendering() async throws {
        guard let starPreset = StickerPreset.builtInCatalog.first(where: { $0.id == "sticker_svg_star_badge" }) else {
            Issue.record("Missing sticker_svg_star_badge in builtInCatalog")
            return
        }
        #expect(starPreset.format == .svg)
        #expect(starPreset.config.svgMarkup?.contains("<svg") == true)

        var cfg = starPreset.config
        cfg.hasShadow = true
        cfg.blendMode = .screen
        cfg.animation.inType = .zoomIn
        cfg.animation.inDuration = 0.5

        guard let json = cfg.encodeToJSON(),
              let decoded = StickerConfiguration.decode(from: json) else {
            Issue.record("StickerConfiguration JSON roundtrip failed")
            return
        }
        #expect(decoded.format == .svg)
        #expect(decoded.blendMode == .screen)
        #expect(decoded.hasShadow == true)
        #expect(decoded.animation.inType == .zoomIn)

        let engine = StickerRendererEngine()
        let canvasSize = CGSize(width: 640, height: 360)
        let props: [String: PropertyValue] = [
            "scale": .number(3.0),
            "positionX": .number(40.0),
            "positionY": .number(-20.0),
            "rotation": .number(15.0),
            "opacity": .number(0.95)
        ]
        let rendered = engine.renderStickerImage(
            config: decoded,
            clipProperties: props,
            localTime: 1.0,
            duration: 3.0,
            canvasSize: canvasSize
        )
        #expect(rendered != nil)
        #expect(rendered?.extent == CGRect(origin: .zero, size: canvasSize))

        let loader = StickerTemplateLoader()
        let repo = SupabaseStickerPresetRepository(client: nil, templateLoader: loader)
        let customPreset = StickerPreset(
            id: "custom_svg_pill",
            name: "Custom SVG Pill",
            description: "Inline SVG stored in Supabase JSON",
            category: .badge,
            format: .svg,
            config: decoded,
            isSystem: false
        )
        try await repo.savePreset(customPreset)
        let fetched = try await repo.fetchPresets()
        #expect(fetched.contains(where: { $0.id == "custom_svg_pill" }))
        #expect(fetched.contains(where: { $0.id == "sticker_svg_star_badge" }))
    }

    @Test("InspectorViewModel updates Sticker Flip H/V strictly as .bool and bridges Animation tab")
    func stickerFlipBoolInvariantAndAnimationBridge() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let preset = StickerPreset.builtInCatalog[0]
        timelineVM.addStickerPreset(preset)

        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()
        #expect(inspectorVM.availableTabs == ["Sticker", "Animation"])

        var sCfg = inspectorVM.stickerConfiguration
        sCfg.flipHorizontal = true
        sCfg.flipVertical = true
        inspectorVM.updateStickerConfiguration(sCfg, commit: true)

        guard let clip = inspectorVM.selectedClip else {
            Issue.record("Expected selected sticker clip")
            return
        }
        // Must strictly remain .bool(true), never overwritten by .string("true")
        #expect(clip.properties["flipHorizontal"] == .bool(true))
        #expect(clip.properties["flipVertical"] == .bool(true))
        #expect(inspectorVM.stickerConfiguration.flipHorizontal == true)
        #expect(inspectorVM.stickerConfiguration.flipVertical == true)

        // Animation tab bridge updates stickerConfig.animation without touching text properties
        var animCarrier = inspectorVM.textConfiguration
        animCarrier.animation.loopType = .pulse
        inspectorVM.updateTextConfiguration(animCarrier, commit: true)
        #expect(inspectorVM.stickerConfiguration.animation.loopType == .pulse)
    }

    @Test("Non-video visual timeline (.image + .sticker) builds carrier video track and custom compositor instructions")
    func stillImageAndStickerTimelineBuildsValidComposition() async throws {
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_still_\(UUID().uuidString).png")
        defer {
            do { try FileManager.default.removeItem(at: tmpURL) } catch { _ = error }
        }

        #if os(macOS)
        let img = NSImage(size: NSSize(width: 160, height: 90))
        img.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 160, height: 90))
        img.unlockFocus()
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try png.write(to: tmpURL)
        }
        #endif

        let imageClip = TimelineClip(
            name: "Photo",
            kind: .image,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)),
            mediaURL: tmpURL,
            properties: ["scale": .number(1.2), "opacity": .number(0.9)]
        )
        let stickerPreset = StickerPreset.builtInCatalog[0]
        let stickerClip = TimelineClip(
            name: stickerPreset.name,
            kind: .sticker,
            timeRange: CMTimeRange(start: CMTime(seconds: 1.0, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)),
            properties: ["stickerConfig": .string(stickerPreset.config.encodeToJSON() ?? ""), "scale": .number(1.5)]
        )

        let stickerLayer = TimelineLayer(name: "Sticker 1", kind: .sticker, clips: [stickerClip])
        let imageLayer = TimelineLayer(name: "Image 1", kind: .image, clips: [imageClip])
        let layers = [stickerLayer, imageLayer]

        #expect(TimelineCompositionBuilder.hasActiveMask(in: layers) == true)

        let composition = AVMutableComposition()
        _ = await TimelineCompositionBuilder.buildTracks(for: composition, from: layers, aspectRatio: .ratio16x9)
        // Carrier track must span up to 5.0s (end of stickerClip)
        #expect(abs(CMTimeGetSeconds(composition.duration) - 5.0) < 0.1)

        let videoComp = try #require(TimelineCompositionBuilder.buildVideoComposition(
            for: layers,
            composition: composition,
            layerTrackIDs: [:],
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        ))
        let instAtMid = try #require(videoComp.instructions.compactMap { $0 as? TimelineCustomVideoCompositionInstruction }.first {
            $0.timeRange.containsTime(CMTime(seconds: 2.0, preferredTimescale: 600))
        })
        #expect(instAtMid.layerInfos.contains(where: { $0.isSticker }))
        #expect(instAtMid.layerInfos.contains(where: { $0.isStillImage && $0.stillImageURL == tmpURL }))

        let stickerGeom = ClipCanvasGeometry.compute(for: stickerClip, canvasSize: CGSize(width: 1920, height: 1080))
        #expect(stickerGeom.size.width > 300.0)
    }
}
