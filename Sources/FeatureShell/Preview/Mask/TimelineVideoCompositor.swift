import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Domain
import os

/// Custom video compositor that performs GPU-accelerated layer blending, native 2K/4K rasterization,
/// dual-texture transitions, still-image rendering, vector SVG/GIF stickers, text, effects, and masking.
/// Complies with R3.1 (<= 300 lines), R9.4, and R9.8 of AGENTS.md.
/// Bắt buộc kế thừa NSObject và conform AVVideoCompositing theo hợp đồng Apple AVFoundation; tài nguyên dùng chung được đồng bộ bởi frameCacheLock (R8.3).
public final class TimelineVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    static let logger = Logger(subsystem: "com.videoeditor", category: "TimelineVideoCompositor")
    let ciContext: CIContext
    let colorGradingEngine = ColorGradingEngine()
    let textRenderer = TextRendererEngine()
    let stickerRenderer = StickerRendererEngine()
    let effectEngine = EffectEngine()
    let proceduralEngine = ProceduralRenderEngine.shared
    let frameCacheLock = NSLock()
    var lastFrameByTrackID: [CMPersistentTrackID: CIImage] = [:]
    var rawStillImageCache: [URL: CIImage] = [:]

    public var sourcePixelBufferAttributes: [String: any Sendable]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: [
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                kCVPixelFormatType_32BGRA
            ],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    public override init() {
        self.ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false
        ])
        super.init()
    }

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let dstPixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            Self.logger.error("Failed to allocate destination pixel buffer for video composition")
            asyncVideoCompositionRequest.finish(with: NSError(domain: "TimelineVideoCompositor", code: -1))
            return
        }

        let contextSize = asyncVideoCompositionRequest.renderContext.size
        guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? TimelineCustomVideoCompositionInstruction else {
            let clearImage = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: contextSize))
            ciContext.render(clearImage, to: dstPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: dstPixelBuffer)
            return
        }

        let logicalSize = instruction.canvasSize
        let outputSize = (contextSize.width > 0 && contextSize.height > 0) ? contextSize : logicalSize
        let sx = outputSize.width / max(1.0, logicalSize.width)
        let sy = outputSize.height / max(1.0, logicalSize.height)
        let outputRect = CGRect(origin: .zero, size: outputSize)
        var canvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: outputRect)
        let compTime = asyncVideoCompositionRequest.compositionTime

        for rawInfo in instruction.layerInfos.reversed() {
            let info = resolvedLayerInfo(rawInfo, at: compTime, canvasSize: logicalSize)
            canvas = compositeSingleLayer(
                info: info,
                over: canvas,
                request: asyncVideoCompositionRequest,
                logicalSize: logicalSize,
                outputSize: outputSize,
                outputRect: outputRect,
                sx: sx,
                sy: sy
            )
        }

        let finalCanvas = canvas.composited(over: CIImage(color: CIColor.black).cropped(to: outputRect))
        ciContext.render(finalCanvas, to: dstPixelBuffer, bounds: outputRect, colorSpace: CGColorSpaceCreateDeviceRGB())
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: dstPixelBuffer)
    }

    func storeCachedFrame(_ image: CIImage, for trackID: CMPersistentTrackID) {
        frameCacheLock.lock()
        lastFrameByTrackID[trackID] = image
        frameCacheLock.unlock()
    }

    func loadCachedFrame(for trackID: CMPersistentTrackID) -> CIImage? {
        frameCacheLock.lock()
        defer { frameCacheLock.unlock() }
        return lastFrameByTrackID[trackID]
    }

    func loadRawStillImage(for url: URL) -> CIImage? {
        frameCacheLock.lock()
        if let cached = rawStillImageCache[url] {
            frameCacheLock.unlock()
            return cached
        }
        frameCacheLock.unlock()

        guard let loaded = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            return nil
        }
        frameCacheLock.lock()
        if rawStillImageCache.count >= 32 {
            rawStillImageCache.removeAll(keepingCapacity: true)
        }
        rawStillImageCache[url] = loaded
        frameCacheLock.unlock()
        return loaded
    }

    static func parseCIColor(hex: String) -> CIColor? {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let intVal = UInt64(clean, radix: 16) else { return nil }
        let r = CGFloat((intVal >> 16) & 0xFF) / 255.0
        let g = CGFloat((intVal >> 8) & 0xFF) / 255.0
        let b = CGFloat(intVal & 0xFF) / 255.0
        return CIColor(red: r, green: g, blue: b)
    }

    public func cancelAllPendingVideoCompositionRequests() {}
}
