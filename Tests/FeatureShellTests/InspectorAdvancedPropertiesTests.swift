import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("InspectorAdvancedPropertiesTests")
@MainActor
struct InspectorAdvancedPropertiesTests {
    @Test("Video clip provides tabs: Video, Grid, Mask, AI")
    func testVideoClipTabs() {
        let registry = ClipPropertyRegistry.shared
        let tabs = registry.tabs(for: .video)
        #expect(tabs == ["Video", "Grid", "Mask", "AI"])

        let videoTabDesc = registry.descriptors(for: .video, tab: "Video")
        #expect(videoTabDesc.contains { $0.id == "scale" })
        #expect(videoTabDesc.contains { $0.id == "uniformScale" })
        #expect(videoTabDesc.contains { $0.id == "position" })
        #expect(videoTabDesc.contains { $0.id == "rotation" })
        #expect(videoTabDesc.contains { $0.id == "opacity" })
        #expect(videoTabDesc.contains { $0.id == "speed" })
        #expect(videoTabDesc.contains { $0.id == "duration" })
        #expect(videoTabDesc.contains { $0.id == "pitchPreservation" })
        #expect(videoTabDesc.contains { $0.id == "volume" })

        let maskTabDesc = registry.descriptors(for: .video, tab: "Mask")
        #expect(maskTabDesc.contains { $0.id == "maskType" })

        let aiTabDesc = registry.descriptors(for: .video, tab: "AI")
        #expect(aiTabDesc.contains { $0.id == "autoPanEnabled" })
        #expect(aiTabDesc.contains { $0.id == "autoPanSmoothness" })
    }

    @Test("InspectorViewModel tab switching filters grouped descriptors")
    func testInspectorViewModelTabFiltering() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/test_clip.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.availableTabs == ["Video", "Grid", "Mask", "AI"])

        // Default tab is Video (contains Transform, Speed, and Audio groups)
        inspectorVM.selectedTab = "Video"
        let videoGroups = inspectorVM.groupedDescriptors
        #expect(videoGroups.count == 3)
        #expect(videoGroups.map(\.group).contains("Transform"))
        #expect(videoGroups.map(\.group).contains("Speed"))
        #expect(videoGroups.map(\.group).contains("Audio"))
        let transformDesc = videoGroups.first(where: { $0.group == "Transform" })?.descriptors.map(\.id) ?? []
        #expect(transformDesc.contains("scale"))
        #expect(transformDesc.contains("uniformScale"))
        #expect(transformDesc.contains("position"))
        #expect(transformDesc.contains("rotation"))
        let speedDesc = videoGroups.first(where: { $0.group == "Speed" })?.descriptors.map(\.id) ?? []
        #expect(speedDesc.contains("speed"))
        #expect(speedDesc.contains("duration"))
        let audioDesc = videoGroups.first(where: { $0.group == "Audio" })?.descriptors.map(\.id) ?? []
        #expect(audioDesc.contains("volume"))

        // Switch to Grid tab
        inspectorVM.selectedTab = "Grid"
        let gridGroups = inspectorVM.groupedDescriptors
        #expect(gridGroups.isEmpty)

        // Switch to Mask tab
        inspectorVM.selectedTab = "Mask"
        let maskGroups = inspectorVM.groupedDescriptors
        #expect(maskGroups.count == 1)
        #expect(maskGroups.first?.group == "Mask")
        #expect(maskGroups.first?.descriptors.map(\.id) == ["maskType"])
    }

    @Test("Reset group restores default values and supports undo/redo")
    func testResetGroupWithUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/reset_test.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        // Modify transform properties
        inspectorVM.updateLiveValue(key: "scale", value: 2.5)
        inspectorVM.updateLiveValue(key: "positionX", value: 120.0)
        inspectorVM.updateLiveValue(key: "positionY", value: -80.0)
        inspectorVM.updateLiveValue(key: "rotation", value: 45.0)

        // Commit changes via slider editing end
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: true)
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: false)

        let modifiedClip = vm.clip(by: clip.id)
        #expect(modifiedClip?.properties["scale"]?.asNumber == 2.5)
        #expect(modifiedClip?.properties["positionX"]?.asNumber == 120.0)

        // Trigger Reset for Transform group
        inspectorVM.resetGroup(name: "Transform")

        let resetClip = vm.clip(by: clip.id)
        #expect(resetClip?.properties["scale"]?.asNumber == 1.0)
        #expect(resetClip?.properties["positionX"]?.asNumber == 0.0)
        #expect(resetClip?.properties["positionY"]?.asNumber == 0.0)
        #expect(resetClip?.properties["rotation"]?.asNumber == 0.0)
        #expect(resetClip?.properties["opacity"]?.asNumber == 1.0)

        // Undo restores modified values
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        let undoneClip = vm.clip(by: clip.id)
        #expect(undoneClip?.properties["scale"]?.asNumber == 2.5)
        #expect(undoneClip?.properties["positionX"]?.asNumber == 120.0)
    }

    @Test("Boolean properties like uniformScale commit and undo properly")
    func testBooleanPropertyCommitAndUndo() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/bool_test.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.liveBool(for: "uniformScale", default: true) == true)

        // Toggle to false
        inspectorVM.updateLiveBool(key: "uniformScale", value: false)
        #expect(inspectorVM.liveBool(for: "uniformScale", default: true) == false)
        #expect(vm.clip(by: clip.id)?.properties["uniformScale"]?.asBool == false)

        // Undo
        _ = vm.undo()
        #expect(vm.clip(by: clip.id)?.properties["uniformScale"]?.asBool == true)
    }
}
