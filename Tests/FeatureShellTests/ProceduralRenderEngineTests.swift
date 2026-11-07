import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("ProceduralRenderEngineTests")
struct ProceduralRenderEngineTests {
    private let engine = ProceduralRenderEngine.shared
    private let canvasSize = CGSize(width: 1920, height: 1080)

    @Test("All 12 procedural types render non-nil CIImage with valid extent")
    func testAllTypesRenderSuccessfully() {
        for type in ProceduralType.allCases {
            let config = ProceduralConfiguration(type: type)
            let image = engine.render(config: config, localTime: 1.0, duration: 5.0, canvasSize: canvasSize)
            #expect(image != nil, "Failed to render procedural type: \(type.rawValue)")
            if let img = image {
                #expect(img.extent.width >= canvasSize.width)
                #expect(img.extent.height >= canvasSize.height)
            }
        }
    }

    @Test("Dynamic procedural patterns vary frame output across time")
    func testDynamicPatternsVaryOverTime() {
        let dynamicTypes: [ProceduralType] = [
            .meshAurora, .topographicLines, .retroGrid,
            .filmCountdown, .hypnoticTunnel, .matrixRain
        ]

        for type in dynamicTypes {
            let config = ProceduralConfiguration(type: type)
            let frame0 = engine.render(config: config, localTime: 0.0, duration: 5.0, canvasSize: canvasSize)
            let frame1 = engine.render(config: config, localTime: 2.5, duration: 5.0, canvasSize: canvasSize)

            #expect(frame0 != nil)
            #expect(frame1 != nil)
        }
    }

    @Test("Film countdown renders valid digit frames across 5 seconds")
    func testCountdownDigits() {
        let config = ProceduralConfiguration(type: .filmCountdown)
        for sec in [0.2, 1.2, 2.2, 3.2, 4.2] {
            let img = engine.render(config: config, localTime: sec, duration: 5.0, canvasSize: canvasSize)
            #expect(img != nil)
        }
    }

    @Test("Procedural blend mode applies screen and add without crashing")
    func testBlendModes() {
        let bg = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: canvasSize))
        let grainConfig = ProceduralConfiguration(type: .filmGrain)
        let grain = engine.render(config: grainConfig, localTime: 1.0, duration: 5.0, canvasSize: canvasSize)!

        let screenBlended = ProceduralRenderEngine.applyBlend(foreground: grain, over: bg, blendMode: "screen", opacity: 0.8)
        #expect(screenBlended.extent.width == canvasSize.width)

        let addBlended = ProceduralRenderEngine.applyBlend(foreground: grain, over: bg, blendMode: "add", opacity: 1.0)
        #expect(addBlended.extent.width == canvasSize.width)

        let multiplyBlended = ProceduralRenderEngine.applyBlend(foreground: grain, over: bg, blendMode: "multiply", opacity: 1.0)
        #expect(multiplyBlended.extent.width == canvasSize.width)
    }

    @Test("Zero canvas size returns nil cleanly without crashing")
    func testZeroCanvasSize() {
        let config = ProceduralConfiguration(type: .meshAurora)
        let img = engine.render(config: config, localTime: 0.0, duration: 5.0, canvasSize: .zero)
        #expect(img == nil)
    }

    @Test("Timeline accepts procedural clip with configuration")
    @MainActor
    func testTimelineAddsProceduralClip() {
        let timelineVM = TimelineViewModel()
        let duration = CMTime(seconds: 5.0, preferredTimescale: 600)

        var properties = BuiltInClipPropertyDefaults.properties(for: .video)
        let config = ProceduralConfiguration(type: .meshAurora)
        properties["isProcedural"] = .bool(true)
        properties["proceduralConfig"] = .string(config.encodeToJSON()!)

        let clip = TimelineClip(
            name: "Cực quang",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            mediaURL: ProceduralAssetProvider.shared.blackVideoURL(),
            properties: properties
        )
        timelineVM.addClip(clip)

        #expect(timelineVM.layers.first?.clips.count == 1)
        let addedClip = timelineVM.layers.first?.clips.first
        #expect(addedClip?.properties["isProcedural"]?.asBool == true)
        let decoded = addedClip?.properties["proceduralConfig"]?.asString.flatMap { ProceduralConfiguration.decode(from: $0) }
        #expect(decoded?.type == .meshAurora)
    }
}
