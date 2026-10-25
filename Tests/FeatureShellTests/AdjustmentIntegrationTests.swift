import Testing
import Foundation
import CoreMedia
@preconcurrency import CoreImage
import Domain
@testable import FeatureShell

@Suite("AdjustmentIntegrationTests")
@MainActor
struct AdjustmentIntegrationTests {

    @Test("Adding adjustment clip creates layer and persists adjustmentConfig")
    func testAddAdjustmentClip() {
        let vm = TimelineViewModel(initialLayers: [])
        let preset = AdjustmentPreset.templates.first { $0.id == "cinematic" }
        #expect(preset != nil)

        vm.addAdjustmentClip(
            named: preset?.name ?? "Cinematic",
            config: preset?.config ?? AdjustmentConfiguration()
        )

        #expect(vm.layers.count == 1)
        let layer = vm.layers[0]
        #expect(layer.kind == .adjustment)
        #expect(layer.clips.count == 1)

        let clip = layer.clips[0]
        #expect(clip.kind == .adjustment)
        #expect(clip.name == "Điện ảnh")

        let configStr = clip.properties["adjustmentConfig"]?.asString
        #expect(configStr != nil)

        let decoded = configStr.flatMap { AdjustmentConfiguration.decode(from: $0) }
        #expect(decoded != nil)
        #expect(decoded?.basic.contrast == 18.0)
        #expect(decoded?.hsl.orange.saturation == 20.0)
    }

