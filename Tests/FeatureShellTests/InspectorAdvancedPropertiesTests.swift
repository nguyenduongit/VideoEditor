import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("InspectorAdvancedPropertiesTests")
@MainActor
struct InspectorAdvancedPropertiesTests {
    @Test("Video clip provides tabs: Video, Mask, Adjustment, AI")
    func testVideoClipTabs() {
        let registry = ClipPropertyRegistry()
        let tabs = registry.tabs(for: .video)
        #expect(tabs == ["Video", "Mask", "Adjustment", "AI"])

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

        #expect(inspectorVM.availableTabs == ["Video", "Mask", "Adjustment", "AI"])

        // Default tab is Video (contains Transform, Blend, Speed, and Audio groups under Basic, Speed, Audio subtabs)
        inspectorVM.selectedTab = "Video"
        let videoGroups = inspectorVM.groupedDescriptors
        #expect(videoGroups.count == 4)
        #expect(videoGroups.map(\.group).contains("Transform"))
        #expect(videoGroups.map(\.group).contains("Blend"))
        #expect(videoGroups.map(\.group).contains("Speed"))
        #expect(videoGroups.map(\.group).contains("Audio"))

        #expect(inspectorVM.activeSubtabs == ["Basic", "Speed", "Audio"])
        let basicGroups = inspectorVM.groups(forSubtab: "Basic")
        #expect(basicGroups.count == 2)
        #expect(basicGroups.map(\.group) == ["Transform", "Blend"])

        let transformDesc = videoGroups.first(where: { $0.group == "Transform" })?.descriptors.map(\.id) ?? []
        #expect(transformDesc.contains("position"))
        #expect(transformDesc.contains("scale"))
        #expect(transformDesc.contains("uniformScale"))
        #expect(transformDesc.contains("rotation"))
        #expect(transformDesc.contains("skewX"))
        #expect(transformDesc.contains("skewY"))
        #expect(transformDesc.contains("perspectiveX"))
        #expect(transformDesc.contains("perspectiveY"))
        #expect(transformDesc.contains("flip"))
        #expect(!transformDesc.contains("opacity"))
        #expect(transformDesc == ["position", "scale", "uniformScale", "rotation", "skewX", "skewY", "perspectiveX", "perspectiveY", "flip"])

        let blendDesc = videoGroups.first(where: { $0.group == "Blend" })?.descriptors.map(\.id) ?? []
        #expect(blendDesc.contains("blendMode"))
        #expect(blendDesc.contains("opacity"))
        let speedDesc = videoGroups.first(where: { $0.group == "Speed" })?.descriptors.map(\.id) ?? []
        #expect(speedDesc.contains("speed"))
        #expect(speedDesc.contains("duration"))
        let audioDesc = videoGroups.first(where: { $0.group == "Audio" })?.descriptors.map(\.id) ?? []
        #expect(audioDesc.contains("volume"))

        // Switch to AI tab
        inspectorVM.selectedTab = "AI"
        let aiGroups = inspectorVM.groupedDescriptors
        #expect(aiGroups.count == 1)
        #expect(aiGroups.first?.group == "Auto Pan")

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

    @Test("Uniform scale aspect ratio lock and proportional scaling math")
    func testUniformScaleAspectRatioLock() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/aspect_ratio_test.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        // 1. Ban đầu uniformScale là true -> Scale hiển thị, scaleWidth & scaleHeight ẩn
        let initialTransformDesc = inspectorVM.groupedDescriptors.first(where: { $0.group == "Transform" })?.descriptors.map(\.id) ?? []
        #expect(initialTransformDesc.contains("scale"))
        #expect(!initialTransformDesc.contains("scaleWidth"))
        #expect(!initialTransformDesc.contains("scaleHeight"))

        // 2. Tắt uniformScale -> Scale ẩn, 2 slider Scale Width & Scale Height xuất hiện
        inspectorVM.updateLiveBool(key: "uniformScale", value: false)
        let splitTransformDesc = inspectorVM.groupedDescriptors.first(where: { $0.group == "Transform" })?.descriptors.map(\.id) ?? []
        #expect(!splitTransformDesc.contains("scale"))
        #expect(splitTransformDesc.contains("scaleWidth"))
        #expect(splitTransformDesc.contains("scaleHeight"))

        // 3. Người dùng đặt Scale Width = 90% (0.9), Scale Height = 110% (1.1)
        inspectorVM.updateLiveValue(key: "scaleWidth", value: 0.90)
        inspectorVM.updateLiveValue(key: "scaleHeight", value: 1.10)
        #expect(inspectorVM.liveNumber(for: "scaleWidth", default: 1.0) == 0.90)
        #expect(inspectorVM.liveNumber(for: "scaleHeight", default: 1.0) == 1.10)

        // 4. Người dùng BẬT lại toggle uniformScale = true để khóa tỉ lệ
        inspectorVM.updateLiveBool(key: "uniformScale", value: true)
        // Thanh Scale duy nhất nhận giá trị của scaleWidth (90%)
        #expect(inspectorVM.liveNumber(for: "scale", default: 1.0) == 0.90)

        // 5. Người dùng chỉnh Scale lên 100% (1.0)
        inspectorVM.updateLiveValue(key: "scale", value: 1.0)
        #expect(inspectorVM.liveNumber(for: "scale", default: 1.0) == 1.0)
        #expect(inspectorVM.liveNumber(for: "scaleWidth", default: 1.0) == 1.0)
        // scaleHeight tự động tăng theo tỉ lệ khóa: 1.0 * (1.1 / 0.9) = 1.2222... (~122%)
        let scaledH = inspectorVM.liveNumber(for: "scaleHeight", default: 1.0)
        #expect(abs(scaledH - 1.2222) < 0.001)

        // 6. Người dùng TẮT toggle để tách 2 thanh kiểm tra lại
        inspectorVM.updateLiveBool(key: "uniformScale", value: false)
        #expect(inspectorVM.liveNumber(for: "scaleWidth", default: 1.0) == 1.0)
        let verifiedH = inspectorVM.liveNumber(for: "scaleHeight", default: 1.0)
        #expect(abs(verifiedH - 1.2222) < 0.001)
    }

