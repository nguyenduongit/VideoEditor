import Foundation
import CoreMedia
import CoreGraphics
import Testing
import Domain
@testable import FeatureShell

@Suite("CanvasAspectRatioTests")
@MainActor
struct CanvasAspectRatioTests {
    @Test func testCanvasAspectRatioProperties() {
        let r16x9 = CanvasAspectRatio.ratio16x9
        #expect(r16x9.width == 1920)
        #expect(r16x9.height == 1080)
        #expect(r16x9.renderSize == CGSize(width: 1920, height: 1080))
        #expect(r16x9.title == "16:9")
        #expect(abs(r16x9.ratio - (1920.0 / 1080.0)) < 0.001)

        let r9x16 = CanvasAspectRatio.ratio9x16
        #expect(r9x16.width == 1080)
        #expect(r9x16.height == 1920)
        #expect(r9x16.renderSize == CGSize(width: 1080, height: 1920))
        #expect(r9x16.title == "9:16")
        #expect(abs(r9x16.ratio - (1080.0 / 1920.0)) < 0.001)
    }

    @Test func testProjectScriptAspectRatioSerialization() throws {
        let script = ProjectScript(
            title: "Test 9:16 Project",
            fps: 30,
            aspectRatio: .ratio9x16
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(script)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectScript.self, from: data)
        #expect(decoded.aspectRatio == .ratio9x16)
        #expect(decoded.metadata.title == "Test 9:16 Project")
    }

    @Test func testProjectScriptBackwardCompatibility() throws {
        let legacyJSON = """
        {
            "schemaVersion": "1.0.0",
            "metadata": { "title": "Legacy Project", "createdAt": 0, "modifiedAt": 0 },
            "fps": 30,
            "layers": []
        }
        """
        guard let data = legacyJSON.data(using: .utf8) else {
            Issue.record("Failed to create data from string")
            return
        }
        let decoded = try JSONDecoder().decode(ProjectScript.self, from: data)
        #expect(decoded.aspectRatio == .ratio16x9)
    }

    @Test func testTimelineCommandSetAspectRatioCodable() throws {
        let cmd = TimelineCommand.setAspectRatio(.ratio9x16)
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(TimelineCommand.self, from: data)
        #expect(decoded == cmd)
    }

    @Test func testTimelineViewModelAspectRatioAndUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        #expect(vm.aspectRatio == .ratio16x9)

        var changedRatios: [CanvasAspectRatio] = []
        vm.onAspectRatioChanged = { ratio in
            changedRatios.append(ratio)
        }

        vm.setAspectRatio(.ratio9x16)
        #expect(vm.aspectRatio == .ratio9x16)
        #expect(changedRatios == [.ratio9x16])
        #expect(vm.canUndo == true)

        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        #expect(vm.aspectRatio == .ratio16x9)
        #expect(changedRatios == [.ratio9x16, .ratio16x9])

        let redoSuccess = vm.redo()
        #expect(redoSuccess == true)
        #expect(vm.aspectRatio == .ratio9x16)
        #expect(changedRatios == [.ratio9x16, .ratio16x9, .ratio9x16])
    }

    @Test func testTimelineCompositionBuilderRenderSize() {
        let comp16x9 = TimelineCompositionBuilder.makeVideoComposition(
            layerInstructions: [],
            renderSize: CanvasAspectRatio.ratio16x9.renderSize,
            duration: CMTime(value: 5, timescale: 1)
        )
        #expect(comp16x9.renderSize == CGSize(width: 1920, height: 1080))

        let comp9x16 = TimelineCompositionBuilder.makeVideoComposition(
            layerInstructions: [],
            renderSize: CanvasAspectRatio.ratio9x16.renderSize,
            duration: CMTime(value: 5, timescale: 1)
        )
        #expect(comp9x16.renderSize == CGSize(width: 1080, height: 1920))
    }

    @Test func testShellViewModelAspectRatioForwarding() {
        let registry = TabRegistry()
        let timelineVM = TimelineViewModel(initialLayers: [])
        let shellVM = ShellViewModel(registry: registry, timelineViewModel: timelineVM)

        #expect(shellVM.aspectRatio == .ratio16x9)
        shellVM.setAspectRatio(.ratio9x16)
        #expect(shellVM.aspectRatio == .ratio9x16)
        #expect(timelineVM.aspectRatio == .ratio9x16)
    }
}
