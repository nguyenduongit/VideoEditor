import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import Domain

/// Extension on TimelineCompositionBuilder for constructing custom GPU video compositions.
/// Complies with R3.1 (<= 300 lines, Func <= 50 lines) and R9.4 of AGENTS.md.
extension TimelineCompositionBuilder {
    static let customCompositedKinds: Set<ClipKind> = [.video, .image, .sticker, .text, .adjustment, .effect]

    static func hasActiveMask(in layers: [TimelineLayer]) -> Bool {
        layers.contains { layer in
            if layer.isHidden { return false }
            let overlayKinds: Set<ClipKind> = [.adjustment, .text, .effect, .sticker, .image]
            if overlayKinds.contains(layer.kind) && !layer.clips.isEmpty {
                return true
            }
            if layer.kind == .video && !layer.transitions.isEmpty {
                return true
            }
            return layer.kind == .video && layer.clips.contains { clip in
                (clip.properties["isSolidColor"]?.asBool ?? false)
                    || (clip.properties["isProcedural"]?.asBool ?? false)
                    || TimelineMaskParameters.extract(from: clip.properties).isMaskActive
                    || hasActiveGrid(in: clip)
                    || hasActiveAutoPan(in: clip)
                    || hasActiveAdjustment(in: clip)
                    || (ClipKeyframeMap.from(clip: clip)?.isEmpty == false)
            }
        }
    }

    static func hasActiveAdjustment(in clip: TimelineClip) -> Bool {
        clip.properties["adjustmentConfig"]?.asString.flatMap { AdjustmentConfiguration.decode(from: $0) }?.hasGradingChanges ?? false
    }

    static func hasActiveAutoPan(in clip: TimelineClip) -> Bool {
        clip.properties["autoPanConfig"]?.asString.flatMap { AutoPanConfiguration.decode(from: $0) }.map { $0.isEnabled && !$0.keyframes.isEmpty } ?? false
    }

    static func hasActiveGrid(in clip: TimelineClip) -> Bool {
        clip.properties["gridConfig"]?.asString.flatMap { GridConfiguration.decode(from: $0) } != nil
    }

