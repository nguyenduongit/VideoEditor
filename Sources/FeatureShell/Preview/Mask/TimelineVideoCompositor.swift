import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Domain
import os

/// Custom video compositor that performs GPU-accelerated layer blending and masking.
/// Complies with R3.1, R9.4, and R9.8 of AGENTS.md.
public final class TimelineVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "TimelineVideoCompositor")
    private let ciContext: CIContext

    public var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    public override init() {
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
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
        Self.logger.notice("startRequest: canvas=\(canvasSize.width)x\(canvasSize.height), layers=\(instruction.layerInfos.count)")
        var canvas = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: canvasSize))

        for info in instruction.layerInfos.reversed() {
            if info.isAdjustment {
                if let config = info.adjustmentConfig, !config.isNeutral {
                    canvas = ColorGradingEngine.shared.applyGrading(to: canvas, config: config, intensity: info.opacity)
                }
                continue
            }

            guard let srcBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: info.trackID) else {
                Self.logger.error("startRequest: failed to get sourceFrame for trackID=\(info.trackID)")
                continue
            }
            let srcHeight = CGFloat(CVPixelBufferGetHeight(srcBuffer))
            let fSrc = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: srcHeight)
            let fDst = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: canvasSize.height)
            let ciTransform = fSrc.concatenating(info.transform).concatenating(fDst)

            var frameImage = CIImage(cvPixelBuffer: srcBuffer)
            frameImage = frameImage.transformed(by: ciTransform)

            if let autoPan = info.autoPanConfig, autoPan.isEnabled, !autoPan.keyframes.isEmpty,
               let clipRange = info.clipTimeRange {
                let compTime = asyncVideoCompositionRequest.compositionTime
                let localTime = CMTimeSubtract(compTime, clipRange.start).seconds
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

            if info.opacity < 1.0 {
                let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, info.opacity)))
                if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: frameImage]) {
                    frameImage = matrix.outputImage ?? frameImage
                }
            }

            if let gridConfig = info.gridConfig, !gridConfig.isDefault {
                frameImage = GridSliceCompositor.applyGrid(to: frameImage, config: gridConfig, canvasSize: canvasSize)
            }

            if let maskParams = info.maskParameters, maskParams.isMaskActive {
                frameImage = TimelineMaskGenerator.applyMask(to: frameImage, params: maskParams, canvasSize: canvasSize)
            }

            canvas = frameImage.composited(over: canvas)
        }

        ciContext.render(canvas, to: dstPixelBuffer)
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: dstPixelBuffer)
    }

    public func cancelAllPendingVideoCompositionRequests() {}
}
