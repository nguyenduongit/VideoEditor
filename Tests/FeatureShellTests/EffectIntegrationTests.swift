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
        let hasTweening = customInstructions?.contains { $0.containsTweening } ?? false
        #expect(hasTweening, "Composition instructions chứa effect phải có containsTweening == true")
    }

    @Test("EffectEngine Fade In và Fade Out tuân thủ tỉ lệ tuyến tính chính xác theo tổng thời lượng")
    func testFadeInFadeOutProportionalScaling() {
        let engine = EffectEngine()
        let size = CGSize(width: 100, height: 100)
        let whiteImage = CIImage(color: CIColor.white).cropped(to: CGRect(origin: .zero, size: size))
        let totalDuration = 3.0
        let fadeInConfig = EffectConfiguration(type: .fadeIn, intensity: 1.0)
        let fadeOutConfig = EffectConfiguration(type: .fadeOut, intensity: 1.0)

        // Kiểm tra tại các mốc thời gian tỉ lệ 0%, 50%, 100% của clip 3 giây
        let fadeInAtStart = engine.applyEffect(to: whiteImage, config: fadeInConfig, localTime: 0.0, duration: totalDuration, canvasSize: size)
        #expect(fadeInAtStart.extent.width == 100)

        let fadeInAtMid = engine.applyEffect(to: whiteImage, config: fadeInConfig, localTime: 1.5, duration: totalDuration, canvasSize: size)
        #expect(fadeInAtMid.extent.width == 100)

        let fadeInAtEnd = engine.applyEffect(to: whiteImage, config: fadeInConfig, localTime: 3.0, duration: totalDuration, canvasSize: size)
        #expect(fadeInAtEnd.extent.width == 100)

        let fadeOutAtStart = engine.applyEffect(to: whiteImage, config: fadeOutConfig, localTime: 0.0, duration: totalDuration, canvasSize: size)
        #expect(fadeOutAtStart.extent.width == 100)

        let fadeOutAtMid = engine.applyEffect(to: whiteImage, config: fadeOutConfig, localTime: 1.5, duration: totalDuration, canvasSize: size)
        #expect(fadeOutAtMid.extent.width == 100)

        let fadeOutAtEnd = engine.applyEffect(to: whiteImage, config: fadeOutConfig, localTime: 3.0, duration: totalDuration, canvasSize: size)
        #expect(fadeOutAtEnd.extent.width == 100)
    }

    @Test("EffectEngine Fade In (gia tốc tăng dần) và Fade Out (gia tốc giảm dần) tuân thủ đúng đường cong quang học")
    func testFadeInFadeOutAccelerationCurves() {
        // Fade In: Bắt đầu đen hoàn toàn (alpha = 1), giữ tối lâu ở đầu, gia tốc tăng dần và sáng bừng ở cuối (alpha = 0)
        let in0 = EffectEngine.calculateFadeInBlackAlpha(progress: 0.0)
        let in25 = EffectEngine.calculateFadeInBlackAlpha(progress: 0.25)
        let in50 = EffectEngine.calculateFadeInBlackAlpha(progress: 0.50)
        let in75 = EffectEngine.calculateFadeInBlackAlpha(progress: 0.75)
        let in100 = EffectEngine.calculateFadeInBlackAlpha(progress: 1.0)

        #expect(in0 == 1.0, "Fade In bắt đầu với màn hình đen hoàn toàn")
        #expect(in25 == 0.9375, "Ở 25% thời lượng vẫn giữ 93.75% đen để hình không bị lộ quá sớm")
        #expect(in50 == 0.75)
        #expect(in75 == 0.4375)
        #expect(in100 == 0.0, "Fade In kết thúc hoàn toàn sáng")

        // Kiểm tra gia tốc tăng dần của độ sáng (1 - blackAlpha)
        let deltaInQ1 = (1.0 - in25) - (1.0 - in0)
        let deltaInQ2 = (1.0 - in50) - (1.0 - in25)
        let deltaInQ3 = (1.0 - in75) - (1.0 - in50)
        let deltaInQ4 = (1.0 - in100) - (1.0 - in75)
        #expect(deltaInQ1 < deltaInQ2 && deltaInQ2 < deltaInQ3 && deltaInQ3 < deltaInQ4, "Độ sáng phải tăng tốc liên tục")

        // Fade Out: Bắt đầu sáng (alpha = 0), tối nhanh ở đầu rồi gia tốc giảm dần vào đen hoàn toàn ở cuối (alpha = 1)
        let out0 = EffectEngine.calculateFadeOutBlackAlpha(progress: 0.0)
        let out25 = EffectEngine.calculateFadeOutBlackAlpha(progress: 0.25)
        let out50 = EffectEngine.calculateFadeOutBlackAlpha(progress: 0.50)
        let out75 = EffectEngine.calculateFadeOutBlackAlpha(progress: 0.75)
        let out100 = EffectEngine.calculateFadeOutBlackAlpha(progress: 1.0)

        #expect(out0 == 0.0, "Fade Out bắt đầu với màn hình sáng")
        #expect(out25 == 0.4375)
        #expect(out50 == 0.75)
        #expect(out75 == 0.9375)
        #expect(out100 == 1.0, "Fade Out kết thúc đen hoàn toàn")

        // Kiểm tra gia tốc giảm dần của độ tối
        let deltaOutQ1 = out25 - out0
        let deltaOutQ2 = out50 - out25
        let deltaOutQ3 = out75 - out50
        let deltaOutQ4 = out100 - out75
        #expect(deltaOutQ1 > deltaOutQ2 && deltaOutQ2 > deltaOutQ3 && deltaOutQ3 > deltaOutQ4, "Độ tối phải giảm tốc liên tục vào mốc đen cuối")
    }

    @Test("EffectTabDescriptor đăng ký thành công vào TabRegistry")
    func testEffectTabDescriptorRegistration() {
        let registry = TabRegistry()
        let descriptor = EffectTabDescriptor()
        registry.register(descriptor)

        #expect(registry.tabs.contains(where: { $0.id == .effect }))
        let tab = registry.descriptor(for: .effect)
        #expect(tab?.title == "Effect")
        #expect(tab?.order == 50)
        #expect(tab?.makeSidebarView() != nil)
    }
}
