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

    @Test("StickerLibraryItem built-in SVG catalog encodes/decodes cleanly and renders crisp CIImage at 3x scale with Animation")
    func svgStickerSerializationAndCrispRendering() async throws {
        guard let flowerItem = StickerLibraryItem.systemItems.first(where: { $0.id == "sticker_animated_flower_leaf" }) else {
            Issue.record("Missing sticker_animated_flower_leaf in systemItems")
            return
        }
        #expect(flowerItem.format == .svg)
        #expect(flowerItem.config.svgMarkup?.contains("<svg") == true)

        var cfg = flowerItem.config
        cfg.hasShadow = true
        cfg.blendMode = .screen
        cfg.animation.scriptId = "bounce_heartbeat"
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3.0, speed: 1.5)
        cfg.animation.isBeatSyncEnabled = true
        cfg.animation.beatBPM = 128.0

        guard let json = cfg.encodeToJSON(),
              let decoded = StickerConfiguration.decode(from: json) else {
            Issue.record("StickerConfiguration JSON roundtrip failed")
            return
        }
        #expect(decoded.format == .svg)
        #expect(decoded.blendMode == .screen)
        #expect(decoded.hasShadow == true)
        #expect(decoded.animation.scriptId == "bounce_heartbeat")
        #expect(decoded.animation.scriptSpeed == 1.5)
        #expect(decoded.animation.isBeatSyncEnabled == true)
        #expect(decoded.animation.beatBPM == 128.0)

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

        var animProps = props
        animProps["originPresetId"] = .string("sticker_animated_flower_leaf")
        let frameA = engine.renderStickerImage(config: flowerItem.config, clipProperties: animProps, localTime: 0.0, duration: 5.0, canvasSize: canvasSize)
        let frameB = engine.renderStickerImage(config: flowerItem.config, clipProperties: animProps, localTime: 1.5, duration: 5.0, canvasSize: canvasSize)
        #expect(frameA != nil)
        #expect(frameB != nil)

        let library = StickerLibrary()
        let items = library.loadAllItems()
        #expect(items.contains(where: { $0.id == "sticker_animated_flower_leaf" }))
        #expect(items.contains(where: { $0.id == "sticker_animated_xmas_tree" }))

        if let xmasItem = StickerLibraryItem.systemItems.first(where: { $0.id == "sticker_animated_xmas_tree" }) {
            #expect(xmasItem.config.svgMarkup?.contains("viewBox=\"0 0 500 500\"") == true)
            #expect(xmasItem.defaultDuration == 3.0)
            #expect(flowerItem.defaultDuration == 3.0)
            var xmasProps = props
            xmasProps["originPresetId"] = .string("sticker_animated_xmas_tree")
            let xmasFrame = engine.renderStickerImage(config: xmasItem.config, clipProperties: xmasProps, localTime: 1.0, duration: 3.0, canvasSize: canvasSize)
            #expect(xmasFrame != nil)

            // Verify 3.0s @ 60fps seamless loop wrap-around at t=0.0s and t=3.0s
            let f0 = TextSVGAndAssetCache.shared.frameForAsset(path: "sticker_animated_flower_leaf.apng", localTime: 0.0, loop: true, speed: 1.0)
            let fMid = TextSVGAndAssetCache.shared.frameForAsset(path: "sticker_animated_flower_leaf.apng", localTime: 1.5, loop: true, speed: 1.0)
            let fWrap = TextSVGAndAssetCache.shared.frameForAsset(path: "sticker_animated_flower_leaf.apng", localTime: 3.0, loop: true, speed: 1.0)
            if let f0, let fMid, let fWrap {
                #expect(f0 === fWrap)
                #expect(f0 !== fMid)
            }
        }

        // Verify 36 Apple Emoji System Items and category restructuring
        #expect(StickerLibraryItem.emojiItems.count == 36)
        #expect(StickerLibraryItem.systemItems.count >= 38)
        #expect(flowerItem.category == .natureHoliday)
        if let grin = StickerLibraryItem.systemItems.first(where: { $0.id == "sticker_emoji_grinning" }) {
            #expect(grin.category == .emoji)
            #expect(grin.format == .svg)
            #expect(grin.config.svgMarkup?.contains("Apple Color Emoji") == true)
            let grinRendered = engine.renderStickerImage(
                config: grin.config,
                clipProperties: props,
                localTime: 0.0,
                duration: 3.0,
                canvasSize: canvasSize
            )
            #expect(grinRendered != nil)
        }
    }

    @Test("InspectorViewModel updates Sticker Flip H/V strictly as .bool and bridges Animation tab")
    func stickerFlipBoolInvariantAndAnimationBridge() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        let stickerItem = StickerLibraryItem.systemItems[0]
        timelineVM.addStickerItem(stickerItem)

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

        // Test continuous Script-Driven sticker animations across all 6 categories without touching GIF/APNG playbackSpeed
        let allScripts = StickerAnimationScriptRegistry.shared.allScripts
        #expect(allScripts.count == 24)
        for category in StickerAnimationCategory.allCases {
            #expect(StickerAnimationScriptRegistry.shared.scripts(in: category).count == 4)
        }

        let engine = StickerRendererEngine()
        for script in allScripts {
            var updated = inspectorVM.stickerConfiguration
            updated.playbackSpeed = 1.75
            updated.animation.scriptId = script.id
            updated.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3.0, speed: 1.5)
            updated.animation.isBeatSyncEnabled = true
            updated.animation.beatBPM = 140.0
            inspectorVM.updateStickerConfiguration(updated, commit: true)
            #expect(inspectorVM.stickerConfiguration.animation.scriptId == script.id)
            #expect(inspectorVM.stickerConfiguration.animation.scriptSpeed == 1.5)
            #expect(inspectorVM.stickerConfiguration.playbackSpeed == 1.75)

            let eval = StickerAnimationEvaluator.evaluate(
                animation: updated.animation,
                localTime: 0.9,
                clipDuration: updated.animation.scriptDuration,
                baseStickerSize: CGSize(width: 140, height: 140),
                positionX: 0.0,
                positionY: 0.0,
                scale: 1.0,
                rotation: 0.0,
                opacity: 1.0
            )
            #expect(!eval.scaleX.isNaN)
            #expect(!eval.scaleY.isNaN)
            #expect(!eval.rotation.isNaN)
            #expect(!eval.skewX.isNaN)
            #expect(!eval.opacity.isNaN)
            #expect(!eval.positionX.isNaN)
            #expect(!eval.positionY.isNaN)

            let rendered = engine.renderStickerImage(
                config: updated,
                clipProperties: [:],
                localTime: 0.9,
                duration: updated.animation.scriptDuration,
                canvasSize: CGSize(width: 320, height: 180)
            )
            #expect(rendered != nil)
        }

        // Verify phase seam continuity (Intro end == Loop start == Loop end == Outro start)
        if let bounceScript = StickerAnimationScriptRegistry.shared.script(for: "bounce_drop") {
            let introEnd = bounceScript.evaluate(localTime: 0.6, clipDuration: 4.2, speed: 1.0, isBeatSyncEnabled: false, beatBPM: 120.0)
            let loopStart = bounceScript.evaluatePhase(.loop(elapsed: 0.0, loopDuration: 3.0, cycles: 3), speed: 1.0, isBeatSyncEnabled: false, beatBPM: 120.0)
            let loopEnd = bounceScript.evaluatePhase(.loop(elapsed: 3.0, loopDuration: 3.0, cycles: 3), speed: 1.0, isBeatSyncEnabled: false, beatBPM: 120.0)
            #expect(abs(introEnd.offsetY - loopStart.offsetY) < 0.001)
            #expect(abs(loopStart.offsetY - loopEnd.offsetY) < 0.001)
            #expect(abs(loopStart.scaleX - loopEnd.scaleX) < 0.001)
        }

        // Verify backward-compatible JSON decode from legacy loopType & loopSpeed
        let legacyJSON = #"{"scriptId":"","loopType":"Nhịp tim","loopSpeed":2.0}"#
        if let data = legacyJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(StickerAnimationConfiguration.self, from: data) {
            #expect(decoded.scriptId == "bounce_heartbeat")
            #expect(decoded.scriptSpeed == 2.0)
            #expect(decoded.hasScriptAnimation == true)
        } else {
            Issue.record("Failed decoding legacy StickerAnimationConfiguration JSON")
        }

        // Verify integer-cycle phase durations adapt dynamically with symmetric R/2 split (In = Out = R/2)
        let shortPhases = StickerAnimationConfiguration(scriptId: "pop_elastic", scriptSpeed: 1.0)
            .resolvedPhases(forClipDuration: 3.0)
        #expect(shortPhases.cycleCount == 2)
        #expect(abs(shortPhases.inDuration - 0.5) < 0.01)
        #expect(abs(shortPhases.loopDuration - 2.0) < 0.01)
        #expect(abs(shortPhases.outDuration - 0.5) < 0.01)

        let oddPhases = StickerAnimationConfiguration(scriptId: "swing_pendulum", scriptSpeed: 1.0)
            .resolvedPhases(forClipDuration: 5.47)
        #expect(oddPhases.cycleCount == 4)
        #expect(abs(oddPhases.loopDuration - 4.0) < 0.01)
        #expect(abs(oddPhases.inDuration - 0.735) < 0.001)
        #expect(abs(oddPhases.outDuration - 0.735) < 0.001)

        // Musical Bar alignment at 120 BPM (1 Bar = 2.0s)
        let barPhases = StickerAnimationConfiguration(
            scriptId: "swing_pendulum",
            scriptSpeed: 1.0,
            isBeatSyncEnabled: true,
            beatBPM: 120.0,
            beatBarMode: .oneBar
        ).resolvedPhases(forClipDuration: 5.5)
        #expect(barPhases.cycleCount == 2)
        #expect(barPhases.beatsPerCycle == 4)
        #expect(abs(barPhases.loopDuration - 4.0) < 0.01)
        #expect(abs(barPhases.inDuration - 0.75) < 0.01)
        #expect(abs(barPhases.outDuration - 0.75) < 0.01)
        #expect(barPhases.cycleLabel == "2×1 Bar")

        let longPhases = StickerAnimationConfiguration(scriptId: "pop_elastic", scriptSpeed: 1.0)
            .resolvedPhases(forClipDuration: 12.0)
        #expect(longPhases.cycleCount == 11)
        #expect(abs(longPhases.loopDuration - 11.0) < 0.01)
        #expect(abs(longPhases.inDuration - 0.5) < 0.01)
        #expect(abs(longPhases.totalDuration - 12.0) < 0.01)

        // Updating Sticker animation must NEVER overwrite Timeline clip length
        let originalDur = timelineVM.clip(by: clip.id)?.timeRange.duration.seconds ?? 0.0
        var extendedCfg = inspectorVM.stickerConfiguration
        extendedCfg.animation.scriptId = "swing_pendulum"
        extendedCfg.animation.updateTimingForSpeed(1.5, clipDuration: 18.0)
        inspectorVM.updateStickerConfiguration(extendedCfg, commit: true)
        #expect(abs((timelineVM.clip(by: clip.id)?.timeRange.duration.seconds ?? 0.0) - originalDur) < 0.001)

        // AudioTempoResolver resolves exact BPM (with clip playback speed) from overlapping audio track
        let period128 = 60.0 / 128.0
        let beatMarkers = (0..<20).map { i in
            AudioBeatMarker(sourceTime: CMTime(seconds: Double(i) * period128, preferredTimescale: 600), kind: .major)
        }
        let beatConfig = AudioBeatConfiguration(mode: .majorOnly, markers: beatMarkers, isVisible: false)
        var audioClip = TimelineClip(
            name: "EDM Track",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600)),
            properties: [
                AudioBeatConfiguration.propertyKey: .string(beatConfig.encodeToJSON() ?? ""),
                "speed": .number(1.25)
            ]
        )
        audioClip.properties["volume"] = .number(1.0)
        let audioLayer = TimelineLayer(name: "Audio 1", kind: .audio, clips: [audioClip])
        let stickerRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 3.0, preferredTimescale: 600))
        let tempo = AudioTempoResolver.resolveTempo(overlapping: stickerRange, in: [audioLayer])
        #expect(tempo.hasAudioUnderneath == true)
        #expect(tempo.bpm == 160.0) // 128 BPM * 1.25x speed = 160 BPM

        // TimelineCompositionBuilder injects overlapping audio BPM into Beat Sync Sticker RenderInfo
        var syncedCfg = StickerConfiguration(systemSymbolFallback: "star.fill")
        syncedCfg.animation.scriptId = "bounce_heartbeat"
        syncedCfg.animation.isBeatSyncEnabled = true
        syncedCfg.animation.beatBPM = 120.0
        let beatStickerClip = TimelineClip(
            name: "Synced Sticker",
            kind: .sticker,
            timeRange: stickerRange,
            properties: ["stickerConfig": .string(syncedCfg.encodeToJSON() ?? "")]
        )
        let stickerLayer = TimelineLayer(name: "Sticker 1", kind: .sticker, clips: [beatStickerClip])
        let renderInfo = TimelineCompositionBuilder.makeStickerRenderInfo(
            layer: stickerLayer,
            range: stickerRange,
            allLayers: [stickerLayer, audioLayer]
        )
        #expect(renderInfo?.stickerConfig?.animation.beatBPM == 160.0)

        // Verify thumbnail renderer outputs valid non-empty NSImage
        let thumb = StickerThumbnailRenderer.renderThumbnail(
            for: allScripts.first,
            sourceConfig: inspectorVM.stickerConfiguration,
            time: 0.4
        )
        #expect(thumb.size.width > 0 && thumb.size.height > 0)
    }

    @Test("Audio-Reactive Audiogram Stickers catalog, FFT spectral extraction, sampler reactivity, and 8-style rendering")
    func audiogramStickersCatalogDSPAndRendering() {
        let audioItems = StickerLibraryItem.audioVisualizerItems
        #expect(audioItems.count == 8)
        #expect(audioItems.allSatisfy { $0.category == .audioVisualizer && $0.format == .audiogram })
        #expect(StickerCategory.assignableCases.contains(.audioVisualizer))

        // JSON serialization roundtrip with custom audiogram settings
        if let first = audioItems.first,
           let json = first.config.encodeToJSON(),
           let decoded = StickerConfiguration.decode(from: json) {
            #expect(decoded.format == .audiogram)
            #expect(decoded.audiogram?.style == first.config.audiogram?.style)
            #expect(decoded.audiogram?.isGlowEnabled == true)
        } else {
            Issue.record("Audiogram StickerConfiguration roundtrip failed")
        }

        // DSP FFT spectrum analysis distinguishes loud low-frequency kick vs silence
        let sampleRate = 22050.0
        var pcm = [Float](repeating: 0.0, count: Int(sampleRate * 2.0))
        for idx in 0..<Int(sampleRate * 1.0) {
            let t = Double(idx) / sampleRate
            pcm[idx] = Float(0.8 * sin(2.0 * .pi * 90.0 * t))
        }
        let service = AudioReactiveAnalysisService()
        guard let profile = service.computeProfile(samples: pcm, sampleRate: sampleRate) else {
            Issue.record("AudioReactiveAnalysisService failed to compute profile from valid PCM")
            return
        }
        let loudSample = profile.sample(atSourceSeconds: 0.45)
        let quietSample = profile.sample(atSourceSeconds: 1.75)
        #expect(loudSample.overallLevel > quietSample.overallLevel + 0.2)
        #expect(loudSample.bands.count == 16)

        // Sampler reactivity combines track profile + beat impulse
        let trackSnapshot = AudioReactiveTrackSnapshot(
            clipName: "Bass Track",
            timelineStart: 0.0,
            timelineDuration: 4.0,
            sourceStart: 0.0,
            speed: 1.0,
            volume: 1.0,
            beatTimesSeconds: [0.40],
            detectedBPM: 128.0,
            profile: profile
        )
        let atBeatFrame = AudioReactiveSampler.sample(atTimelineTime: 0.43, tracks: [trackSnapshot], bandCount: 20, sensitivity: 1.2)
        let idleFrame = AudioReactiveSampler.sample(atTimelineTime: 1.75, tracks: [trackSnapshot], bandCount: 20, sensitivity: 1.2)
        #expect(atBeatFrame.isSyncedToAudio == true)
        #expect(atBeatFrame.beatImpulse > 0.5)
        #expect(atBeatFrame.bassLevel > idleFrame.bassLevel)

        // All 8 audiogram styles render non-empty CIImage cleanly across composition engine
        let engine = StickerRendererEngine()
        for style in StickerAudiogramStyle.allCases {
            var cfg = StickerConfiguration(
                format: .audiogram,
                systemSymbolFallback: style.symbolName,
                audiogram: StickerAudiogramConfiguration(style: style)
            )
            cfg.animation.scriptId = "pop_elastic"
            let rendered = engine.renderStickerImage(
                config: cfg,
                clipProperties: [:],
                localTime: 0.45,
                duration: 3.0,
                canvasSize: CGSize(width: 640, height: 360),
                compTime: 0.43,
                audioTracks: [trackSnapshot]
            )
            #expect(rendered != nil)
        }
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
        let stickerItem = StickerLibraryItem.systemItems[0]
        let stickerClip = TimelineClip(
            name: stickerItem.name,
            kind: .sticker,
            timeRange: CMTimeRange(start: CMTime(seconds: 1.0, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)),
            properties: ["stickerConfig": .string(stickerItem.config.encodeToJSON() ?? ""), "scale": .number(1.5)]
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
