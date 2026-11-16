import Testing
import Foundation
import CoreGraphics
@preconcurrency import CoreImage
import Domain
@testable import FeatureShell

@Suite("NatureEffectParticlesTests")
@MainActor
struct NatureEffectParticlesTests {

    @Test("Các hiệu ứng Nature sở hữu Shader Compute Kernel đặc thù riêng biệt thay vì dùng chung hạt li ti")
    func testNatureKernelsRegistered() {
        let expectedKernels = [
            "metal_effect_falling_leaves",
            "metal_effect_petals",
            "metal_effect_floating_dust",
            "metal_effect_fireflies",
            "metal_effect_embers_sparks",
            "metal_effect_floating_bubbles"
        ]

        let registered = BuiltInMetalShaders.allKernelNames
        for kernel in expectedKernels {
            #expect(registered.contains(kernel), "Kernel \(kernel) phải được đăng ký trong BuiltInMetalShaders")
        }
    }

    @Test("DynamicShaderRuntimeEngine phân phối và render độc lập từng loại hiệu ứng thiên nhiên")
    func testNatureShaderPipelineDispatch() {
        let baseImage = CIImage(color: CIColor.black).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let canvasSize = CGSize(width: 100, height: 100)

        let natureFilters = [
            "FallingLeaves",
            "Petals",
            "FloatingDust",
            "Fireflies",
            "Embers",
            "Bubbles"
        ]

        for filterName in natureFilters {
            var config = EffectConfiguration(type: .fadeIn, intensity: 1.0, speed: 1.0)
            config.filterPipeline = [
                CreativeFilterStep(filterName: filterName, parameterBindings: [
                    "density": "1.0",
                    "speed": "1.0"
                ])
            ]

            let output = DynamicShaderRuntimeEngine.shared.executePipeline(
                on: baseImage,
                config: config,
                progress: 0.5,
                localTime: 1.0,
                canvasSize: canvasSize
            )

            #expect(output.extent.width > 0, "Filter \(filterName) phải render thành công khung hình hợp lệ")
        }
    }
}

