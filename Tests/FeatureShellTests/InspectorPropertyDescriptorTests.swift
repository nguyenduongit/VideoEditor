import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("InspectorPropertyDescriptorTests")
@MainActor
struct InspectorPropertyDescriptorTests {
    @Test("Registry provides distinct property sets for each clip kind")
    func testRegistryProvidesDistinctPropertySets() {
        let registry = ClipPropertyRegistry.shared

        let videoDescriptors = registry.descriptors(for: .video)
        let audioDescriptors = registry.descriptors(for: .audio)
        let textDescriptors = registry.descriptors(for: .text)
        let adjustmentDescriptors = registry.descriptors(for: .adjustment)

        // Video has both transform and audio
        #expect(videoDescriptors.contains { $0.id == "opacity" })
        #expect(videoDescriptors.contains { $0.id == "volume" })
        #expect(videoDescriptors.contains { $0.id == "scale" })

        // Audio only has audio properties, no transform
        #expect(audioDescriptors.contains { $0.id == "volume" })
        #expect(audioDescriptors.contains { $0.id == "pan" && $0.title == "Balance" })
        #expect(!audioDescriptors.contains { $0.id == "scale" })
        #expect(!audioDescriptors.contains { $0.id == "opacity" })

        // Text has textContent and fontSize
        #expect(textDescriptors.contains { $0.id == "textContent" })
        #expect(textDescriptors.contains { $0.id == "fontSize" })

        // Adjustment has filter adjustments
        #expect(adjustmentDescriptors.contains { $0.id == "brightness" })
        #expect(adjustmentDescriptors.contains { $0.id == "contrast" })
    }

    @Test("UpdateClipProperties command modifies clip and supports undo/redo")
    func testUpdateClipPropertiesCommandUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        #expect(clip.properties["opacity"]?.asNumber == 1.0)

        // Apply property update
        var updatedProps = clip.properties
        updatedProps["opacity"] = .number(0.4)
        updatedProps["volume"] = .number(0.8)

        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: updatedProps)
        let success = vm.commandExecutor?.execute(cmd) ?? false
        #expect(success == true)

        let modifiedClip = vm.clip(by: clip.id)
        #expect(modifiedClip?.properties["opacity"]?.asNumber == 0.4)
        #expect(modifiedClip?.properties["volume"]?.asNumber == 0.8)

        // Undo
        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        let undoneClip = vm.clip(by: clip.id)
        #expect(undoneClip?.properties["opacity"]?.asNumber == 1.0)
        #expect(undoneClip?.properties["volume"]?.asNumber == 1.0)

        // Redo
        let redoSuccess = vm.redo()
        #expect(redoSuccess == true)
        let redoneClip = vm.clip(by: clip.id)
        #expect(redoneClip?.properties["opacity"]?.asNumber == 0.4)
        #expect(redoneClip?.properties["volume"]?.asNumber == 0.8)
    }

    @Test("Properties persist across project script export, JSON encode/decode, and import")
    func testPropertiesPersistAcrossScriptSerialization() throws {
        let vm1 = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/props.mp4"), type: .video)
        vm1.addAsset(asset, at: .zero)

        guard let clip = vm1.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        var customProps = clip.properties
        customProps["opacity"] = .number(0.65)
        customProps["scale"] = .number(1.5)
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: customProps)
        _ = vm1.commandExecutor?.execute(cmd)

        // Export and serialize
        let script = vm1.exportScript(title: "Property Project")
        let data = try JSONEncoder().encode(script)
        let loadedScript = try JSONDecoder().decode(ProjectScript.self, from: data)

        // Load into fresh VM
        let vm2 = TimelineViewModel(initialLayers: [])
        vm2.loadScript(loadedScript)

        let loadedClip = vm2.clip(by: clip.id)
        #expect(loadedClip != nil)
        #expect(loadedClip?.properties["opacity"]?.asNumber == 0.65)
        #expect(loadedClip?.properties["scale"]?.asNumber == 1.5)
    }

    @Test("InspectorViewModel batches slider continuous drag into single command")
    func testInspectorViewModelSliderDragBatching() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/drag.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectedClipIDs = [clip.id]
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.selectedClip?.id == clip.id)
        #expect(inspectorVM.liveProperties["opacity"]?.asNumber == 1.0)
        let initialHistoryCount = vm.commandExecutor?.history.count ?? 0

        // 1. User starts drag
        inspectorVM.onSliderEditingChanged(key: "opacity", isEditing: true)
        #expect(vm.commandExecutor?.history.count == initialHistoryCount)

        // 2. User drags continuously (multiple micro updates)
        inspectorVM.updateLiveValue(key: "opacity", value: 0.8)
        inspectorVM.updateLiveValue(key: "opacity", value: 0.6)
        inspectorVM.updateLiveValue(key: "opacity", value: 0.3)
        #expect(vm.commandExecutor?.history.count == initialHistoryCount)

        // 3. User releases slider
        inspectorVM.onSliderEditingChanged(key: "opacity", isEditing: false)
        #expect(vm.commandExecutor?.history.count == initialHistoryCount + 1)

        // Verify committed value
        let committedClip = vm.clip(by: clip.id)
        #expect(committedClip?.properties["opacity"]?.asNumber == 0.3)

        // Verify undo rolls back to pre-drag value (1.0)
        let undo = vm.undo()
        #expect(undo == true)
        let rolledBackClip = vm.clip(by: clip.id)
        #expect(rolledBackClip?.properties["opacity"]?.asNumber == 1.0)
    }

    @Test("Instant property lookup falls back to selectedClip directly without delay")
    func testInstantPropertyLookupWithoutDelay() {
        let vm = TimelineViewModel(initialLayers: [])
        let videoAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/v.mp4"), type: .video)
        let audioAsset = MediaAsset(url: URL(fileURLWithPath: "/tmp/a.mp3"), type: .audio)
        vm.addAsset(videoAsset, at: .zero)
        vm.addAsset(audioAsset, at: .zero)

        let videoClip = vm.layers.first(where: { $0.kind == .video })?.clips.first
        let audioClip = vm.layers.first(where: { $0.kind == .audio })?.clips.first
        #expect(videoClip != nil)
        #expect(audioClip != nil)

        guard let vClip = videoClip, let aClip = audioClip else { return }

        // Set custom properties
        vm.commandExecutor?.execute(.updateClipProperties(clipID: vClip.id, properties: ["opacity": .number(0.42), "scale": .number(1.8)]))
        vm.commandExecutor?.execute(.updateClipProperties(clipID: aClip.id, properties: ["volume": .number(0.75)]))

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)

        // Select video clip
        vm.selectClip(vClip.id)
        inspectorVM.liveProperties = [:]
        #expect(inspectorVM.liveNumber(for: "opacity", default: 1.0) == 0.42)
        #expect(inspectorVM.liveNumber(for: "scale", default: 1.0) == 1.8)

        // Switch selection to audio clip
        vm.selectClip(aClip.id)
        #expect(inspectorVM.liveNumber(for: "volume", default: 1.0) == 0.75)
        #expect(inspectorVM.descriptors.contains(where: { $0.id == "volume" }))
        #expect(!inspectorVM.descriptors.contains(where: { $0.id == "opacity" }))

        // Switch back to video clip
        vm.selectClip(vClip.id)
        #expect(inspectorVM.liveNumber(for: "opacity", default: 1.0) == 0.42)
        #expect(inspectorVM.descriptors.contains(where: { $0.id == "opacity" }))
    }
}
