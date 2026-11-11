import Foundation
import CoreGraphics
import CoreImage
import Metal
import OSLog

/// Lõi thực thi Metal Compute Pipeline (GPU Compute Shader Engine) tối ưu cho Mac Intel (`x86_64`) & Apple Silicon.
/// Tái sử dụng `scratchTexturePool` (input) và `outputTextureRing` (vòng quay 8-slot cho `outTex` tránh cấp phát VRAM mỗi frame).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R8.3 (Thread-safe).
public final class MetalComputeRuntimeEngine: @unchecked Sendable {
    public static let shared = MetalComputeRuntimeEngine()

    struct OutputRing {
        var textures: [MTLTexture] = []
        var cursor: Int = 0
    }

    let logger = Logger(subsystem: "VideoEditor", category: "MetalComputeRuntimeEngine")
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let ciContext: CIContext?
    let colorSpace: CGColorSpace

    let lock = NSLock()
    var pipelineCache: [String: MTLComputePipelineState] = [:]
    var scratchTexturePool: [String: [MTLTexture]] = [:]
    var outputTextureRing: [String: OutputRing] = [:]

    public init() {
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        self.colorSpace = rgbSpace

        guard let mtlDevice = MTLCreateSystemDefaultDevice(),
              let queue = mtlDevice.makeCommandQueue() else {
            self.device = nil
            self.commandQueue = nil
            self.ciContext = nil
            logger.error("Không thể khởi tạo MTLDevice hoặc MTLCommandQueue trên hệ thống này.")
            return
        }

        self.device = mtlDevice
        self.commandQueue = queue
        self.ciContext = CIContext(
            mtlCommandQueue: queue,
            options: [.workingColorSpace: rgbSpace, .outputColorSpace: rgbSpace, .cacheIntermediates: false]
        )
        compileBuiltInLibrary(with: mtlDevice)
    }

    public var isAvailable: Bool {
        device != nil && commandQueue != nil && ciContext != nil
    }

    public func hasCompiledKernel(named name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pipelineCache[name] != nil
    }

    @discardableResult
    public func compileCustomKernel(source: String, kernelName: String) -> MTLComputePipelineState? {
        guard let device else { return nil }
        let cacheKey = "\(kernelName)::\(source.hashValue)"
        lock.lock()
        if let cached = pipelineCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        do {
            let options = MTLCompileOptions()
            options.fastMathEnabled = true
            let library = try device.makeLibrary(source: source, options: options)
            guard let function = library.makeFunction(name: kernelName) else {
                logger.error("Không tìm thấy hàm kernel '\(kernelName, privacy: .public)' trong MSL source.")
                return nil
            }
            let state = try device.makeComputePipelineState(function: function)
            lock.lock()
            pipelineCache[cacheKey] = state
            lock.unlock()
            return state
        } catch {
            logger.error("Lỗi biên dịch JIT Metal kernel '\(kernelName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func dispatchEffect(
        kernelName: String,
        customSource: String? = nil,
        on image: CIImage,
        uniforms: MetalEffectUniforms,
        canvasRect: CGRect
    ) -> CIImage {
        guard let device, let commandQueue, let ciContext,
              let pipelineState = resolvePipeline(kernelName: kernelName, customSource: customSource) else { return image }

        let width = max(1, Int(canvasRect.width.rounded()))
        let height = max(1, Int(canvasRect.height.rounded()))
        let localRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let inTex = acquireScratchTexture(width: width, height: height, device: device),
              let outTex = acquireOutputTexture(width: width, height: height, device: device),
              let cmdBuffer = commandQueue.makeCommandBuffer() else { return image }
        defer { releaseScratchTexture(inTex) }

        let alignedInput = normalizeImage(image, to: localRect, canvasRect: canvasRect)
        ciContext.render(alignedInput, to: inTex, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)

        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return image }
        var localUniforms = uniforms
        localUniforms.width = Float(width)
        localUniforms.height = Float(height)
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inTex, index: 0)
        encoder.setTexture(outTex, index: 1)
        encoder.setBytes(&localUniforms, length: MemoryLayout<MetalEffectUniforms>.stride, index: 0)
        encodeThreadgroups(encoder: encoder, pipelineState: pipelineState, width: width, height: height)
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        return makeOutputCIImage(from: outTex, localRect: localRect, targetRect: canvasRect) ?? image
    }