    @Test("Video clip with non-normal blendMode triggers custom compositor in TimelineCompositionBuilder")
    func testVideoClipBlendModeTriggersCustomCompositor() {
        let overlayClip = TimelineClip(
            name: "Test.mp4",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: ["blendMode": .string("overlay")]
        )
        let overlayLayer = TimelineLayer(id: UUID(), name: "Video 1", kind: .video, clips: [overlayClip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [overlayLayer]) == true)

        let normalClip = TimelineClip(
            name: "Normal.mp4",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: ["blendMode": .string("normal")]
        )
        let normalLayer = TimelineLayer(id: UUID(), name: "Video 1", kind: .video, clips: [normalClip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [normalLayer]) == false)
    }

    @Test("TimelineCompositionBuilder computeTransform applies Skew and Flip")
    func testTransformSkewAndFlipMatrixMath() {
        let flippedClip = TimelineClip(
            name: "Flipped.mp4",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: [
                "flipHorizontal": .bool(true),
                "flipVertical": .bool(true),
                "skewX": .number(15.0),
                "skewY": .number(-10.0)
            ]
        )
        let canvasSize = CGSize(width: 1920, height: 1080)
        let naturalSize = CGSize(width: 1920, height: 1080)
        let res = TimelineCompositionBuilder.computeTransform(
            transform: .identity,
            naturalSize: naturalSize,
            clip: flippedClip,
            canvasSize: canvasSize
        )
        // Transform should have negative scale components due to flip
        #expect(res.transform.a < 0)
        #expect(res.transform.d < 0)
        // And non-zero shear components due to skew
        #expect(abs(res.transform.b) > 0.01)
        #expect(abs(res.transform.c) > 0.01)

        let layer = TimelineLayer(id: UUID(), name: "Video 1", kind: .video, clips: [flippedClip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layer]) == true)

        let perspectiveClip = TimelineClip(
            name: "Perspective.mp4",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: [
                "perspectiveX": .number(0.25),
                "perspectiveY": .number(-0.30)
            ]
        )
        let perspLayer = TimelineLayer(id: UUID(), name: "Video 2", kind: .video, clips: [perspectiveClip])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [perspLayer]) == true)
    }
}
