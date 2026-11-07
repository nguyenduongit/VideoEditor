import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import Domain

/// Mở rộng `TimelineVideoCompositor` kết xuất từng loại Layer ở đúng độ phân giải đích (`1080p / 2K / 4K`),
/// bảo toàn Premultiplied Alpha Opacity và hỗ trợ `.video`, `.image`, `.sticker`, `.text`, `.effect`, `.adjustment`, `CutTransition`.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TimelineVideoCompositor {

    func compositeSingleLayer(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        over canvas: CIImage,
        request: AVAsynchronousVideoCompositionRequest,
        logicalSize: CGSize,
        outputSize: CGSize,
        outputRect: CGRect,
        sx: CGFloat,
        sy: CGFloat
    ) -> CIImage {
        let compTime = request.compositionTime

        if let transInfo = info.activeTransition {
            if let blended = renderActiveTransition(
                transInfo,
                request: request,
                logicalSize: logicalSize,
                outputSize: outputSize,
                outputRect: outputRect,
                sx: sx,
                sy: sy
            ) {
                return blended.composited(over: canvas)
            }
            return canvas
        }

        if info.isAdjustment {
            if let config = info.adjustmentConfig, !config.isNeutral {
                return colorGradingEngine.applyGrading(to: canvas, config: config, intensity: info.opacity)
                    .cropped(to: outputRect)
            }
            return canvas
        }

        if info.isEffect, let config = info.effectConfig {
            let clipStart = info.clipTimeRange?.start ?? .zero
            let clipDuration = info.clipTimeRange?.duration.seconds ?? 3.0
            let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
            return effectEngine.applyEffect(
                to: canvas,
                config: config,
                localTime: localTime,
                duration: clipDuration,
                canvasSize: outputSize
            ).cropped(to: outputRect)
        }

        if info.isText, let config = info.textConfig {
            let clipStart = info.clipTimeRange?.start ?? .zero
            let clipDuration = info.clipTimeRange?.duration.seconds ?? 5.0
            let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
            let scaledCfg = scaleTextConfigForOutput(config, sx: Double(sx), sy: Double(sy))
            return textRenderer.composite(
                config: scaledCfg,
                over: canvas,
                localTime: localTime,
                duration: clipDuration,
                canvasSize: outputSize
            ).cropped(to: outputRect)
        }

        if info.isSticker, let config = info.stickerConfig {
            let clipStart = info.clipTimeRange?.start ?? .zero
            let clipDuration = info.clipTimeRange?.duration.seconds ?? 3.0
            let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
            let resolvedProps = resolvedClipProperties(for: info, at: compTime)
            return stickerRenderer.composite(
                config: config,
                clipProperties: resolvedProps,
                over: canvas,
                localTime: localTime,
                duration: clipDuration,
                canvasSize: outputSize
            )
        }

        if info.isProcedural, let config = info.proceduralConfig {
            return compositeProceduralLayer(info: info, config: config, over: canvas, compTime: compTime, outputSize: outputSize, sx: sx, sy: sy)
        }

        if info.isSolidColor {
            let color = info.solidColorHex.flatMap { Self.parseCIColor(hex: $0) } ?? CIColor.black
            var solidImg = CIImage(color: color).cropped(to: outputRect)
            if info.opacity < 1.0 {
                solidImg = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(info.opacity), to: solidImg)
            }
            if let maskParams = info.maskParameters, maskParams.isMaskActive {
                let scaledMask = maskParams.scaled(sx: Double(sx), sy: Double(sy))
                solidImg = TimelineMaskGenerator.applyMask(to: solidImg, params: scaledMask, canvasSize: outputSize)
            }
            return solidImg.composited(over: canvas)
        }

        if let renderedLayer = renderVideoOrStillLayer(
            info: info,
            request: request,
            logicalSize: logicalSize,
            outputSize: outputSize,
            outputRect: outputRect,
            sx: sx,
            sy: sy
        ) {
            return renderedLayer.composited(over: canvas)
        }
        return canvas
    }

    private func compositeProceduralLayer(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        config: ProceduralConfiguration,
        over canvas: CIImage,
        compTime: CMTime,
        outputSize: CGSize,
        sx: CGFloat,
        sy: CGFloat
    ) -> CIImage {
        let clipStart = info.clipTimeRange?.start ?? .zero
        let clipDuration = max(0.1, (info.clipTimeRange?.duration ?? CMTime(seconds: 5.0, preferredTimescale: 600)).seconds)
        let localTime = max(0.0, CMTimeSubtract(compTime, clipStart).seconds)
        guard var procImage = proceduralEngine.render(
            config: config,
            localTime: localTime,
            duration: clipDuration,
            canvasSize: outputSize
        ) else {
            return canvas
        }
        if let maskParams = info.maskParameters, maskParams.isMaskActive {
            let scaledMask = maskParams.scaled(sx: Double(sx), sy: Double(sy))
            procImage = TimelineMaskGenerator.applyMask(to: procImage, params: scaledMask, canvasSize: outputSize)
        }
        return ProceduralRenderEngine.applyBlend(
            foreground: procImage,
            over: canvas,
            blendMode: config.blendMode,
            opacity: info.opacity
        )
    }

    func renderVideoOrStillLayer(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        request: AVAsynchronousVideoCompositionRequest,
        logicalSize: CGSize,
        outputSize: CGSize,
        outputRect: CGRect,
        sx: CGFloat,
        sy: CGFloat
    ) -> CIImage? {
        guard var frameImage = resolveBaseFrame(info: info, request: request, outputSize: outputSize, sx: sx, sy: sy) else {
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
                canvasWidth: Double(logicalSize.width)
            )
            if abs(panOffset) > 0.001 {
                frameImage = frameImage.transformed(by: CGAffineTransform(translationX: CGFloat(panOffset) * sx, y: 0.0))
            }
        }

        frameImage = frameImage.cropped(to: outputRect)

        if let gridConfig = info.gridConfig, !gridConfig.isDefault {
            let localTime = info.clipTimeRange.map { CMTimeSubtract(request.compositionTime, $0.start).seconds } ?? 0.0
            let effectiveGrid = GridSliceEngine.resolvedConfig(
                from: gridConfig,
                at: localTime,
                keyframes: info.autoPanConfig?.keyframes ?? [],
                scaleY: info.userScaleY,
                normalizedOffsetY: info.normalizedOffsetY
            )
            frameImage = GridSliceCompositor.applyGrid(to: frameImage, config: effectiveGrid, canvasSize: outputSize)
        }

        if let config = info.adjustmentConfig, !config.isNeutral {
            frameImage = colorGradingEngine.applyGrading(to: frameImage, config: config, intensity: 1.0)
                .cropped(to: outputRect)
        }

        if info.opacity < 1.0 {
            frameImage = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(info.opacity), to: frameImage)
        }

        if let maskParams = info.maskParameters, maskParams.isMaskActive {
            let scaledMask = maskParams.scaled(sx: Double(sx), sy: Double(sy))
            frameImage = TimelineMaskGenerator.applyMask(to: frameImage, params: scaledMask, canvasSize: outputSize)
        }
        return frameImage
    }

    private func resolveBaseFrame(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        request: AVAsynchronousVideoCompositionRequest,
        outputSize: CGSize,
        sx: CGFloat,
        sy: CGFloat
    ) -> CIImage? {
        if info.isStillImage {
            guard let url = info.stillImageURL, var rawImage = loadRawStillImage(for: url) else { return nil }
            let ext = rawImage.extent
            if ext.origin != .zero {
                rawImage = rawImage.transformed(by: CGAffineTransform(translationX: -ext.origin.x, y: -ext.origin.y))
            }
            let rawH = info.rawNaturalSize.height > 0 ? info.rawNaturalSize.height : ext.height
            let fSrc = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: rawH)
            let fScale = CGAffineTransform(scaleX: sx, y: sy)
            let fDst = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: outputSize.height)
            let ciTransform = fSrc.concatenating(info.transform).concatenating(fScale).concatenating(fDst)
            return rawImage.transformed(by: ciTransform)
        }

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
            let fScale = CGAffineTransform(scaleX: sx, y: sy)
            let fDst = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: outputSize.height)
            let ciTransform = fSrc.concatenating(info.transform).concatenating(fScale).concatenating(fDst)
            let transformed = rawImage.transformed(by: ciTransform)
            storeCachedFrame(transformed, for: info.trackID)
            return transformed
        }
        return loadCachedFrame(for: info.trackID)
    }

    func renderActiveTransition(
        _ transInfo: TimelineCustomVideoCompositionInstruction.ActiveTransitionRenderInfo,
        request: AVAsynchronousVideoCompositionRequest,
        logicalSize: CGSize,
        outputSize: CGSize,
        outputRect: CGRect,
        sx: CGFloat,
        sy: CGFloat
    ) -> CIImage? {
        let compTime = request.compositionTime
        let resolvedFrom = resolvedLayerInfo(transInfo.fromLayerInfo, at: compTime, canvasSize: logicalSize)
        let resolvedTo = resolvedLayerInfo(transInfo.toLayerInfo, at: compTime, canvasSize: logicalSize)

        let fromImg = renderVideoOrStillLayer(
            info: resolvedFrom,
            request: request,
            logicalSize: logicalSize,
            outputSize: outputSize,
            outputRect: outputRect,
            sx: sx,
            sy: sy
        ) ?? CIImage(color: .black).cropped(to: outputRect)

        let toImg = renderVideoOrStillLayer(
            info: resolvedTo,
            request: request,
            logicalSize: logicalSize,
            outputSize: outputSize,
            outputRect: outputRect,
            sx: sx,
            sy: sy
        ) ?? CIImage(color: .black).cropped(to: outputRect)

        let durSec = max(0.01, transInfo.windowRange.duration.seconds)
        let rawProgress = max(0.0, min(1.0, CMTimeSubtract(compTime, transInfo.windowRange.start).seconds / durSec))
        return executeTransitionBlend(
            fromImage: fromImg,
            toImage: toImg,
            transition: transInfo.transition,
            rawProgress: rawProgress,
            canvasSize: outputSize,
            canvasRect: outputRect
        )
    }
}
