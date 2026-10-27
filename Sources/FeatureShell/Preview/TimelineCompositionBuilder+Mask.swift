import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import Domain

/// Extension on TimelineCompositionBuilder for constructing custom mask video compositions.
/// Complies with R3.1 and R9.4 of AGENTS.md.
extension TimelineCompositionBuilder {
    static func hasActiveMask(in layers: [TimelineLayer]) -> Bool {
        layers.contains { layer in
            if layer.isHidden { return false }
            if (layer.kind == .adjustment || layer.kind == .text) && !layer.clips.isEmpty {
                return true
            }
            return layer.kind == .video && layer.clips.contains { clip in
                TimelineMaskParameters.extract(from: clip.properties).isMaskActive
                    || hasActiveGrid(in: clip)
                    || hasActiveAutoPan(in: clip)
                    || hasActiveAdjustment(in: clip)
            }
        }
    }

    private static func hasActiveAdjustment(in clip: TimelineClip) -> Bool {
        guard let configStr = clip.properties["adjustmentConfig"]?.asString,
              let config = AdjustmentConfiguration.decode(from: configStr) else {
            return false
        }
        return config.hasGradingChanges
    }

    private static func hasActiveAutoPan(in clip: TimelineClip) -> Bool {
        guard let configStr = clip.properties["autoPanConfig"]?.asString,
              let config = AutoPanConfiguration.decode(from: configStr) else {
            return false
        }
        return config.isEnabled && !config.keyframes.isEmpty
    }

    private static func hasActiveGrid(in clip: TimelineClip) -> Bool {
        guard let configStr = clip.properties["gridConfig"]?.asString,
              let _ = GridConfiguration.decode(from: configStr) else {
            return false
        }
        return true
    }

    static func buildMaskVideoComposition(
        for layers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        aspectRatio: CanvasAspectRatio,
        duration: CMTime,
        renderSize: CGSize? = nil
    ) -> AVMutableVideoComposition? {
        let logicalCanvasSize = aspectRatio.renderSize
        let outputRenderSize = renderSize ?? logicalCanvasSize
        let safeDuration = CMTimeMaximum(duration, CMTime(value: 1, timescale: 30))
        let timeRanges = computeInstructionTimeRanges(layers: layers, duration: safeDuration)
        let activeLayers = layers.filter { !$0.isHidden && ($0.kind == .video || $0.kind == .adjustment || $0.kind == .text) }

        let customInstructions = buildInstructions(
            timeRanges: timeRanges,
            layers: activeLayers,
            composition: composition,
            layerTrackIDs: layerTrackIDs,
            canvasSize: logicalCanvasSize
        )
        guard !customInstructions.isEmpty else { return nil }

        let videoComposition = AVMutableVideoComposition()
        let size = (outputRenderSize.width > 0 && outputRenderSize.height > 0) ? outputRenderSize : CGSize(width: 1920, height: 1080)
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.customVideoCompositorClass = TimelineVideoCompositor.self
        videoComposition.instructions = customInstructions
        logger.notice("buildMaskVideoComposition: created videoComposition with \(customInstructions.count) instructions")
        return videoComposition
    }

    private static func buildInstructions(
        timeRanges: [CMTimeRange],
        layers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        canvasSize: CGSize
    ) -> [AVVideoCompositionInstructionProtocol] {
        var customInstructions: [AVVideoCompositionInstructionProtocol] = []
        for range in timeRanges {
            var layerInfos: [TimelineCustomVideoCompositionInstruction.LayerRenderInfo] = []
            for layer in layers {
                if layer.kind == .adjustment {
                    if let adjInfo = makeAdjustmentRenderInfo(layer: layer, range: range) {
                        layerInfos.append(adjInfo)
                    }
                    continue
                }
                if layer.kind == .text {
                    if let textInfo = makeTextRenderInfo(layer: layer, range: range) {
                        layerInfos.append(textInfo)
                    }
                    continue
                }

                guard let trackID = layerTrackIDs[layer.id],
                      composition.track(withTrackID: trackID) != nil else { continue }
                if let vInfo = makeVideoRenderInfo(layer: layer, trackID: trackID, range: range, canvasSize: canvasSize) {
                    layerInfos.append(vInfo)
                }
            }

            let instruction = TimelineCustomVideoCompositionInstruction(
                timeRange: range,
                layerInfos: layerInfos,
                canvasSize: canvasSize
            )
            customInstructions.append(instruction)
        }
        return customInstructions
    }

