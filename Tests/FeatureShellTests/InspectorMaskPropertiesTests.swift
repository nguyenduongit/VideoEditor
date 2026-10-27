import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("InspectorMaskPropertiesTests")
@MainActor
struct InspectorMaskPropertiesTests {
    @Test("Video clip provides complete mask descriptors with picker control")
    func testVideoClipProvidesMaskDescriptors() {
        let registry = ClipPropertyRegistry()
        let maskDesc = registry.descriptors(for: .video, tab: "Mask")

        guard let typeDesc = maskDesc.first(where: { $0.id == "maskType" }) else {
            Issue.record("maskType descriptor missing")
            return
        }

        #expect(typeDesc.defaultValue == .string("none"))
        if case .picker(let options) = typeDesc.control {
            #expect(options.count == 5)
            #expect(options.map(\.id) == ["none", "split", "filmstrip", "circle", "rectangle"])
        } else {
            Issue.record("maskType must use .picker control kind")
        }

        #expect(maskDesc.contains { $0.id == "maskInvert" })
        #expect(maskDesc.contains { $0.id == "maskFeather" })
        #expect(maskDesc.contains { $0.id == "maskPosition" })
        #expect(maskDesc.contains { $0.id == "maskRotation" })
        #expect(maskDesc.contains { $0.id == "maskRadiusX" })
        #expect(maskDesc.contains { $0.id == "maskRadiusY" })
        #expect(maskDesc.contains { $0.id == "maskWidth" })
        #expect(maskDesc.contains { $0.id == "maskHeight" })
        #expect(maskDesc.contains { $0.id == "maskCornerRadius" })
        #expect(maskDesc.contains { $0.id == "maskFilmHeight" })
    }

    @Test("InspectorViewModel dynamically filters mask properties by selected mask type")
    func testDynamicConditionFilteringForMaskShapes() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/mask_test.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        inspectorVM.selectedTab = "Mask"

        // 1. None: only maskType is visible
        let noneIDs = inspectorVM.groupedDescriptors.first?.descriptors.map(\.id) ?? []
        #expect(noneIDs == ["maskType"])

        // 2. Circle: includes invert, feather, position, rotation, radiusX, radiusY
        inspectorVM.updateDiscreteString(key: "maskType", value: "circle")
        let circleIDs = inspectorVM.groupedDescriptors.first?.descriptors.map(\.id) ?? []
        #expect(circleIDs.contains("maskType"))
        #expect(circleIDs.contains("maskInvert"))
        #expect(circleIDs.contains("maskFeather"))
        #expect(circleIDs.contains("maskPosition"))
        #expect(circleIDs.contains("maskRotation"))
        #expect(circleIDs.contains("maskRadiusX"))
        #expect(circleIDs.contains("maskRadiusY"))
        #expect(!circleIDs.contains("maskWidth"))
        #expect(!circleIDs.contains("maskCornerRadius"))

        // 3. Rectangle: includes invert, feather, position, rotation, width, height, cornerRadius
        inspectorVM.updateDiscreteString(key: "maskType", value: "rectangle")
        let rectIDs = inspectorVM.groupedDescriptors.first?.descriptors.map(\.id) ?? []
        #expect(rectIDs.contains("maskWidth"))
        #expect(rectIDs.contains("maskHeight"))
        #expect(rectIDs.contains("maskCornerRadius"))
        #expect(!rectIDs.contains("maskRadiusX"))

        // 4. Split: includes position, rotation, invert, feather
        inspectorVM.updateDiscreteString(key: "maskType", value: "split")
        let splitIDs = inspectorVM.groupedDescriptors.first?.descriptors.map(\.id) ?? []
        #expect(splitIDs.contains("maskPosition"))
        #expect(splitIDs.contains("maskRotation"))
        #expect(!splitIDs.contains("maskRadiusX"))
        #expect(!splitIDs.contains("maskWidth"))

        // 5. Filmstrip: includes offsetY, filmHeight, invert, feather
        inspectorVM.updateDiscreteString(key: "maskType", value: "filmstrip")
        let filmIDs = inspectorVM.groupedDescriptors.first?.descriptors.map(\.id) ?? []
        #expect(filmIDs.contains("maskOffsetY"))
        #expect(filmIDs.contains("maskFilmHeight"))
        #expect(!filmIDs.contains("maskPosition"))
    }

    @Test("Mask type changes commit commands and support transactional undo/redo")
    func testMaskTypeChangeUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/mask_undo.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        inspectorVM.selectedTab = "Mask"

        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString ?? "none" == "none")

        inspectorVM.updateDiscreteString(key: "maskType", value: "circle")
        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString == "circle")

        vm.undo()
        inspectorVM.syncWithSelection()
        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString ?? "none" == "none")

        vm.redo()
        inspectorVM.syncWithSelection()
        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString == "circle")
    }

    @Test("Reset group on Mask resets all mask properties to defaults and supports undo")
    func testMaskResetGroup() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/mask_reset.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        inspectorVM.selectedTab = "Mask"

        inspectorVM.updateDiscreteString(key: "maskType", value: "rectangle")
        inspectorVM.updateLiveValue(key: "maskFeather", value: 0.35)
        inspectorVM.onSliderEditingChanged(key: "maskFeather", isEditing: false)

        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString == "rectangle")
        #expect(vm.clip(by: clip.id)?.properties["maskFeather"]?.asNumber == 0.35)

        inspectorVM.resetGroup(name: "Mask")
        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString == "none")
        #expect(vm.clip(by: clip.id)?.properties["maskFeather"]?.asNumber == 0.0)

        vm.undo()
        inspectorVM.syncWithSelection()
        #expect(vm.clip(by: clip.id)?.properties["maskType"]?.asString == "rectangle")
        #expect(vm.clip(by: clip.id)?.properties["maskFeather"]?.asNumber == 0.35)
    }
}
