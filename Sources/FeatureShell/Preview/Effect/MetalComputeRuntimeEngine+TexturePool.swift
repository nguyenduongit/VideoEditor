import Foundation
import CoreGraphics
import CoreImage
import Metal
import OSLog

/// Mở rộng `MetalComputeRuntimeEngine` quản lý biên dịch thư viện MSL, phân chia threadgroups
/// và bộ đệm xoay vòng tái sử dụng `MTLTexture` (`scratchTexturePool` + `outputTextureRing`).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension MetalComputeRuntimeEngine {

    func compileBuiltInLibrary(with device: MTLDevice) {
        do {
            let options = MTLCompileOptions()
            options.fastMathEnabled = true
            let library = try device.makeLibrary(source: BuiltInMetalShaders.librarySource, options: options)
            for name in BuiltInMetalShaders.allKernelNames {
                if let fn = library.makeFunction(name: name) {
                    pipelineCache[name] = try device.makeComputePipelineState(function: fn)
                }
            }
        } catch {
            logger.error("Không thể biên dịch BuiltInMetalShaders: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resolvePipeline(kernelName: String, customSource: String?) -> MTLComputePipelineState? {
        if let source = customSource, !source.isEmpty {
            return compileCustomKernel(source: source, kernelName: kernelName)
        }
        lock.lock()
        defer { lock.unlock() }
        return pipelineCache[kernelName]
    }

    func encodeThreadgroups(
        encoder: MTLComputeCommandEncoder,
        pipelineState: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let w = max(1, pipelineState.threadExecutionWidth)
        let h = max(1, pipelineState.maxTotalThreadsPerThreadgroup / w)
        let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
        let numGroups = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
        encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
    }

    func makePrivateTexture(width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return device.makeTexture(descriptor: desc)
    }

    func acquireScratchTexture(width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let key = "\(width)x\(height)"
        lock.lock()
        if var bucket = scratchTexturePool[key], let tex = bucket.popLast() {
            scratchTexturePool[key] = bucket
            lock.unlock()
            return tex
        }
        lock.unlock()
        return makePrivateTexture(width: width, height: height, device: device)
    }

    func releaseScratchTexture(_ texture: MTLTexture) {
        let key = "\(texture.width)x\(texture.height)"
        lock.lock()
        defer { lock.unlock() }
        var bucket = scratchTexturePool[key, default: []]
        if bucket.count < 6 {
            bucket.append(texture)
            scratchTexturePool[key] = bucket
        }
    }

    func acquireOutputTexture(width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let key = "\(width)x\(height)"
        let ringCapacity = 8
        lock.lock()
        var ring = outputTextureRing[key] ?? OutputRing()
        if ring.textures.count >= ringCapacity {
            let tex = ring.textures[ring.cursor % ringCapacity]
            ring.cursor = (ring.cursor + 1) % ringCapacity
            outputTextureRing[key] = ring
            lock.unlock()
            return tex
        }
        lock.unlock()

        guard let fresh = makePrivateTexture(width: width, height: height, device: device) else { return nil }
        lock.lock()
        var updated = outputTextureRing[key] ?? OutputRing()
        if updated.textures.count < ringCapacity {
            updated.textures.append(fresh)
            updated.cursor = updated.textures.count % ringCapacity
            outputTextureRing[key] = updated
        }
        lock.unlock()
        return fresh
    }

    func normalizeImage(_ image: CIImage, to localRect: CGRect, canvasRect: CGRect) -> CIImage {
        let cropped = image.clampedToExtent().cropped(to: canvasRect)
        if canvasRect.origin == .zero { return cropped }
        return cropped.transformed(by: CGAffineTransform(translationX: -canvasRect.origin.x, y: -canvasRect.origin.y))
    }

    func makeOutputCIImage(from texture: MTLTexture, localRect: CGRect, targetRect: CGRect) -> CIImage? {
        guard var ciImg = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace]) else { return nil }
        ciImg = ciImg.cropped(to: localRect)
        if targetRect.origin != .zero {
            ciImg = ciImg.transformed(by: CGAffineTransform(translationX: targetRect.origin.x, y: targetRect.origin.y))
        }
        return ciImg.cropped(to: targetRect)
    }
}