    static func buildMaskVideoComposition(
        for layers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        secondaryTrackIDs: [UUID: CMPersistentTrackID] = [:],
        aspectRatio: CanvasAspectRatio,
        duration: CMTime,
        renderSize: CGSize? = nil
    ) -> AVMutableVideoComposition? {
        let logicalCanvasSize = aspectRatio.renderSize
        let outputRenderSize = renderSize ?? logicalCanvasSize
        let safeDuration = CMTimeMaximum(duration, CMTime(value: 1, timescale: TimeRational.defaultFPS))
        let timeRanges = computeInstructionTimeRanges(layers: layers, duration: safeDuration)
        let activeLayers = layers.filter { !$0.isHidden && customCompositedKinds.contains($0.kind) }

        let customInstructions = buildInstructions(
            timeRanges: timeRanges,
            layers: activeLayers,
            composition: composition,
            layerTrackIDs: layerTrackIDs,
            secondaryTrackIDs: secondaryTrackIDs,
            canvasSize: logicalCanvasSize
        )
        guard !customInstructions.isEmpty else { return nil }

        let videoComposition = AVMutableVideoComposition()
        let size = (outputRenderSize.width > 0 && outputRenderSize.height > 0)
            ? outputRenderSize
            : CGSize(width: 1920, height: 1080)
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: TimeRational.defaultFPS)
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
        secondaryTrackIDs: [UUID: CMPersistentTrackID],
        canvasSize: CGSize
    ) -> [AVVideoCompositionInstructionProtocol] {
        var customInstructions: [AVVideoCompositionInstructionProtocol] = []
        for range in timeRanges {
            var layerInfos: [TimelineCustomVideoCompositionInstruction.LayerRenderInfo] = []
            for layer in layers {
                switch layer.kind {
                case .adjustment:
                    if let adjInfo = makeAdjustmentRenderInfo(layer: layer, range: range) {
                        layerInfos.append(adjInfo)
                    }
                case .effect:
                    if let effectInfo = makeEffectRenderInfo(layer: layer, range: range) {
                        layerInfos.append(effectInfo)
                    }
                case .text:
                    if let textInfo = makeTextRenderInfo(layer: layer, range: range) {
                        layerInfos.append(textInfo)
                    }
                case .sticker:
                    if let stickerInfo = makeStickerRenderInfo(layer: layer, range: range) {
                        layerInfos.append(stickerInfo)
                    }
                case .image:
                    if let imgInfo = makeStillImageRenderInfo(layer: layer, range: range, canvasSize: canvasSize) {
                        layerInfos.append(imgInfo)
                    }
                case .video:
                    guard let trackID = layerTrackIDs[layer.id],
                          composition.track(withTrackID: trackID) != nil else { continue }
                    let secondaryID = secondaryTrackIDs[layer.id]
                    if let vInfo = makeVideoLayerOrTransitionRenderInfo(
                        layer: layer,
                        primaryTrackID: trackID,
                        secondaryTrackID: secondaryID,
                        range: range,
                        canvasSize: canvasSize
                    ) {
                        layerInfos.append(vInfo)
                    }
                case .audio:
                    break
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

    static func makeSingleClipVideoRenderInfo(
        clip: TimelineClip,
        trackID: CMPersistentTrackID,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        if let url = clip.mediaURL, metadataCache.metadata(for: url) == nil {
            _ = TimelineMediaDimensionResolver.resolveDimension(for: url, type: .video)
        }
        let meta = (clip.mediaURL.flatMap { metadataCache.metadata(for: $0) })
            ?? VideoTrackMetadata(transform: .identity, naturalSize: CGSize(width: 1920, height: 1080))

        let computed = computeTransform(
            transform: meta.transform,
            naturalSize: meta.naturalSize,
            clip: clip,
            canvasSize: canvasSize
        )
        let maskParams = TimelineMaskParameters.extract(from: clip.properties)
        let gridConfig = clip.properties["gridConfig"]?.asString.flatMap { GridConfiguration.decode(from: $0) }
        let autoPanConfig = clip.properties["autoPanConfig"]?.asString.flatMap { AutoPanConfiguration.decode(from: $0) }
        let adjConfig = clip.properties["adjustmentConfig"]?.asString.flatMap { AdjustmentConfiguration.decode(from: $0) }
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
            adjustmentConfig: (adjConfig?.isNeutral == false) ? adjConfig : nil,
            isSolidColor: clip.properties["isSolidColor"]?.asBool ?? false,
            solidColorHex: clip.properties["solidColorHex"]?.asString,
            isProcedural: clip.properties["isProcedural"]?.asBool ?? false,
            proceduralConfig: clip.properties["proceduralConfig"]?.asString.flatMap { ProceduralConfiguration.decode(from: $0) },
            clip: clip,
            videoTrackTransform: meta.transform
        )
    }

    static func computeInstructionTimeRanges(layers: [TimelineLayer], duration: CMTime) -> [CMTimeRange] {
        var points: [CMTime] = [.zero, duration]
        for layer in layers where !layer.isHidden && customCompositedKinds.contains(layer.kind) {
            for clip in layer.clips {
                let s = clip.timeRange.start
                let e = clip.timeRange.end
                if s >= .zero && s <= duration { points.append(s) }
                if e >= .zero && e <= duration { points.append(e) }
            }
            for win in transitionWindows(for: layer) {
                if win.range.start >= .zero && win.range.start <= duration { points.append(win.range.start) }
                if win.range.end >= .zero && win.range.end <= duration { points.append(win.range.end) }
            }
        }
        points.sort()
        var uniquePoints: [CMTime] = []
        for pt in points {
            if let last = uniquePoints.last {
                if CMTimeCompare(pt, last) != 0 { uniquePoints.append(pt) }
            } else {
                uniquePoints.append(pt)
            }
        }
        var ranges: [CMTimeRange] = []
        for i in 0..<(uniquePoints.count - 1) {
            let dur = CMTimeSubtract(uniquePoints[i + 1], uniquePoints[i])
            if dur > .zero {
                ranges.append(CMTimeRange(start: uniquePoints[i], duration: dur))
            }
        }
        return ranges.isEmpty ? [CMTimeRange(start: .zero, duration: duration)] : ranges
    }
}