    @Test("Adding adjustment clip supports Undo and Redo")
    func testAddAdjustmentClipUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        vm.addAdjustmentClip(named: "Default Adj")

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)

        let canUndo = vm.undo()
        #expect(canUndo)
        #expect(vm.layers.isEmpty || vm.layers.allSatisfy { $0.clips.isEmpty })

        let canRedo = vm.redo()
        #expect(canRedo)
        #expect(vm.layers.contains { $0.kind == .adjustment && $0.clips.count == 1 })
    }

    @Test("TimelineCompositionBuilder activates custom compositor when adjustment clip exists")
    func testCompositorActivationWithAdjustmentLayer() {
        let emptyLayers: [TimelineLayer] = [
            TimelineLayer(kind: .video, clips: [])
        ]
        #expect(!TimelineCompositionBuilder.hasActiveMask(in: emptyLayers))

        let clip = TimelineClip(
            name: "Adj",
            kind: .adjustment,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let adjLayers: [TimelineLayer] = [
            TimelineLayer(kind: .adjustment, clips: [clip]),
            TimelineLayer(kind: .video, clips: [])
        ]

        #expect(TimelineCompositionBuilder.hasActiveMask(in: adjLayers))
    }

    @Test("ColorGradingEngine applies grading to CIImage without crashing")
    func testColorGradingEngineExecution() {
        let extent = CGRect(x: 0, y: 0, width: 100, height: 100)
        let baseImage = CIImage(color: CIColor.red).cropped(to: extent)

        var hsl = HSLAdjustments()
        hsl.red = HSLChannel(hue: 20, saturation: -30, luminance: 10)
        let config = AdjustmentConfiguration(
            basic: BasicGradingParameters(
                temp: 20, tint: 10, saturation: 15,
                exposure: 5, contrast: 10, highlight: -10, shadow: 15,
                white: 5, black: -5, brilliance: 10
            ),
            hsl: hsl
        )

        let output = ColorGradingEngine.shared.applyGrading(to: baseImage, config: config, intensity: 1.0)
        #expect(output.extent == extent)
    }

    @Test("Video clip provides tabs Video, Grid, Mask, Adjustment, AI and Adjustment provides 5 grading tabs")
    func testClipMainTabs() {
        let videoClip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1))
        )
        let videoLayer = TimelineLayer(name: "V1", kind: .video, clips: [videoClip])
        let vm = TimelineViewModel(initialLayers: [videoLayer])
        vm.selectClip(videoClip.id)

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.selectedClip?.kind == .video)
        #expect(inspectorVM.availableTabs == ["Video", "Mask", "Adjustment", "AI"])
        #expect(inspectorVM.effectiveTab == "Video")

        inspectorVM.selectedTab = "Adjustment"
        #expect(inspectorVM.effectiveTab == "Adjustment")

        // Test Adjustment clip
        vm.addAdjustmentClip(named: "Test Adj")
        inspectorVM.syncWithSelection()
        #expect(inspectorVM.selectedClip?.kind == .adjustment)
        #expect(inspectorVM.availableTabs == ["Basic", "HSL", "Wheels", "Curves", "Effects"])
        #expect(inspectorVM.effectiveTab == "Basic")
    }

    @Test("AdjustmentConfiguration supports isEnabled flag to toggle grading on and off")
    func testAdjustmentConfigurationIsEnabled() {
        var config = AdjustmentConfiguration()
        #expect(config.isEnabled)
        #expect(config.isNeutral)

        config.basic.contrast = 25.0
        #expect(!config.isNeutral)

        // Disable adjustment -> immediately becomes neutral (bypassed)
        config.isEnabled = false
        #expect(config.isNeutral)

        // Encode and decode roundtrip
        guard let json = config.encodeToJSON(),
              let decoded = AdjustmentConfiguration.decode(from: json) else {
            Issue.record("Failed to roundtrip JSON")
            return
        }
        #expect(!decoded.isEnabled)
        #expect(decoded.basic.contrast == 25.0)
        #expect(decoded.isNeutral)
    }

    @Test("Toggling isEnabled preserves custom compositor to prevent black screen flashing")
    func testCompositorPreservedOnToggle() {
        var config = AdjustmentConfiguration()
        config.basic.contrast = 20.0
        config.isEnabled = true
        let enabledJSON = config.encodeToJSON()!

        let enabledClip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            properties: ["adjustmentConfig": .string(enabledJSON)]
        )
        let layerEnabled = TimelineLayer(kind: .video, clips: [enabledClip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layerEnabled]))

        // Disable adjustment
        config.isEnabled = false
        let disabledJSON = config.encodeToJSON()!
        let disabledClip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            properties: ["adjustmentConfig": .string(disabledJSON)]
        )
        let layerDisabled = TimelineLayer(kind: .video, clips: [disabledClip])

        // Custom compositor MUST remain active to avoid replacing AVPlayerItem
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layerDisabled]))
    }

    @Test("LUTParser parses valid .cube files and rejects invalid content")
    func testLUTParser() {
        let validCube = """
        TITLE "Test 2x2x2"
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """
        let parsed = LUTParser.parse(cubeString: validCube)
        #expect(parsed != nil)
        #expect(parsed?.dimension == 2)
        #expect(parsed?.cubeData.count == 2 * 2 * 2 * 4 * MemoryLayout<Float>.size)

        let invalidCube = "LUT_3D_SIZE 2\n0.0 0.0"
        #expect(LUTParser.parse(cubeString: invalidCube) == nil)
    }

    @Test("HistogramEngine calculates 256 bins and telemetry from CIImage")
    func testHistogramEngine() {
        let extent = CGRect(x: 0, y: 0, width: 64, height: 64)
        let redImage = CIImage(color: CIColor.red).cropped(to: extent)
        let data = HistogramEngine.shared.calculateHistogram(from: redImage)

        #expect(data.redBins.count == 256)
        #expect(data.greenBins.count == 256)
        #expect(data.blueBins.count == 256)
        #expect(data.lumaBins.count == 256)
        #expect(data.redBins[255] > 0.5) // Red channel has peak at 255

        let telemetry = HistogramEngine.shared.analyzeTelemetry(from: redImage)
        #expect(telemetry.meanRed > 0.8)
        #expect(telemetry.meanBlue < 0.2)
        #expect(telemetry.dominantCast == "warm")
    }

    @Test("ColorGradingEngine applies Wheels, Curves, and Effects without crashing")
    func testAdvancedColorGradingEngine() {
        let extent = CGRect(x: 0, y: 0, width: 80, height: 80)
        let baseImage = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)

        var config = AdjustmentConfiguration()
        config.wheels.lift = ColorWheelOffset(x: -0.2, y: -0.2, luma: 10)
        config.wheels.gamma = ColorWheelOffset(x: 0.1, y: 0.0, luma: -5)
        config.wheels.gain = ColorWheelOffset(x: 0.2, y: 0.2, luma: 15)
        config.curves.master = [CurvePoint(x: 0, y: 0.1), CurvePoint(x: 0.5, y: 0.55), CurvePoint(x: 1, y: 0.95)]
        config.effects.vignetteAmount = 40
        config.effects.sharpenAmount = 30

        let output = ColorGradingEngine.shared.applyGrading(to: baseImage, config: config, intensity: 1.0)
        #expect(output.extent == extent)
    }

    @Test("AdjustmentConfiguration decodes legacy JSON cleanly")
    func testLegacyJSONCompatibility() {
        let legacyJSON = """
        {
            "basic": { "temp": 10, "contrast": 20 },
            "hsl": { "red": { "hue": 5, "saturation": 15, "luminance": -5 } }
        }
        """
        let decoded = AdjustmentConfiguration.decode(from: legacyJSON)
        #expect(decoded != nil)
        #expect(decoded?.basic.temp == 10)
        #expect(decoded?.basic.contrast == 20)
        #expect(decoded?.hsl.red.hue == 5)
        #expect(decoded?.wheels.isNeutral == true)
        #expect(decoded?.curves.isNeutral == true)
        #expect(decoded?.effects.isNeutral == true)
        #expect(decoded?.lut.isNeutral == true)
    }

    @Test("AdjustmentTemplateLoader loads all 16 JSON template scripts with full grading modules")
    func testAdjustmentTemplateLoaderAndSupabaseSync() {
        let templates = AdjustmentTemplateLoader.shared.reload()
        #expect(templates.count >= 16)

        let cinematic = templates.first { $0.id == "cinematic" }
        #expect(cinematic != nil)
        #expect(cinematic?.category == .cinematic)
        #expect(cinematic?.activeModuleBadges == ["Basic", "HSL", "Wheels", "Curves", "FX"])
        if let cinematic {
            let thumb = AdjustmentThumbnailRenderer.shared.thumbnail(for: cinematic)
            #expect(thumb != nil)
            #expect(thumb?.size.width == 180)
        }

        let supabaseJSON = """
        {
          "id": "supabase_neon_tokyo",
          "schemaVersion": 99,
          "name": "Supabase Neon Tokyo",
          "description": "Cloud synced grading script",
          "category": "Cyber & Đêm",
          "tags": ["supabase", "neon"],
          "previewBadge": "CLOUD",
          "previewColorsHex": ["#FF007F", "#00F0FF"],
          "futureServerField": "ignored_safely",
          "config": {
            "basic": { "temp": -14.0, "contrast": 24.0 },
            "wheels": { "lift": { "x": -0.12, "y": -0.18, "luma": -4.0 } },
            "effects": { "vignetteAmount": 30.0, "grainAmount": 12.0 }
          }
        }
        """
        let merged = AdjustmentTemplateLoader.shared.mergeSupabaseTemplateScripts(
            [supabaseJSON],
            persistToCache: false
        )
        let synced = merged.first { $0.id == "supabase_neon_tokyo" }
        #expect(synced != nil)
        #expect(synced?.schemaVersion == 99)
        #expect(synced?.config.basic.contrast == 24.0)
        #expect(synced?.config.wheels.lift.x == -0.12)
        #expect(synced?.config.effects.vignetteAmount == 30.0)

        let libraryVM = AdjustmentLibraryViewModel()
        libraryVM.selectedCategory = .cyberNeon
        #expect(!libraryVM.filteredTemplatePresets.isEmpty)
        #expect(libraryVM.filteredTemplatePresets.allSatisfy { $0.category == .cyberNeon })
    }
}
