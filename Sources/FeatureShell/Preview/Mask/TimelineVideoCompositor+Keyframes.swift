import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import CoreImage
import Domain

/// Extension trên `TimelineVideoCompositor` đảm nhiệm nội suy Keyframe 60fps, tỷ lệ hóa Text 2K/4K và cầu nối Transition.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Function <= 50 dòng) của AGENTS.md.
extension TimelineVideoCompositor {

    func resolvedClipProperties(
        for info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        at compositionTime: CMTime
    ) -> [String: PropertyValue] {
        guard let clip = info.clip else { return [:] }
        guard let kfMap = ClipKeyframeMap.from(clip: clip), !kfMap.isEmpty else {
            return clip.properties
        }
        let clipStart = info.clipTimeRange?.start ?? clip.timeRange.start
        let localTime = max(0.0, CMTimeSubtract(compositionTime, clipStart).seconds)
        return KeyframeEvaluator.resolvedProperties(baseProperties: clip.properties, atLocalTime: localTime)
    }

    func scaleTextConfigForOutput(_ config: TextConfiguration, sx: Double, sy: Double) -> TextConfiguration {
        guard abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 else { return config }
        var c = config
        let s = min(sx, sy)
        c.fontSize *= s
        c.characterSpacing *= sx
        c.positionX *= sx
        c.positionY *= sy
        c.innerStroke.width = min(40.0, c.innerStroke.width * s)
        c.outerStroke.width = min(40.0, c.outerStroke.width * s)
        c.glow.range = min(50.0, c.glow.range * s)
        c.shadow.blur = min(50.0, c.shadow.blur * s)
        c.shadow.distance = min(80.0, c.shadow.distance * s)
        c.curve.radiusOffset *= s
        c.curve.waveAmplitude *= sy
        c.curve.wavelength *= sx
        c.background.paddingX *= sx
        c.background.paddingY *= sy
        c.background.cornerRadius *= s
        c.background.borderWidth *= s
        c.background.featherRadius *= s
        c.background.shadowBlur *= s
        c.background.shadowDistance *= s
        c.background.customWidth *= sx
        c.background.customHeight *= sy
        c.background.offsetX *= sx
        c.background.offsetY *= sy
        return c
    }

