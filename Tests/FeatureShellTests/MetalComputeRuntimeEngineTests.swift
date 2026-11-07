import Testing
import CoreGraphics
import CoreImage
import Domain
@testable import FeatureShell

@Suite("MetalComputeRuntimeEngine Tests")
struct MetalComputeRuntimeEngineTests {
    private let sampleCanvas = CGSize(width: 320, height: 180)

    private func makeTestImage(color: CIColor = CIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1.0)) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(origin: .zero, size: sampleCanvas))
    }

    @Test("All 8 built-in Metal Compute kernels compile on Mac Intel GPU")
    func allBuiltInKernelsCompiled() {
        let engine = MetalComputeRuntimeEngine.shared
        guard engine.isAvailable else { return }

        for kernelName in BuiltInMetalShaders.allKernelNames {
            #expect(
                engine.hasCompiledKernel(named: kernelName),
                "Built-in Metal kernel '\(kernelName)' phải được biên dịch thành công"
            )
        }
    }

    @Test("Single-texture built-in Metal Compute effects execute and preserve canvas extent")
    func singleTextureEffectsExecute() {
        let runtime = DynamicShaderRuntimeEngine.shared
        let inputImage = makeTestImage()
        let expectedRect = CGRect(origin: .zero, size: sampleCanvas)

        let packages: [EffectPreset] = [
            EffectPreset.rgbGlitchPackage,
            EffectPreset.vhsRetroTapePackage,
            EffectPreset.thermalVisionPackage,
            EffectPreset.comicHalftonePackage,
            EffectPreset.pixelRetroArcadePackage,
            EffectPreset.shockwaveRipplePackage
        ]

        for pkg in packages {
            let output = runtime.executePipeline(
                on: inputImage,
                config: pkg.config,
                progress: 0.45,
                localTime: 0.9,
                canvasSize: sampleCanvas
            )
            #expect(output.extent == expectedRect, "Effect '\(pkg.id)' phải giữ nguyên extent \(expectedRect)")
        }
    }

    @Test("Custom MSL source compiles JIT and executes via CreativeFilterStep")
    func customMSLShaderJITExecution() {
        let runtime = DynamicShaderRuntimeEngine.shared
        let inputImage = makeTestImage()
        let expectedRect = CGRect(origin: .zero, size: sampleCanvas)

        let customMSL = """
        #include <metal_stdlib>
        using namespace metal;

        struct MetalEffectUniforms {
            float time; float progress; float intensity; float speed;
            float width; float height;
            float p0; float p1; float p2; float p3;
            float p4; float p5; float p6; float p7;
            float reserved0; float reserved1;
        };

        kernel void custom_tint_boost(
            texture2d<float, access::read> inTex [[texture(0)]],
            texture2d<float, access::write> outTex [[texture(1)]],
            constant MetalEffectUniforms &u [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
            float4 src = inTex.read(gid);
            float3 boosted = clamp(src.rgb * max(0.1, u.p0), 0.0, 1.0);
            outTex.write(float4(boosted, src.a), gid);
        }
        """

        let step = CreativeFilterStep(
            filterName: "CustomTintBoost",
            kernelSource: customMSL,
            metalKernelName: "custom_tint_boost",
            parameterBindings: ["0_boost": "$param.boost * $intensity + 0.2"]
        )
        let config = EffectConfiguration(
            intensity: 1.0,
            speed: 1.0,
            parameterValues: ["boost": 1.3],
            filterPipeline: [step]
        )

        let output = runtime.executePipeline(
            on: inputImage,
            config: config,
            progress: 0.5,
            localTime: 1.0,
            canvasSize: sampleCanvas
        )
        #expect(output.extent == expectedRect)
    }

    @Test("Dual-texture Metal Compute transitions execute across progress 0.0, 0.5, 1.0")
    func dualTextureTransitionsExecute() {
        let runtime = DynamicShaderRuntimeEngine.shared
        let clipA = makeTestImage(color: CIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        let clipB = makeTestImage(color: CIColor(red: 0.1, green: 0.8, blue: 0.4, alpha: 1.0))
        let expectedRect = CGRect(origin: .zero, size: sampleCanvas)

        for kernel in ["metal_transition_cross_warp", "metal_transition_glitch_slice"] {
            for progress in [0.0, 0.5, 1.0] {
                let blended = runtime.executeTransition(
                    from: clipA,
                    to: clipB,
                    kernelName: kernel,
                    progress: progress,
                    warpStrength: 42.0,
                    canvasSize: sampleCanvas
                )
                #expect(blended.extent == expectedRect)
            }
        }
    }

    @Test("Expression evaluator supports addition and multiplication")
    func expressionEvaluatorAdditionAndMultiplication() {
        let runtime = DynamicShaderRuntimeEngine.shared
        let config = EffectConfiguration(
            intensity: 0.5,
            speed: 2.0,
            parameterValues: ["offset": 20.0]
        )

        let val = runtime.evaluateExpression(
            "$param.offset * $intensity + $speed * 3.0",
            config: config,
            progress: 0.25,
            localTime: 1.5
        )
        #expect(abs(val - 16.0) < 0.001)
    }
}

