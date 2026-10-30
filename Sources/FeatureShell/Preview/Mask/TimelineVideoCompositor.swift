import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Domain
import os

/// Custom video compositor that performs GPU-accelerated layer blending and masking.
/// Complies with R3.1, R9.4, and R9.8 of AGENTS.md.
/// Bắt buộc kế thừa NSObject và conform AVVideoCompositing theo hợp đồng Apple AVFoundation; tài nguyên dùng chung được đồng bộ bởi frameCacheLock (R8.3).
public final class TimelineVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "TimelineVideoCompositor")
    private let ciContext: CIContext
    private let colorGradingEngine = ColorGradingEngine()
    private let textRenderer = TextRendererEngine()
    private let effectEngine = EffectEngine()
    private let frameCacheLock = NSLock()
    private var lastFrameByTrackID: [CMPersistentTrackID: CIImage] = [:]

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

        guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? TimelineCustomVideoCompositionInstruction else {
            // Fallback: clear buffer and finish
            let size = asyncVideoCompositionRequest.renderContext.size
            let clearImage = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))
            ciContext.render(clearImage, to: dstPixelBuffer)
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: dstPixelBuffer)
            return
        }

        let canvasSize = instruction.canvasSize
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var canvas = CIImage(color: CIColor.black).cropped(to: canvasRect)

        for info in instruction.layerInfos.reversed() {
            if info.isAdjustment {
                if let config = info.adjustmentConfig, !config.isNeutral {
                    canvas = colorGradingEngine.applyGrading(to: canvas, config: config, intensity: info.opacity)
                        .cropped(to: canvasRect)
                }
                continue
            }

            if info.isEffect {
                if let config = info.effectConfig {
                    let compTime = asyncVideoCompositionRequest.compositionTime
                    let clipStart = info.clipTimeRange?.start ?? .zero
                    let clipDuration = info.clipTimeRange?.duration.seconds ?? 3.0
                    let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
                    canvas = effectEngine.applyEffect(
                        to: canvas,
                        config: config,
                        localTime: localTime,
                        duration: clipDuration,
                        canvasSize: canvasSize
                    ).cropped(to: canvasRect)
                }
                continue
            }

            if info.isText {
                if let config = info.textConfig {
                    let compTime = asyncVideoCompositionRequest.compositionTime
                    let clipStart = info.clipTimeRange?.start ?? .zero
                    let clipDuration = info.clipTimeRange?.duration.seconds ?? 5.0
                    let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
                    if let textImage = textRenderer.renderAnimatedImage(
                        for: config,
                        localTime: localTime,
                        duration: clipDuration,
                        canvasSize: canvasSize
                    ) {
                        canvas = textImage.composited(over: canvas)
                    }
                }
                continue
            }

            if info.isSolidColor {
                let color = info.solidColorHex.flatMap { Self.parseCIColor(hex: $0) } ?? CIColor.black
                var solidImg = CIImage(color: color).cropped(to: canvasRect)
                if info.opacity < 1.0 {
                    let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, info.opacity)))
                    if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: solidImg]) {
                        solidImg = matrix.outputImage ?? solidImg
                    }
                }
                if let maskParams = info.maskParameters, maskParams.isMaskActive {
                    solidImg = TimelineMaskGenerator.applyMask(to: solidImg, params: maskParams, canvasSize: canvasSize)
                }
                canvas = solidImg.composited(over: canvas)
                continue
            }

            if let renderedLayer = renderVideoLayer(
                info: info,
                request: asyncVideoCompositionRequest,
                canvasSize: canvasSize,
                canvasRect: canvasRect
            ) {
                canvas = renderedLayer.composited(over: canvas)
            }
        }

        let renderSize = asyncVideoCompositionRequest.renderContext.size
        if renderSize.width > 0 && renderSize.height > 0 && (renderSize.width != canvasSize.width || renderSize.height != canvasSize.height) {
            let sx = renderSize.width / canvasSize.width
            let sy = renderSize.height / canvasSize.height
            canvas = canvas.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        }

        ciContext.render(canvas, to: dstPixelBuffer)
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: dstPixelBuffer)
    }

    private func renderVideoLayer(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        request: AVAsynchronousVideoCompositionRequest,
        canvasSize: CGSize,
        canvasRect: CGRect
    ) -> CIImage? {
        guard var frameImage = resolveBaseVideoFrame(info: info, request: request, canvasSize: canvasSize) else {
            return nil
        }

        if let autoPan = info.autoPanConfig, autoPan.isEnabled, !autoPan.keyframes.isEmpty,
           let clipRange = info.clipTimeRange {
            let localTime = CMTimeSubtract(request.compositionTime, clipRange.start)
            let panOffset = AutoPanEngine.panOffset(
                at: localTime,
                config: autoPan,
                videoWidth: Double(info.naturalSize.width),
                scale: info.finalScale,
                canvasWidth: Double(canvasSize.width)
            )
            if abs(panOffset) > 0.001 {
                frameImage = frameImage.transformed(by: CGAffineTransform(translationX: CGFloat(panOffset), y: 0.0))
            }
        }

        frameImage = frameImage.cropped(to: canvasRect)

        // Apply Grid/Leg Stretch BEFORE Color Grading so Color Grading runs once instead of 3x per slice
        if let gridConfig = info.gridConfig, !gridConfig.isDefault {
            let localTime = info.clipTimeRange.map { CMTimeSubtract(request.compositionTime, $0.start).seconds } ?? 0.0
            let effectiveGrid = GridSliceEngine.resolvedConfig(
                from: gridConfig,
                at: localTime,
                keyframes: info.autoPanConfig?.keyframes ?? [],
                scaleY: info.userScaleY,
                normalizedOffsetY: info.normalizedOffsetY
            )
            frameImage = GridSliceCompositor.applyGrid(to: frameImage, config: effectiveGrid, canvasSize: canvasSize)
        }

        if let config = info.adjustmentConfig, !config.isNeutral {
            frameImage = colorGradingEngine.applyGrading(to: frameImage, config: config, intensity: 1.0)
                .cropped(to: canvasRect)
        }

        if info.opacity < 1.0 {
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, info.opacity)))
            if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: frameImage]) {
                frameImage = matrix.outputImage ?? frameImage
            }
        }

        if let maskParams = info.maskParameters, maskParams.isMaskActive {
            frameImage = TimelineMaskGenerator.applyMask(to: frameImage, params: maskParams, canvasSize: canvasSize)
        }
        return frameImage
    }

    private func resolveBaseVideoFrame(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        request: AVAsynchronousVideoCompositionRequest,
        canvasSize: CGSize
    ) -> CIImage? {
        if let srcBuffer = request.sourceFrame(byTrackID: info.trackID) {
            let bufW = CGFloat(CVPixelBufferGetWidth(srcBuffer))
            let bufH = CGFloat(CVPixelBufferGetHeight(srcBuffer))
            let rawW = info.rawNaturalSize.width > 0 ? info.rawNaturalSize.width : bufW
            let rawH = info.rawNaturalSize.height > 0 ? info.rawNaturalSize.height : bufH

            var rawImage = CIImage(cvPixelBuffer: srcBuffer)
            if abs(bufW - rawW) > 0.5 || abs(bufH - rawH) > 0.5 {
                rawImage = rawImage.transformed(
                    by: CGAffineTransform(scaleX: rawW / max(1.0, bufW), y: rawH / max(1.0, bufH))
                )
            }
            let fSrc = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: rawH)
            let fDst = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: canvasSize.height)
            let ciTransform = fSrc.concatenating(info.transform).concatenating(fDst)
            let transformed = rawImage.transformed(by: ciTransform)
            storeCachedFrame(transformed, for: info.trackID)
            return transformed
        }
        return loadCachedFrame(for: info.trackID)
    }

    private func storeCachedFrame(_ image: CIImage, for trackID: CMPersistentTrackID) {
        frameCacheLock.lock()
        lastFrameByTrackID[trackID] = image
        frameCacheLock.unlock()
    }

    private func loadCachedFrame(for trackID: CMPersistentTrackID) -> CIImage? {
        frameCacheLock.lock()
        defer { frameCacheLock.unlock() }
        return lastFrameByTrackID[trackID]
    }

    private static func parseCIColor(hex: String) -> CIColor? {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let intVal = UInt64(clean, radix: 16) else { return nil }
        let r = CGFloat((intVal >> 16) & 0xFF) / 255.0
        let g = CGFloat((intVal >> 8) & 0xFF) / 255.0
        let b = CGFloat(intVal & 0xFF) / 255.0
        return CIColor(red: r, green: g, blue: b)
    }

    public func cancelAllPendingVideoCompositionRequests() {}
}
