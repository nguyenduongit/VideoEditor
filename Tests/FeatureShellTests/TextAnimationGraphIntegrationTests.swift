import Foundation
import CoreGraphics
import CoreImage
import Testing
@testable import Domain
@testable import FeatureShell

private struct TestBloomTintPlugin: TextAnimationRenderPlugin {
    let id = "test.tint.plugin"
    let requiredChannels: Set<String> = ["custom.tint.strength"]

    func apply(
        to image: CIImage,
        parameters: TextAnimationParameterBag,
        context: TextAnimationRenderPluginContext
    ) -> CIImage {
        let strength = CGFloat(min(1.0, max(0.0, parameters["custom.tint.strength"] ?? 0.0)))
        guard strength > 0.01, context.canvasSize.width > 1 else { return image }
        let green = CIImage(color: CIColor(red: 0.1, green: 1.0, blue: 0.35, alpha: strength)).cropped(to: image.extent)
        return CIFilter(name: "CISourceAtopCompositing", parameters: [
            kCIInputImageKey: green,
            kCIInputBackgroundImageKey: image
        ])?.outputImage?.cropped(to: image.extent) ?? image
    }
}

@Suite("Text Animation Graph Engine Integration")
struct TextAnimationGraphIntegrationTests {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let canvasSize = CGSize(width: 640, height: 360)