    public func dispatchRawCompute(
        kernelName: String,
        on image: CIImage,
        uniformFloats: [Float],
        canvasRect: CGRect
    ) -> CIImage {
        guard !uniformFloats.isEmpty,
              let device, let commandQueue, let ciContext,
              let pipelineState = resolvePipeline(kernelName: kernelName, customSource: nil) else { return image }

        let width = max(1, Int(canvasRect.width.rounded()))
        let height = max(1, Int(canvasRect.height.rounded()))
        let localRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let inTex = acquireScratchTexture(width: width, height: height, device: device),
              let outTex = acquireOutputTexture(width: width, height: height, device: device),
              let cmdBuffer = commandQueue.makeCommandBuffer() else { return image }
        defer { releaseScratchTexture(inTex) }

        let alignedInput = normalizeImage(image, to: localRect, canvasRect: canvasRect)
        ciContext.render(alignedInput, to: inTex, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)

        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return image }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inTex, index: 0)
        encoder.setTexture(outTex, index: 1)
        uniformFloats.withUnsafeBytes { rawBuf in
            if let base = rawBuf.baseAddress {
                encoder.setBytes(base, length: rawBuf.count, index: 0)
            }
        }
        encodeThreadgroups(encoder: encoder, pipelineState: pipelineState, width: width, height: height)
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        return makeOutputCIImage(from: outTex, localRect: localRect, targetRect: canvasRect) ?? image
    }

    public func dispatchTransition(
        kernelName: String,
        customSource: String? = nil,
        from fromImage: CIImage,
        to toImage: CIImage,
        uniforms: MetalEffectUniforms,
        canvasRect: CGRect
    ) -> CIImage {
        guard let device, let commandQueue, let ciContext,
              let pipelineState = resolvePipeline(kernelName: kernelName, customSource: customSource) else { return toImage }

        let width = max(1, Int(canvasRect.width.rounded()))
        let height = max(1, Int(canvasRect.height.rounded()))
        let localRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let fromTex = acquireScratchTexture(width: width, height: height, device: device),
              let toTex = acquireScratchTexture(width: width, height: height, device: device),
              let outTex = acquireOutputTexture(width: width, height: height, device: device),
              let cmdBuffer = commandQueue.makeCommandBuffer() else { return toImage }
        defer {
            releaseScratchTexture(fromTex)
            releaseScratchTexture(toTex)
        }

        let alignedFrom = normalizeImage(fromImage, to: localRect, canvasRect: canvasRect)
        let alignedTo = normalizeImage(toImage, to: localRect, canvasRect: canvasRect)
        ciContext.render(alignedFrom, to: fromTex, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)
        ciContext.render(alignedTo, to: toTex, commandBuffer: cmdBuffer, bounds: localRect, colorSpace: colorSpace)

        guard let encoder = cmdBuffer.makeComputeCommandEncoder() else { return toImage }
        var localUniforms = uniforms
        localUniforms.width = Float(width)
        localUniforms.height = Float(height)
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(fromTex, index: 0)
        encoder.setTexture(toTex, index: 1)
        encoder.setTexture(outTex, index: 2)
        encoder.setBytes(&localUniforms, length: MemoryLayout<MetalEffectUniforms>.stride, index: 0)
        encodeThreadgroups(encoder: encoder, pipelineState: pipelineState, width: width, height: height)
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        return makeOutputCIImage(from: outTex, localRect: localRect, targetRect: canvasRect) ?? toImage
    }

    public func renderCGImage(from image: CIImage, rect: CGRect) -> CGImage? {
        guard let ciContext else { return nil }
        return ciContext.createCGImage(image, from: rect, format: .RGBA8, colorSpace: colorSpace)
    }
}