    private static func makeAdjustmentRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        guard let clip = layer.clips.first(where: {
            $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
        }) else { return nil }
        let config = clip.properties["adjustmentConfig"]?.asString.flatMap {
            AdjustmentConfiguration.decode(from: $0)
        } ?? AdjustmentConfiguration()
        let opacity = Float(clip.properties["opacity"]?.asNumber ?? 1.0)
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: .identity,
            opacity: opacity,
            maskParameters: nil,
            clipTimeRange: clip.timeRange,
            isAdjustment: true,
            adjustmentConfig: config
        )
    }

    private static func makeTextRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        guard let clip = layer.clips.first(where: {
            $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
        }) else { return nil }
        var config = clip.properties["textConfig"]?.asString.flatMap {
            TextConfiguration.decode(from: $0)
        } ?? TextConfiguration(content: clip.properties["textContent"]?.asString ?? clip.name)

        if let px = clip.properties["positionX"]?.asNumber { config.positionX = px }
        if let py = clip.properties["positionY"]?.asNumber { config.positionY = py }
        if let s = clip.properties["scale"]?.asNumber { config.scale = s }
        if let r = clip.properties["rotation"]?.asNumber { config.rotation = r }
        if let op = clip.properties["opacity"]?.asNumber { config.opacity = op }
        if let content = clip.properties["textContent"]?.asString { config.content = content }
        if let size = clip.properties["fontSize"]?.asNumber { config.fontSize = size }
        if let font = clip.properties["fontName"]?.asString { config.fontName = font }

        let opacity = Float(clip.properties["opacity"]?.asNumber ?? config.opacity)
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: .identity,
            opacity: opacity,
            maskParameters: nil,
            clipTimeRange: clip.timeRange,
            isText: true,
            textConfig: config
        )
    }

    private static func makeVideoRenderInfo(
        layer: TimelineLayer,
        trackID: CMPersistentTrackID,
        range: CMTimeRange,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        guard let clip = layer.clips.first(where: {
            $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
        }) else { return nil }
        if let url = clip.mediaURL, VideoMetadataCache.shared.metadata(for: url) == nil {
            _ = TimelineMediaDimensionResolver.resolveDimension(for: url, type: .video)
        }
        let meta = (clip.mediaURL.flatMap { VideoMetadataCache.shared.metadata(for: $0) })
            ?? VideoTrackMetadata(transform: .identity, naturalSize: CGSize(width: 1920, height: 1080))

        let computed = computeTransform(
            transform: meta.transform,
            naturalSize: meta.naturalSize,
            clip: clip,
            canvasSize: canvasSize
        )
        let maskParams = TimelineMaskParameters.extract(from: clip.properties)
        let gridConfig = clip.properties["gridConfig"]?.asString.flatMap {
            GridConfiguration.decode(from: $0)
        }
        let autoPanConfig = clip.properties["autoPanConfig"]?.asString.flatMap {
            AutoPanConfiguration.decode(from: $0)
        }
        let adjConfig = clip.properties["adjustmentConfig"]?.asString.flatMap {
            AdjustmentConfiguration.decode(from: $0)
        }
        let oriented = meta.naturalSize.applying(meta.transform)
        let srcW = max(1.0, abs(oriented.width))
        let srcH = max(1.0, abs(oriented.height))
        let safeCanvasH = max(1.0, Double(canvasSize.height))
        let effectiveScaleY = (Double(srcH) * Double(computed.finalScale)) / safeCanvasH
        let userPosY = clip.properties["positionY"]?.asNumber ?? 0.0
        let normalizedOffsetY = userPosY / safeCanvasH

        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: trackID,
            transform: computed.transform,
            opacity: computed.opacity,
            maskParameters: maskParams,
            gridConfig: (gridConfig?.isDefault == false) ? gridConfig : nil,
            autoPanConfig: autoPanConfig,
            clipTimeRange: clip.timeRange,
            naturalSize: CGSize(width: srcW, height: srcH),
            rawNaturalSize: meta.naturalSize,
            finalScale: computed.finalScale,
            userScaleY: effectiveScaleY,
            normalizedOffsetY: normalizedOffsetY,
            adjustmentConfig: (adjConfig?.isNeutral == false) ? adjConfig : nil
        )
    }

    private static func computeInstructionTimeRanges(layers: [TimelineLayer], duration: CMTime) -> [CMTimeRange] {
        var points: [CMTime] = [.zero, duration]
        for layer in layers where !layer.isHidden && (layer.kind == .video || layer.kind == .adjustment || layer.kind == .text) {
            for clip in layer.clips {
                let s = clip.timeRange.start
                let e = clip.timeRange.end
                if s >= .zero && s <= duration { points.append(s) }
                if e >= .zero && e <= duration { points.append(e) }
            }
        }

        points.sort()

        var uniquePoints: [CMTime] = []
        for pt in points {
            if let last = uniquePoints.last {
                if CMTimeCompare(pt, last) != 0 {
                    uniquePoints.append(pt)
                }
            } else {
                uniquePoints.append(pt)
            }
        }

        var ranges: [CMTimeRange] = []
        for i in 0..<(uniquePoints.count - 1) {
            let t0 = uniquePoints[i]
            let t1 = uniquePoints[i + 1]
            let dur = CMTimeSubtract(t1, t0)
            if dur > .zero {
                ranges.append(CMTimeRange(start: t0, duration: dur))
            }
        }
        return ranges.isEmpty ? [CMTimeRange(start: .zero, duration: duration)] : ranges
    }
}
