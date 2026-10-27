import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("Preset Origin Tracking Tests")
struct PresetOriginTrackingTests {

    @Test("Adding adjustment clip with originPresetID attaches metadata to clip properties")
    @MainActor
    func testAddAdjustmentClipPreservesOriginPresetID() {
        let vm = TimelineViewModel(initialLayers: [])
        var cfg = AdjustmentConfiguration()
        cfg.basic.contrast = 20

        vm.addAdjustmentClip(
            named: "Điện ảnh",
            config: cfg,
            originPresetID: "cinematic_teal_orange"
        )

        let clip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .adjustment })
        #expect(clip != nil)
        #expect(clip?.properties["originPresetId"]?.asString == "cinematic_teal_orange")
        #expect(clip?.properties["originPresetName"]?.asString == "Điện ảnh")
    }

    @Test("Adding text preset attaches originPresetId and originPresetName to clip properties")
    @MainActor
    func testAddTextPresetPreservesOriginPresetID() {
        let vm = TimelineViewModel(initialLayers: [])
        let preset = TextPreset(
            id: "preset_karaoke_neon",
            name: "Neon Karaoke",
            description: "Mẫu chữ neon",
            category: .cyber,
            config: TextConfiguration(content: "HELLO WORLD"),
            isSystem: true
        )

        vm.addTextPreset(preset)

        let clip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text })
        #expect(clip != nil)
        #expect(clip?.properties["originPresetId"]?.asString == "preset_karaoke_neon")
        #expect(clip?.properties["originPresetName"]?.asString == "Neon Karaoke")
    }
}
