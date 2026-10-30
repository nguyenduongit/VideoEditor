import Testing
import Foundation
import CoreMedia
@preconcurrency import AVFoundation
@preconcurrency import CoreImage
import Domain
@testable import FeatureShell

@Suite("EffectIntegrationTests")
@MainActor
struct EffectIntegrationTests {

    @Test("Thêm clip effect tạo đúng layer kind .effect và lưu effectConfig")
    func testAddEffectClip() {
        let vm = TimelineViewModel(initialLayers: [])
        let config = EffectConfiguration(type: .fadeIn, intensity: 0.9, speed: 1.5, blurRadius: 20.0)

        vm.addEffectClip(
            named: "Mở màn sáng dần",
            config: config,
            durationSeconds: 3.0
        )

        #expect(vm.layers.count == 1)
        let layer = vm.layers[0]
        #expect(layer.kind == .effect)
        #expect(layer.clips.count == 1)

        let clip = layer.clips[0]
        #expect(clip.kind == .effect)
        #expect(clip.name == "Mở màn sáng dần")
        #expect(CMTimeGetSeconds(clip.timeRange.duration) == 3.0)

        let configStr = clip.properties["effectConfig"]?.asString
        #expect(configStr != nil)

        let decoded = configStr.flatMap { EffectConfiguration.decode(from: $0) }
        #expect(decoded != nil)
        #expect(decoded?.type == .fadeIn)
        #expect(decoded?.intensity == 0.9)
        #expect(decoded?.speed == 1.5)
        #expect(decoded?.blurRadius == 20.0)
    }

    @Test("Thêm clip effect hỗ trợ Undo và Redo")
    func testAddEffectClipUndoRedo() {
        let vm = TimelineViewModel(initialLayers: [])
        vm.addEffectClip(named: "Fade Out Test")

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)

        let canUndo = vm.undo()
        #expect(canUndo)
        #expect(vm.layers.isEmpty || vm.layers.allSatisfy { $0.clips.isEmpty })

        let canRedo = vm.redo()
        #expect(canRedo)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].name == "Fade Out Test")
    }

    @Test("EffectConfiguration mã hoá và giải mã JSON chính xác")
    func testEffectConfigurationJSON() {
        let config = EffectConfiguration(type: .whiteFlash, intensity: 0.85, speed: 2.0, blurRadius: 35.0)
        guard let json = config.encodeToJSON() else {
            Issue.record("Không thể mã hoá EffectConfiguration sang JSON")
            return
        }

        let decoded = EffectConfiguration.decode(from: json)
        #expect(decoded != nil)
        #expect(decoded?.type == .whiteFlash)
        #expect(decoded?.intensity == 0.85)
        #expect(decoded?.speed == 2.0)
        #expect(decoded?.blurRadius == 35.0)
    }

    @Test("EffectEngine áp dụng thành công toàn bộ 5 hiệu ứng cơ bản")
    func testEffectEngineRenderAllTypes() {
        let engine = EffectEngine()
        let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 200, height: 200))

        for type in EffectType.allCases {
            let config = EffectConfiguration(type: type, intensity: 1.0, speed: 1.0, blurRadius: 15.0)
            let result = engine.applyEffect(
                to: testImage,
                config: config,
                localTime: 0.5,
                duration: 2.0,
                canvasSize: CGSize(width: 200, height: 200)
            )
            #expect(result.extent.width > 0, "Hiệu ứng \(type.rawValue) phải trả về CIImage có kích thước hợp lệ")
        }
    }

    @Test("TimelineCompositionBuilder tạo VideoComposition Instruction chứa isEffect = true")
    func testTimelineCompositionWithEffectLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        vm.addEffectClip(named: "Fade In", durationSeconds: 3.0)
        let composition = AVMutableComposition()
        let customComp = TimelineCompositionBuilder.buildVideoComposition(
            for: vm.layers,
            composition: composition,
            layerTrackIDs: [:],
            aspectRatio: .ratio16x9,
            duration: CMTime(seconds: 10.0, preferredTimescale: 600)
        )

        #expect(customComp != nil)
        #expect((customComp?.instructions.count ?? 0) >= 1)
        let customInstructions = customComp?.instructions as? [TimelineCustomVideoCompositionInstruction]
        let hasEffect = customInstructions?.contains { inst in
            inst.layerInfos.contains { $0.isEffect }
        } ?? false
        #expect(hasEffect, "Composition instructions phải chứa layerInfo có isEffect == true")
    }

    @Test("EffectTabDescriptor đăng ký thành công vào TabRegistry")
    func testEffectTabDescriptorRegistration() {
        let registry = TabRegistry()
        let descriptor = EffectTabDescriptor()
        registry.register(descriptor)

        #expect(registry.tabs.contains(where: { $0.id == .effect }))
        let tab = registry.descriptor(for: .effect)
        #expect(tab?.title == "Effects")
        #expect(tab?.order == 50)
        #expect(tab?.makeSidebarView() != nil)
    }
}