    @Test("GraphMapper propagates echo count defaults, bevel depth, cursor, anchor, and mask shape")
    func testCompleteGraphChannelMapping() {
        let graph = TextAnimationGraph(
            id: "full-map",
            name: "Full Map",
            tracks: [
                TextAnimationTrack(channel: TextAnimationChannel.echoOffsetX, signal: .constant(0.12)),
                TextAnimationTrack(channel: TextAnimationChannel.trailingCursorOpacity, signal: .constant(0.85)),
                TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(6.0))
            ],
            staticStringChannels: [
                TextAnimationChannel.maskShape: TextMaskShapeMode.diagonalSlash.rawValue,
                TextAnimationChannel.anchor: TextAnchorPoint.bottom.rawValue
            ]
        )
        let config = TextConfiguration(
            content: "GRAPH",
            fontSize: 56,
            animation: TextAnimationConfiguration(graph: graph)
        )
        let evaluated = TextAnimationEvaluator.evaluate(
            config: config, localTime: 2.0, duration: 5.0, canvasSize: canvasSize
        )
        #expect(evaluated.overlay.echoCount == 3)
        #expect(abs(evaluated.overlay.echoOffsetXEm - 0.12) < 0.001)
        #expect(abs(evaluated.overlay.trailingCursorOpacity - 0.85) < 0.001)
        #expect(abs(evaluated.overlay.bevelDepth - 6.0) < 0.001)
        #expect(evaluated.overlay.maskShapeMode == .diagonalSlash)
        #expect(evaluated.config.animation.anchorPoint == .bottom)
    }

    @Test("Graph loop phase transitions continuously across cycle seams without freezing")
    func testGraphLoopContinuityAndStaggerWave() {
        let graph = TextAnimationGraph(
            id: "wave-continuous",
            name: "Wave Continuous",
            scope: .perCharacter,
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.positionY,
                    phase: .loop,
                    signal: .oscillator(
                        waveform: .sine, frequency: 1.0, amplitude: 24.0,
                        phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress
                    ),
                    staggerFraction: 0.5
                )
            ]
        )
        let config = TextConfiguration(
            content: "ABCDE",
            fontSize: 48,
            animation: TextAnimationConfiguration(scriptSpeed: 1.0, graph: graph)
        )
        let midCycle = TextAnimationEvaluator.evaluate(
            config: config, localTime: 1.25, duration: 5.0, canvasSize: canvasSize, charIndex: 4, charCount: 5
        )
        let endSeam = TextAnimationEvaluator.evaluate(
            config: config, localTime: 1.999, duration: 5.0, canvasSize: canvasSize, charIndex: 4, charCount: 5
        )
        let nextStart = TextAnimationEvaluator.evaluate(
            config: config, localTime: 2.001, duration: 5.0, canvasSize: canvasSize, charIndex: 4, charCount: 5
        )
        #expect(abs(midCycle.config.positionY - (-24.0)) < 0.25)
        #expect(abs(endSeam.config.positionY - nextStart.config.positionY) < 1.0)
    }

    @Test("Audio reactive sampler inputs modulate rendered text pixels when beat energy spikes")
    func testAudioReactiveGraphProducesDistinctRenderedPixels() {
        let graph = TextAnimationGraph(
            id: "audio-pulse",
            name: "Audio Pulse",
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.scaleX,
                    signal: .remap(.externalInput(name: TextAnimationChannel.audioRMS, fallback: 0.0), inputMin: 0.0, inputMax: 1.0, outputMin: 0.85, outputMax: 1.45)
                ),
                TextAnimationTrack(
                    channel: TextAnimationChannel.scaleY,
                    signal: .remap(.externalInput(name: TextAnimationChannel.audioBeat, fallback: 0.0), inputMin: 0.0, inputMax: 1.0, outputMin: 0.85, outputMax: 1.45)
                )
            ]
        )
        let config = TextConfiguration(
            content: "BEAT",
            fontSize: 72,
            textColorHex: "#FFFFFF",
            animation: TextAnimationConfiguration(isBeatSyncEnabled: true, beatBPM: 120.0, graph: graph)
        )
        let engine = TextRendererEngine()
        let canvas = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: canvasSize))

        let quietImg = engine.composite(
            config: config, over: canvas, localTime: 2.0, duration: 5.0, canvasSize: canvasSize,
            animationInputs: [TextAnimationChannel.audioRMS: 0.05, TextAnimationChannel.audioBeat: 0.0]
        )
        let peakImg = engine.composite(
            config: config, over: canvas, localTime: 2.0, duration: 5.0, canvasSize: canvasSize,
            animationInputs: [TextAnimationChannel.audioRMS: 0.95, TextAnimationChannel.audioBeat: 1.0]
        )

        #expect(meanLuma(of: peakImg) > meanLuma(of: quietImg) * 1.15)
    }

    @Test("Segmented graph evaluation executes per-token shaders and injected plugins cleanly")
    func testSegmentedPerTokenPluginsAndEnvelopeMeasurement() {
        let graph = TextAnimationGraph(
            id: "token-plugin",
            name: "Token Plugin",
            scope: .perCharacter,
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.positionY,
                    signal: .constant(18.0)
                ),
                TextAnimationTrack(
                    channel: "custom.tint.strength",
                    signal: .unitIndex
                )
            ]
        )
        var config = TextConfiguration(
            content: "AB",
            fontSize: 64,
            textColorHex: "#FFFFFF",
            animation: TextAnimationConfiguration(graph: graph)
        )
        config.background.isEnabled = true

        let baselineEngine = TextRendererEngine()
        let pluginEngine = TextRendererEngine(renderPlugins: [TestBloomTintPlugin()])

        let sizeWithoutGraph = baselineEngine.measureSize(
            for: TextConfiguration(content: "AB", fontSize: 64, background: config.background),
            canvasSize: canvasSize
        )
        let sizeWithGraph = pluginEngine.measureSize(for: config, canvasSize: canvasSize)
        #expect(sizeWithGraph.height > sizeWithoutGraph.height + 10.0)

        config.background.isEnabled = false
        let baseImg = baselineEngine.renderAnimatedImage(for: config, localTime: 2.0, duration: 5.0, canvasSize: canvasSize)
        let plugImg = pluginEngine.renderAnimatedImage(for: config, localTime: 2.0, duration: 5.0, canvasSize: canvasSize)
        #expect(baseImg != nil && plugImg != nil)

        if let baseImg, let plugImg {
            let baseRGB = averageRGB(of: baseImg)
            let plugRGB = averageRGB(of: plugImg)
            // First character has unitIndex=0 (white), second has unitIndex=1 (green tint), reducing red/blue relative to green
            #expect(plugRGB.green > plugRGB.red * 1.15)
            #expect(abs(baseRGB.red - baseRGB.green) < 0.05)
        }
    }

    @Test("Audio reactive builder extracts non-empty inputs from silent or active timeline snapshots")
    func testAudioReactiveInputsBuilder() {
        let track = AudioReactiveTrackSnapshot(
            clipName: "Beat",
            timelineStart: 0.0,
            timelineDuration: 6.0,
            sourceStart: 0.0,
            speed: 1.0,
            volume: 1.0,
            beatTimesSeconds: [1.0, 2.0, 3.0],
            detectedBPM: 120.0,
            profile: nil
        )
        let cfg = TextConfiguration(
            content: "Hi",
            animation: TextAnimationConfiguration(isBeatSyncEnabled: true, beatBPM: 120.0)
        )
        let onBeat = TextAudioReactiveInputsBuilder.inputs(atTimelineTime: 2.01, config: cfg, audioTracks: [track])
        let offBeat = TextAudioReactiveInputsBuilder.inputs(atTimelineTime: 2.45, config: cfg, audioTracks: [track])
        #expect((onBeat[TextAnimationChannel.audioBeat] ?? 0.0) > 0.7)
        #expect((offBeat[TextAnimationChannel.audioBeat] ?? 1.0) < 0.15)
        #expect(onBeat[TextAnimationChannel.audioIsSynced] == 1.0)
    }

    @Test("2D Anchor pivot, Z-Depth Sorting, and Unified Graph Thumbnail Previews execute cleanly")
    @MainActor
    func test2DAnchorZDepthSortingAndCatalogThumbnails() {
        let evalA = TextAnimationEvaluator.EvaluationResult(
            config: TextConfiguration(content: "A"),
            overlay: TextTransformOverlay(offsetZEm: 0.8)
        )
        let evalB = TextAnimationEvaluator.EvaluationResult(
            config: TextConfiguration(content: "B"),
            overlay: TextTransformOverlay(offsetZEm: -0.8)
        )
        let entryA = TextGPUSegmentedDepthSorter.DepthEntry(
            orderIndex: 0, tokenIndex: 0, evaluated: evalA, curveCenter: .zero, depthZ: 40.0, depthScale: 1.15
        )
        let entryB = TextGPUSegmentedDepthSorter.DepthEntry(
            orderIndex: 1, tokenIndex: 1, evaluated: evalB, curveCenter: .zero, depthZ: -40.0, depthScale: 0.85
        )
        let sorted = TextGPUSegmentedDepthSorter.sortedBackToFront([entryA, entryB])
        #expect(sorted.map(\.orderIndex) == [1, 0])
        #expect(TextGPUSegmentedDepthSorter.perspectiveDepthScale(offsetZEm: 1.0) > 1.0)
        #expect(TextGPUSegmentedDepthSorter.perspectiveDepthScale(offsetZEm: -1.0) < 1.0)

        for graph in TextAnimationGraphLibrary.allGraphs {
            let heroT = TextThumbnailRenderer.heroPreviewTime(for: graph.id)
            let thumb = TextThumbnailRenderer.renderScriptPreviewFrame(scriptId: graph.id, localTime: heroT, duration: 2.8)
            #expect(thumb != nil, "Thumbnail preview failed for graph \(graph.id)")
        }

        let engine = TextRendererEngine()
        let doorCfg = TextConfiguration(
            content: "HINGE",
            fontSize: 64,
            textColorHex: "#FFFFFF",
            animation: TextAnimationConfiguration(graph: TextAnimationGraphLibrary.doorHingeSwing3D)
        )
        let doorImg = engine.renderAnimatedImage(for: doorCfg, localTime: 0.25, duration: 5.0, canvasSize: canvasSize)
        #expect(doorImg?.extent.size == canvasSize)
    }

    private func meanLuma(of image: CIImage) -> Double {
        let rgb = averageRGB(of: image)
        return 0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
    }

    private func averageRGB(of image: CIImage) -> (red: Double, green: Double, blue: Double) {
        let rect = CGRect(origin: .zero, size: canvasSize)
        guard let avg = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image.cropped(to: rect),
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])?.outputImage else {
            return (0, 0, 0)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avg, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(pixel[0]) / 255.0, Double(pixel[1]) / 255.0, Double(pixel[2]) / 255.0)
    }
}
