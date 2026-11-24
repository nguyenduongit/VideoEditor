import Foundation
import CoreGraphics
import CoreImage
import Metal

/// Describes one Metal Compute shader pass executed inside a single batched command buffer.
public struct MetalTransparentPass: @unchecked Sendable {
    public let kernelName: String
    public let uniforms: MetalEffectUniforms
    public let secondaryTexture: MTLTexture?

    public init(
        kernelName: String,
        uniforms: MetalEffectUniforms,
        secondaryTexture: MTLTexture? = nil
    ) {
        self.kernelName = kernelName
        self.uniforms = uniforms
        self.secondaryTexture = secondaryTexture
    }
}

/// Extension on `MetalComputeRuntimeEngine` for alpha-safe transparent overlay kernels, batched GPU chains, and Glyph SDF generation.
extension MetalComputeRuntimeEngine {
    public func dispatchTransparentEffect(
        kernelName: String,
        on image: CIImage,
        uniforms: MetalEffectUniforms,
        canvasRect: CGRect
    ) -> CIImage {
        dispatchTransparentEffectChain(
            passes: [MetalTransparentPass(kernelName: kernelName, uniforms: uniforms)],
            on: image,
            canvasRect: canvasRect
        )
    }

    /// Executes an ordered sequence of transparent compute passes inside a single `MTLCommandBuffer`
    /// using GPU-to-GPU ping-pong textures, eliminating intermediate CPU sync stalls and CIImage roundtrips.
    public func dispatchTransparentEffectChain(
        passes: [MetalTransparentPass],
        on image: CIImage,
        canvasRect: CGRect
    ) -> CIImage {
        guard !passes.isEmpty, let device, let commandQueue, let ciContext else { return image }
        let resolvedPasses: [(state: MTLComputePipelineState, pass: MetalTransparentPass)] = passes.compactMap { pass in
            guard let state = resolvePipeline(kernelName: pass.kernelName, customSource: nil) else { return nil }
            return (state, pass)
        }
        guard resolvedPasses.count == passes.count else { return image }

        let width = max(1, Int(canvasRect.width.rounded()))
        let height = max(1, Int(canvasRect.height.rounded()))
        let localRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let scratchTex = acquireScratchTexture(width: width, height: height, device: device),
              let outTex = acquireOutputTexture(width: width, height: height, device: device),
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            return image
        }
        defer { releaseScratchTexture(scratchTex) }

        let shifted = canvasRect.origin == .zero
            ? image
            : image.transformed(by: CGAffineTransform(translationX: -canvasRect.origin.x, y: -canvasRect.origin.y))
        let aligned = shifted.cropped(to: localRect).composited(over: CIImage.clear.cropped(to: localRect)).cropped(to: localRect)

        // Odd pass count starts in scratchTex so the final pass always lands directly in outTex.
        var currentInput: MTLTexture = (resolvedPasses.count % 2 == 1) ? scratchTex : outTex
        var currentOutput: MTLTexture = (resolvedPasses.count % 2 == 1) ? outTex : scratchTex
        ciContext.render(aligned, to: currentInput, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)

        for item in resolvedPasses {
            guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return image }
            var u = item.pass.uniforms
            u.width = Float(width)
            u.height = Float(height)
            encoder.setComputePipelineState(item.state)
            encoder.setTexture(currentInput, index: 0)
            encoder.setTexture(currentOutput, index: 1)
            if let secondary = item.pass.secondaryTexture {
                encoder.setTexture(secondary, index: 2)
            }
            encoder.setBytes(&u, length: MemoryLayout<MetalEffectUniforms>.stride, index: 0)
            encodeThreadgroups(encoder: encoder, pipelineState: item.state, width: width, height: height)
            encoder.endEncoding()
            swap(&currentInput, &currentOutput)
        }

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        return makeOutputCIImage(from: outTex, localRect: localRect, targetRect: canvasRect) ?? image
    }

    /// Uploads a tightly cropped RGBA glyph `CIImage` into a private GPU texture and builds its `.rgba16Float`
    /// Signed Distance Field (`signedDistPx, normalX, normalY, alpha`) in a single GPU command buffer.
    public func buildGlyphTexturesWithSDF(
        from image: CIImage,
        pixelSize: CGSize,
        jfaMaxStride: Int = 32
    ) -> (colorTexture: MTLTexture, sdfTexture: MTLTexture, colorCIImage: CIImage)? {
        guard let device, let commandQueue, let ciContext,
              let seedState = resolvePipeline(kernelName: "metal_text_sdf_seed", customSource: nil),
              let jfaState = resolvePipeline(kernelName: "metal_text_sdf_jfa_step", customSource: nil),
              let finState = resolvePipeline(kernelName: "metal_text_sdf_finalize", customSource: nil) else {
            return nil
        }

        let width = max(4, min(4096, Int(pixelSize.width.rounded())))
        let height = max(4, min(4096, Int(pixelSize.height.rounded())))
        let localRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let colorTex = makePrivateTexture(width: width, height: height, device: device, pixelFormat: .rgba8Unorm),
              let seedA = makePrivateTexture(width: width, height: height, device: device, pixelFormat: .rgba16Float),
              let seedB = makePrivateTexture(width: width, height: height, device: device, pixelFormat: .rgba16Float),
              let sdfTex = makePrivateTexture(width: width, height: height, device: device, pixelFormat: .rgba16Float),
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }

        let shifted = image.extent.origin == .zero
            ? image
            : image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
        let aligned = shifted.cropped(to: localRect).composited(over: CIImage.clear.cropped(to: localRect)).cropped(to: localRect)
        ciContext.render(aligned, to: colorTex, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)

        var uniform = MetalEffectUniforms(width: Float(width), height: Float(height))
        encodeSDFPass(state: seedState, tex0: colorTex, tex1: seedA, tex2: nil, uniforms: uniform, cmdBuffer: cmdBuffer, width: width, height: height)

        var srcSeed = seedA
        var dstSeed = seedB
        var stride = max(1, jfaMaxStride)
        while stride >= 1 {
            uniform.p0 = Float(stride)
            encodeSDFPass(state: jfaState, tex0: srcSeed, tex1: dstSeed, tex2: nil, uniforms: uniform, cmdBuffer: cmdBuffer, width: width, height: height)
            swap(&srcSeed, &dstSeed)
            if stride == 1 { break }
            stride = max(1, stride / 2)
        }

        encodeSDFPass(state: finState, tex0: srcSeed, tex1: sdfTex, tex2: colorTex, uniforms: uniform, cmdBuffer: cmdBuffer, width: width, height: height)
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        guard let outCI = CIImage(mtlTexture: colorTex, options: [.colorSpace: colorSpace])?.cropped(to: localRect) else {
            return nil
        }
        return (colorTex, sdfTex, outCI)
    }

    private func encodeSDFPass(
        state: MTLComputePipelineState,
        tex0: MTLTexture,
        tex1: MTLTexture,
        tex2: MTLTexture?,
        uniforms: MetalEffectUniforms,
        cmdBuffer: MTLCommandBuffer,
        width: Int,
        height: Int
    ) {
        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return }
        var localU = uniforms
        encoder.setComputePipelineState(state)
        encoder.setTexture(tex0, index: 0)
        encoder.setTexture(tex1, index: 1)
        if let tex2 { encoder.setTexture(tex2, index: 2) }
        encoder.setBytes(&localU, length: MemoryLayout<MetalEffectUniforms>.stride, index: 0)
        encodeThreadgroups(encoder: encoder, pipelineState: state, width: width, height: height)
        encoder.endEncoding()
    }
}
