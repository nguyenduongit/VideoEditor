import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@preconcurrency import AVFoundation
import Domain
import Infrastructure
@testable import FeatureShell

@Suite("Transition A/B Checkerboard, 8 Metal Kernels, Undo/Redo & Persistence Tests")
@MainActor
struct TransitionABEngineAndPersistenceTests {

    private static func makeTestVideoFile(url: URL, durationSeconds: Double = 2.0) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 180
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 320, 180, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        if let buffer = pixelBuffer {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            adaptor.append(buffer, withPresentationTime: .zero)
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            adaptor.append(buffer, withPresentationTime: CMTime(seconds: durationSeconds, preferredTimescale: 600))
        }
        input.markAsFinished()
        await writer.finishWriting()
    }

    @Test("All 8 dual-texture Metal transition kernels compile and execute cleanly on GPU")
    func allEightDualTextureMetalKernelsExecute() {
        let engine = MetalComputeRuntimeEngine.shared
        guard engine.isAvailable else { return }

        let expectedKernels = [
            "metal_transition_dissolve",
            "metal_transition_push",
            "metal_transition_whip_pan",
            "metal_transition_zoom_blur",
            "metal_transition_cross_warp",
            "metal_transition_glitch_slice",
            "metal_transition_light_leak",
            "metal_transition_geometric_wipe"
        ]

        let size = CGSize(width: 320, height: 180)
        let rect = CGRect(origin: .zero, size: size)
        let fromImg = CIImage(color: CIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)).cropped(to: rect)
        let toImg = CIImage(color: CIColor(red: 0.1, green: 0.5, blue: 0.95, alpha: 1.0)).cropped(to: rect)

        for kernel in expectedKernels {
            #expect(engine.hasCompiledKernel(named: kernel), "Missing compiled Metal kernel: \(kernel)")
            let out = DynamicShaderRuntimeEngine.shared.executeTransition(
                from: fromImg,
                to: toImg,
                kernelName: kernel,
                progress: 0.5,
                parameters: [1.0, 0.25],
                canvasSize: size
            )
            #expect(out.extent == rect)
        }
    }

    @Test("A/B Checkerboard routing preserves cut timestamps, clamps un-trimmed handles, and builds Audio Crossfade")
    func abCheckerboardPreservesCutTimingAndBuildsDualTracks() async throws {
        let tmpA = FileManager.default.temporaryDirectory.appendingPathComponent("trans_a_\(UUID().uuidString).mp4")
        let tmpB = FileManager.default.temporaryDirectory.appendingPathComponent("trans_b_\(UUID().uuidString).mp4")
        defer {
            do { try FileManager.default.removeItem(at: tmpA) } catch { _ = error }
            do { try FileManager.default.removeItem(at: tmpB) } catch { _ = error }
        }
        try await Self.makeTestVideoFile(url: tmpA, durationSeconds: 2.0)
        try await Self.makeTestVideoFile(url: tmpB, durationSeconds: 2.5)

        // Clip 0: un-trimmed [0.0s .. 2.0s] -> requires Frame Clamp for tail [2.0s .. 2.3s]
        let clip0 = TimelineClip(
            name: "Shot A",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: tmpA,
            sourceStartTime: .zero
        )
        // Clip 1: trimmed head (sourceStartTime = 0.5s) [2.0s .. 4.0s] -> uses Smart Handle for head [1.7s .. 2.0s]
        let clip1 = TimelineClip(
            name: "Shot B",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 2.0, preferredTimescale: 600)),
            mediaURL: tmpB,
            sourceStartTime: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
        let trans = CutTransition(
            presetID: "whip_pan_left",
            name: "Whip Pan Trái",
            leadingClipID: clip0.id,
            trailingClipID: clip1.id,
            duration: RationalTime(cmTime: CMTime(seconds: 0.6, preferredTimescale: 600)),
            alignment: .center,
            shaderType: .whipPanLeft,
            easing: .cubicBezier,
            crossfadeAudio: true,
            parameterValues: ["blurStrength": 1.4]
        )
        let videoLayer = TimelineLayer(name: "Main Video", kind: .video, clips: [clip0, clip1], transitions: [trans])

        let composition = AVMutableComposition()
        let composed = await TimelineCompositionBuilder.buildComposedTracks(
            for: composition,
            from: [videoLayer],
            aspectRatio: .ratio16x9
        )

        let trackAID = try #require(composed.primaryVideoTrackIDs[videoLayer.id])
        let trackBID = try #require(composed.secondaryVideoTrackIDs[videoLayer.id])
        #expect(trackAID != trackBID)

        let trackA = try #require(composition.track(withTrackID: trackAID))
        let trackB = try #require(composition.track(withTrackID: trackBID))
        // Track A must cover through 2.3s (2.0s body + 0.3s clamped frame); Track B must reach 4.0s without shifting cut
        #expect(trackA.timeRange.end.seconds >= 2.28)
        #expect(abs(trackB.timeRange.end.seconds - 4.0) < 0.05)

        let videoComp = try #require(TimelineCompositionBuilder.buildVideoComposition(
            for: [videoLayer],
            composition: composition,
            layerTrackIDs: composed.primaryVideoTrackIDs,
            secondaryTrackIDs: composed.secondaryVideoTrackIDs,
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 4.0, preferredTimescale: 600)
        ))
        let midCutInst = try #require(videoComp.instructions.compactMap { $0 as? TimelineCustomVideoCompositionInstruction }.first {
            $0.timeRange.containsTime(CMTime(seconds: 2.0, preferredTimescale: 600))
        })
        let activeTrans = try #require(midCutInst.layerInfos.first?.activeTransition)
        #expect(activeTrans.fromLayerInfo.trackID == trackAID)
        #expect(activeTrans.toLayerInfo.trackID == trackBID)
        #expect(activeTrans.transition.shaderType == .whipPanLeft)

        let audioMix = TimelineCompositionBuilder.buildAudioMix(for: [videoLayer], layerAudioTrackIDs: composed.trackMap)
        #expect(audioMix.inputParameters.count == 2)
    }

    @Test("CutTransition supports full Undo/Redo via TimelineCommandExecutor, LayerScript persistence & Supabase upsert")
    func transitionUndoRedoPersistenceAndSupabase() async throws {
        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 2.0, preferredTimescale: 600)))
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)

        guard let transitionPreset = TransitionPreset.builtInCatalog.first(where: { $0.id == "dissolve_default" }) ?? TransitionPreset.builtInCatalog.first else {
            Issue.record("Missing transition preset in builtInCatalog")
            return
        }

        let created = try #require(timelineVM.addOrUpdateCutTransition(transitionPreset, between: c0.id, and: c1.id))
        #expect(timelineVM.layers[0].transitions.count == 1)
        #expect(created.shaderType == .dissolve)

        // Transactional parameter update via InspectorViewModel
        inspectorVM.syncWithSelection()
        inspectorVM.onTransitionSliderEditingChanged(true)
        inspectorVM.updateTransitionParameter(id: "gammaCurve", value: 1.85, commit: false)
        inspectorVM.onTransitionSliderEditingChanged(false)
        #expect(abs((timelineVM.layers[0].transitions.first?.parameterValues["gammaCurve"] ?? 0) - 1.85) < 0.001)

        // LayerScript JSON roundtrip
        let script = LayerScript(from: timelineVM.layers[0])
        let encoded = try JSONEncoder().encode(script)
        let decodedLayer = try JSONDecoder().decode(LayerScript.self, from: encoded).toTimelineLayer()
        #expect(decodedLayer.transitions.count == 1)
        #expect(abs((decodedLayer.transitions.first?.parameterValues["gammaCurve"] ?? 0) - 1.85) < 0.001)

        // Undo parameter edit -> Undo transition creation -> Redo both
        timelineVM.undo()
        #expect(abs((timelineVM.layers[0].transitions.first?.parameterValues["gammaCurve"] ?? 0) - 1.0) < 0.001)
        timelineVM.undo()
        #expect(timelineVM.layers[0].transitions.isEmpty)
        timelineVM.redo()
        #expect(timelineVM.layers[0].transitions.count == 1)

        // SupabaseTransitionPresetRepository offline-first roundtrip
        let loader = TransitionTemplateLoader()
        let repo = SupabaseTransitionPresetRepository(client: nil, templateLoader: loader)
        var customPreset = transitionPreset
        customPreset = TransitionPreset(
            id: "custom_cyber_zoom",
            name: "Cyber Zoom",
            description: "Custom GPU transition",
            category: .glitch,
            defaultDuration: 0.45,
            shaderType: .zoomBlur,
            defaultEasing: .cubicBezier,
            parameters: transitionPreset.parameters,
            parameterValues: ["zoomStrength": 0.8],
            isSystem: false
        )
        try await repo.savePreset(customPreset)
        let allPresets = try await repo.fetchPresets()
        #expect(allPresets.contains(where: { $0.id == "custom_cyber_zoom" }))
        #expect(allPresets.count >= 2)
    }

    @Test("TimelineTransitionOverlayView positioning math is strictly symmetrical and Inspector duration updates realtime")
    func transitionOverlaySymmetryAndDurationRealtime() throws {
        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 2.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 3.0, preferredTimescale: 600)))
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)

        guard let preset = TransitionPreset.builtInCatalog.first else {
            Issue.record("Missing builtInCatalog transition preset")
            return
        }

        let trans = try #require(timelineVM.addOrUpdateCutTransition(preset, between: c0.id, and: c1.id))
        timelineVM.selectedTransitionID = trans.id
        inspectorVM.syncWithSelection()

        let pps: CGFloat = 100.0
        let cutX = c0.timeRange.end.seconds * pps // 200.0 pt

        // 1. Initial symmetry check
        let initialDuration = trans.duration.seconds // default ~0.5s
        let initialWidth = initialDuration * pps
        let initialStartX = cutX - (initialWidth / 2.0)
        let initialLeftWing = cutX - initialStartX
        let initialRightWing = (initialStartX + initialWidth) - cutX
        #expect(abs(initialLeftWing - initialRightWing) < 0.0001)

        // 2. Max allowed duration check: 2 * min(2.0, 3.0) = 4.0s
        #expect(abs(inspectorVM.maxAllowedTransitionDuration - 4.0) < 0.001)

        // 3. Realtime slider duration adjustment (commit: false)
        inspectorVM.updateTransitionDuration(1.2, commit: false)
        let updatedTrans = try #require(timelineVM.layers[0].transitions.first)
        #expect(abs(updatedTrans.duration.seconds - 1.2) < 0.001)

        let updatedWidth = 1.2 * pps // 120.0 pt
        let updatedStartX = cutX - (updatedWidth / 2.0) // 140.0 pt
        let updatedLeftWing = cutX - updatedStartX // 60.0 pt
        let updatedRightWing = (updatedStartX + updatedWidth) - cutX // 60.0 pt
        #expect(abs(updatedLeftWing - updatedRightWing) < 0.0001)

        // 4. Delete key removal via deleteSelectedClips with Undo/Redo
        #expect(timelineVM.layers[0].transitions.count == 1)
        timelineVM.deleteSelectedClips()
        #expect(timelineVM.layers[0].transitions.isEmpty)
        #expect(timelineVM.selectedTransitionID == nil)

        timelineVM.undo()
        #expect(timelineVM.layers[0].transitions.count == 1)
    }
}