    func executeTransitionBlend(
        fromImage: CIImage,
        toImage: CIImage,
        transition: CutTransition,
        rawProgress: Double,
        canvasSize: CGSize,
        canvasRect: CGRect
    ) -> CIImage {
        let easedProgress = transition.easing.apply(to: rawProgress)
        if MetalComputeRuntimeEngine.shared.isAvailable {
            let params = resolveTransitionUniformSlots(for: transition)
            return DynamicShaderRuntimeEngine.shared.executeTransition(
                from: fromImage,
                to: toImage,
                kernelName: transition.shaderType.metalKernelName,
                customSource: transition.customMetalSource,
                progress: easedProgress,
                parameters: params,
                canvasSize: canvasSize
            ).cropped(to: canvasRect)
        }
        let p = CGFloat(max(0.0, min(1.0, easedProgress)))
        let inv = 1.0 - p
        let fadedFrom = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(inv), to: fromImage)
        let fadedTo = TextSVGAndAssetCache.applyPremultipliedOpacity(Double(p), to: toImage)
        return fadedTo.composited(over: fadedFrom).cropped(to: canvasRect)
    }

    private func resolveTransitionUniformSlots(for transition: CutTransition) -> [Float] {
        let v = transition.parameterValues
        if let custom = transition.customMetalSource, !custom.isEmpty {
            return v.keys.sorted().prefix(8).compactMap { v[$0].map(Float.init) }
        }
        switch transition.shaderType {
        case .dissolve:
            return [Float(v["gammaCurve"] ?? 1.0)]
        case .directionalPush:
            return [Float(v["dirX"] ?? -1.0), Float(v["dirY"] ?? 0.0)]
        case .whipPanLeft:
            return [-1.0, Float(v["blurStrength"] ?? 1.0)]
        case .whipPanRight:
            return [1.0, Float(v["blurStrength"] ?? 1.0)]
        case .zoomBlur:
            return [Float(v["zoomStrength"] ?? 0.38)]
        case .crossWarp:
            return [Float(v["warpStrength"] ?? 48.0)]
        case .glitchWipe:
            return [Float(v["sliceIntensity"] ?? 90.0)]
        case .lightLeak:
            return [Float(v["flareIntensity"] ?? 1.0), Float(v["warmth"] ?? 0.85)]
        case .geometricWipe:
            return [Float(v["shapeMode"] ?? 0.0), Float(v["feather"] ?? 0.06)]
        }
    }

    func resolvedLayerInfo(
        _ info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        at compositionTime: CMTime,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        guard let clip = info.clip,
              let kfMap = ClipKeyframeMap.from(clip: clip),
              !kfMap.isEmpty else {
            return info
        }
        let clipStart = info.clipTimeRange?.start ?? clip.timeRange.start
        let localTime = max(0.0, CMTimeSubtract(compositionTime, clipStart).seconds)
        let resolvedProps = KeyframeEvaluator.resolvedProperties(
            baseProperties: clip.properties,
            atLocalTime: localTime
        )

        var resolvedClip = clip
        resolvedClip.properties = resolvedProps

        if info.isText {
            return resolveTextKeyframes(info: info, resolvedProps: resolvedProps)
        }
        if info.isSticker {
            return resolveStickerKeyframes(info: info, resolvedClip: resolvedClip, resolvedProps: resolvedProps)
        }
        if info.isEffect {
            return resolveEffectKeyframes(info: info, resolvedProps: resolvedProps)
        }
        if info.isAdjustment {
            return resolveAdjustmentKeyframes(info: info, resolvedProps: resolvedProps)
        }
        return resolveVideoOrImageKeyframes(
            info: info,
            resolvedClip: resolvedClip,
            resolvedProps: resolvedProps,
            canvasSize: canvasSize
        )
    }

    private func resolveStickerKeyframes(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        resolvedClip: TimelineClip,
        resolvedProps: [String: PropertyValue]
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        let opacity = Float(resolvedProps["opacity"]?.asNumber ?? Double(info.opacity))
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: info.trackID,
            transform: info.transform,
            opacity: opacity,
            maskParameters: info.maskParameters,
            clipTimeRange: info.clipTimeRange,
            isSticker: true,
            stickerConfig: info.stickerConfig,
            clip: resolvedClip
        )
    }

    private func resolveTextKeyframes(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        resolvedProps: [String: PropertyValue]
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        var config = info.textConfig ?? TextConfiguration()
        if let px = resolvedProps["positionX"]?.asNumber { config.positionX = px }
        if let py = resolvedProps["positionY"]?.asNumber { config.positionY = py }
        if let s = resolvedProps["scale"]?.asNumber { config.scale = s }
        if let r = resolvedProps["rotation"]?.asNumber { config.rotation = r }
        if let op = resolvedProps["opacity"]?.asNumber { config.opacity = op }
        if let size = resolvedProps["fontSize"]?.asNumber { config.fontSize = size }
        let opacity = Float(resolvedProps["opacity"]?.asNumber ?? Double(info.opacity))

        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: info.trackID,
            transform: info.transform,
            opacity: opacity,
            maskParameters: info.maskParameters,
            clipTimeRange: info.clipTimeRange,
            isText: true,
            textConfig: config,
            clip: info.clip
        )
    }

    private func resolveEffectKeyframes(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        resolvedProps: [String: PropertyValue]
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        var config = info.effectConfig ?? EffectConfiguration()
        if let intensity = resolvedProps["intensity"]?.asNumber { config.intensity = intensity }
        if let speed = resolvedProps["effectSpeed"]?.asNumber ?? resolvedProps["speed"]?.asNumber { config.speed = speed }
        if let blur = resolvedProps["blurRadius"]?.asNumber { config.blurRadius = blur }
        for param in config.customParameters {
            if let v = resolvedProps[param.id]?.asNumber {
                config.setValue(v, forParameter: param.id)
            }
        }
        let opacity = Float(resolvedProps["opacity"]?.asNumber ?? Double(info.opacity))
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: info.trackID,
            transform: info.transform,
            opacity: opacity,
            maskParameters: info.maskParameters,
            clipTimeRange: info.clipTimeRange,
            isEffect: true,
            effectConfig: config,
            clip: info.clip
        )
    }

    private func resolveAdjustmentKeyframes(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        resolvedProps: [String: PropertyValue]
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        let opacity = Float(resolvedProps["opacity"]?.asNumber ?? Double(info.opacity))
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: info.trackID,
            transform: info.transform,
            opacity: opacity,
            maskParameters: info.maskParameters,
            clipTimeRange: info.clipTimeRange,
            isAdjustment: true,
            adjustmentConfig: info.adjustmentConfig,
            clip: info.clip
        )
    }

    private func resolveVideoOrImageKeyframes(
        info: TimelineCustomVideoCompositionInstruction.LayerRenderInfo,
        resolvedClip: TimelineClip,
        resolvedProps: [String: PropertyValue],
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        let rawSize = info.rawNaturalSize.width > 0 ? info.rawNaturalSize : CGSize(width: 1920, height: 1080)
        let computed = TimelineCompositionBuilder.computeTransform(
            transform: info.videoTrackTransform,
            naturalSize: rawSize,
            clip: resolvedClip,
            canvasSize: canvasSize
        )
        let maskParams = TimelineMaskParameters.extract(from: resolvedProps)
        let safeCanvasH = max(1.0, Double(canvasSize.height))
        let srcH = max(1.0, Double(info.naturalSize.height))
        let effectiveScaleY = (srcH * Double(computed.finalScale)) / safeCanvasH
        let normalizedOffsetY = (resolvedProps["positionY"]?.asNumber ?? 0.0) / safeCanvasH

        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: info.trackID,
            transform: computed.transform,
            opacity: computed.opacity,
            maskParameters: maskParams,
            gridConfig: info.gridConfig,
            autoPanConfig: info.autoPanConfig,
            clipTimeRange: info.clipTimeRange,
            naturalSize: info.naturalSize,
            rawNaturalSize: info.rawNaturalSize,
            finalScale: computed.finalScale,
            userScaleY: effectiveScaleY,
            normalizedOffsetY: normalizedOffsetY,
            isAdjustment: info.isAdjustment,
            adjustmentConfig: info.adjustmentConfig,
            isEffect: info.isEffect,
            effectConfig: info.effectConfig,
            isText: info.isText,
            textConfig: info.textConfig,
            isSticker: info.isSticker,
            stickerConfig: info.stickerConfig,
            isStillImage: info.isStillImage,
            stillImageURL: info.stillImageURL,
            isSolidColor: info.isSolidColor,
            solidColorHex: info.solidColorHex,
            isProcedural: info.isProcedural,
            proceduralConfig: info.proceduralConfig,
            clip: resolvedClip,
            videoTrackTransform: info.videoTrackTransform
        )
    }
}
