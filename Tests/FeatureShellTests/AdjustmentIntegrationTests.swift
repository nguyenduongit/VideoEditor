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

    @Test("Adjustment clip provides 2 main tabs Basic and HSL in InspectorViewModel without subtabs")
    func testAdjustmentClipMainTabs() {
        let vm = TimelineViewModel(initialLayers: [])
        vm.addAdjustmentClip(named: "Test Adj")
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.selectedClip?.kind == .adjustment)
        #expect(inspectorVM.availableTabs == ["Basic", "HSL"])
        #expect(inspectorVM.effectiveTab == "Basic")

        inspectorVM.selectedTab = "HSL"
        #expect(inspectorVM.effectiveTab == "HSL")
    }
}
