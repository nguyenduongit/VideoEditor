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

    @Test func testNewAspectRatiosPropertiesAndClosestMatching() {
        let r1x1 = CanvasAspectRatio.ratio1x1
        #expect(r1x1.width == 1080 && r1x1.height == 1080 && r1x1.title == "1:1")
        #expect(abs(r1x1.ratio - 1.0) < 0.001)

        let r4x3 = CanvasAspectRatio.ratio4x3
        #expect(r4x3.width == 1440 && r4x3.height == 1080 && r4x3.title == "4:3")
        #expect(abs(r4x3.ratio - (4.0 / 3.0)) < 0.001)

        let r3x4 = CanvasAspectRatio.ratio3x4
        #expect(r3x4.width == 1080 && r3x4.height == 1440 && r3x4.title == "3:4")
        #expect(abs(r3x4.ratio - (3.0 / 4.0)) < 0.001)

        let r5x7 = CanvasAspectRatio.ratio5x7
        #expect(r5x7.width == 1080 && r5x7.height == 1512 && r5x7.title == "5:7")
        #expect(abs(r5x7.ratio - (5.0 / 7.0)) < 0.001)

        let r7x5 = CanvasAspectRatio.ratio7x5
        #expect(r7x5.width == 1512 && r7x5.height == 1080 && r7x5.title == "7:5")
        #expect(abs(r7x5.ratio - (7.0 / 5.0)) < 0.001)

        let r21x9 = CanvasAspectRatio.ratio21x9
        #expect(r21x9.width == 2560 && r21x9.height == 1080 && r21x9.title == "21:9")

        // Closest matching
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1920, height: 1080)) == .ratio16x9)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 3840, height: 2160)) == .ratio16x9)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1080, height: 1920)) == .ratio9x16)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 720, height: 1280)) == .ratio9x16)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1000, height: 1000)) == .ratio1x1)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1200, height: 1600)) == .ratio3x4)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1600, height: 1200)) == .ratio4x3)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1000, height: 1400)) == .ratio5x7)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 1400, height: 1000)) == .ratio7x5)
        #expect(CanvasAspectRatio.closest(for: CGSize(width: 2560, height: 1080)) == .ratio21x9)
    }

    @Test func testAutoAspectAdjustmentOnFirstClip() {
        let vm = TimelineViewModel(initialLayers: [])
        #expect(vm.aspectRatio == .ratio16x9)

        let verticalURL = URL(fileURLWithPath: "/tmp/sample_vertical.mp4")
        TimelineMediaDimensionResolver.cacheDimension(CGSize(width: 1080, height: 1920), for: verticalURL)

        let firstAsset = MediaAsset(url: verticalURL, type: .video)
        vm.addAsset(firstAsset, at: .zero)

        // Empty timeline automatically adopts the first clip's aspect ratio (9:16)
        #expect(vm.aspectRatio == .ratio9x16)

        // Adding a second clip with square aspect ratio does NOT alter the project's aspect ratio
        let squareURL = URL(fileURLWithPath: "/tmp/sample_square.png")
        TimelineMediaDimensionResolver.cacheDimension(CGSize(width: 1000, height: 1000), for: squareURL)

        let secondAsset = MediaAsset(url: squareURL, type: .image)
        vm.addAsset(secondAsset, at: CMTime(value: 6, timescale: 1))

        #expect(vm.aspectRatio == .ratio9x16)
    }

    @Test func testAutoAspectAdjustmentAudioClipDoesNotChangeRatio() {
        let vm = TimelineViewModel(initialLayers: [])
        #expect(vm.aspectRatio == .ratio16x9)

        let audioURL = URL(fileURLWithPath: "/tmp/sample_audio.mp3")
        let audioAsset = MediaAsset(url: audioURL, type: .audio)
        vm.addAsset(audioAsset, at: .zero)

        // Audio has no visual dimension, timeline remains default 16:9
        #expect(vm.aspectRatio == .ratio16x9)
    }
}
