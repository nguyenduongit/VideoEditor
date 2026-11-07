import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import Domain

/// Mở rộng `TimelineCompositionBuilder` để dựng `LayerRenderInfo` cho các lớp phủ `.text`, `.sticker`, `.image`, `.effect`, `.adjustment`
/// và định tuyến chuyển cảnh A/B (`CutTransition`) cho lớp `.video`.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TimelineCompositionBuilder {

    struct ResolvedTransitionWindow: Sendable {
        let transition: CutTransition
        let leadingClip: TimelineClip
        let trailingClip: TimelineClip
        let leadingIndex: Int
        let trailingIndex: Int
        let range: CMTimeRange
    }

    static func transitionWindows(for layer: TimelineLayer) -> [ResolvedTransitionWindow] {
        guard (layer.kind == .video || layer.kind == .image), !layer.transitions.isEmpty else { return [] }
        let sorted = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
        var windows: [ResolvedTransitionWindow] = []
        for transition in layer.transitions {
            guard let leadIdx = sorted.firstIndex(where: { $0.id == transition.leadingClipID }),
                  let trailIdx = sorted.firstIndex(where: { $0.id == transition.trailingClipID }),
                  trailIdx == leadIdx + 1 else {
                continue
            }
            let lead = sorted[leadIdx]
            let trail = sorted[trailIdx]
            let cutTime = trail.timeRange.start
            guard abs(CMTimeGetSeconds(CMTimeSubtract(cutTime, lead.timeRange.end))) <= 0.05 else { continue }

            let rawDur = CMTimeMaximum(CMTime(seconds: 0.1, preferredTimescale: 600), transition.duration.cmTime)
            let maxSafeDur = CMTimeMinimum(lead.timeRange.duration, trail.timeRange.duration)
            let dur = CMTimeMinimum(rawDur, maxSafeDur)
            guard dur > .zero else { continue }

            let start: CMTime
            switch transition.alignment {
            case .center:
                start = CMTimeMaximum(lead.timeRange.start, CMTimeSubtract(cutTime, CMTimeMultiplyByFloat64(dur, multiplier: 0.5)))
            case .startOnCut:
                start = cutTime
            case .endOnCut:
                start = CMTimeMaximum(lead.timeRange.start, CMTimeSubtract(cutTime, dur))
            }
            let end = CMTimeMinimum(trail.timeRange.end, CMTimeAdd(start, dur))
            let actualDur = CMTimeSubtract(end, start)
            guard actualDur > .zero else { continue }

            windows.append(ResolvedTransitionWindow(
                transition: transition,
                leadingClip: lead,
                trailingClip: trail,
                leadingIndex: leadIdx,
                trailingIndex: trailIdx,
                range: CMTimeRange(start: start, duration: actualDur)
            ))
        }
        return windows
    }

    static func makeVideoLayerOrTransitionRenderInfo(
        layer: TimelineLayer,
        primaryTrackID: CMPersistentTrackID,
        secondaryTrackID: CMPersistentTrackID?,
        range: CMTimeRange,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        let sortedClips = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }

        if let secondaryID = secondaryTrackID {
            for win in transitionWindows(for: layer) where win.range.containsTime(midTime) {
                let leadTrackID = (win.leadingIndex % 2 == 0) ? primaryTrackID : secondaryID
                let trailTrackID = (win.trailingIndex % 2 == 0) ? primaryTrackID : secondaryID
                let fromInfo = makeSingleClipVideoRenderInfo(clip: win.leadingClip, trackID: leadTrackID, canvasSize: canvasSize)
                let toInfo = makeSingleClipVideoRenderInfo(clip: win.trailingClip, trackID: trailTrackID, canvasSize: canvasSize)
                let activeTrans = TimelineCustomVideoCompositionInstruction.ActiveTransitionRenderInfo(
                    transition: win.transition,
                    windowRange: win.range,
                    fromLayerInfo: fromInfo,
                    toLayerInfo: toInfo
                )
                return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
                    trackID: leadTrackID,
                    transform: .identity,
                    opacity: 1.0,
                    maskParameters: nil,
                    clipTimeRange: win.range,
                    activeTransition: activeTrans
                )
            }
        }

        guard let idx = sortedClips.firstIndex(where: {
            $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
        }) else {
            return nil
        }
        let clip = sortedClips[idx]
        let trackID: CMPersistentTrackID
        if let secondaryID = secondaryTrackID, !layer.transitions.isEmpty {
            trackID = (idx % 2 == 0) ? primaryTrackID : secondaryID
        } else {
            trackID = primaryTrackID
        }
        return makeSingleClipVideoRenderInfo(clip: clip, trackID: trackID, canvasSize: canvasSize)
    }

    static func makeStickerRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        guard let clip = findActiveClip(in: layer, range: range) else { return nil }
        var config = clip.properties["stickerConfig"]?.asString.flatMap {
            StickerConfiguration.decode(from: $0)
        } ?? StickerConfiguration(
            systemSymbolFallback: clip.properties["systemSymbolFallback"]?.asString ?? "face.smiling"
        )
        if let fh = clip.properties["flipHorizontal"]?.asBool { config.flipHorizontal = fh }
        if let fv = clip.properties["flipVertical"]?.asBool { config.flipVertical = fv }
        if let spd = clip.properties["speed"]?.asNumber { config.playbackSpeed = spd }
        if let loopRaw = clip.properties["loopMode"]?.asString, let loop = StickerLoopMode(rawValue: loopRaw) {
            config.loopMode = loop
        }
        let opacity = Float(clip.properties["opacity"]?.asNumber ?? 1.0)
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: .identity,
            opacity: opacity,
            maskParameters: nil,
            clipTimeRange: clip.timeRange,
            isSticker: true,
            stickerConfig: config,
            clip: clip
        )
    }

    static func makeStillImageRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        for win in transitionWindows(for: layer) where win.range.containsTime(midTime) {
            let fromInfo = makeSingleClipStillImageRenderInfo(clip: win.leadingClip, canvasSize: canvasSize)
            let toInfo = makeSingleClipStillImageRenderInfo(clip: win.trailingClip, canvasSize: canvasSize)
            let activeTrans = TimelineCustomVideoCompositionInstruction.ActiveTransitionRenderInfo(
                transition: win.transition,
                windowRange: win.range,
                fromLayerInfo: fromInfo,
                toLayerInfo: toInfo
            )
            return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
                trackID: kCMPersistentTrackID_Invalid,
                transform: .identity,
                opacity: 1.0,
                maskParameters: nil,
                clipTimeRange: win.range,
                activeTransition: activeTrans
            )
        }
        guard let clip = findActiveClip(in: layer, range: range) else { return nil }
        return makeSingleClipStillImageRenderInfo(clip: clip, canvasSize: canvasSize)
    }

    private static func makeSingleClipStillImageRenderInfo(
        clip: TimelineClip,
        canvasSize: CGSize
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo {
        let naturalSize: CGSize
        if let url = clip.mediaURL, let resolved = TimelineMediaDimensionResolver.resolveDimension(for: url, type: .image) {
            naturalSize = resolved
        } else {
            naturalSize = canvasSize
        }

        let computed = computeTransform(transform: .identity, naturalSize: naturalSize, clip: clip, canvasSize: canvasSize)
        let maskParams = TimelineMaskParameters.extract(from: clip.properties)
        let gridConfig = clip.properties["gridConfig"]?.asString.flatMap { GridConfiguration.decode(from: $0) }
        let autoPanConfig = clip.properties["autoPanConfig"]?.asString.flatMap { AutoPanConfiguration.decode(from: $0) }
        let adjConfig = clip.properties["adjustmentConfig"]?.asString.flatMap { AdjustmentConfiguration.decode(from: $0) }
        let safeCanvasH = max(1.0, Double(canvasSize.height))
        let effectiveScaleY = (Double(naturalSize.height) * Double(computed.finalScale)) / safeCanvasH
        let normalizedOffsetY = (clip.properties["positionY"]?.asNumber ?? 0.0) / safeCanvasH

        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: computed.transform,
            opacity: computed.opacity,
            maskParameters: maskParams,
            gridConfig: (gridConfig?.isDefault == false) ? gridConfig : nil,
            autoPanConfig: autoPanConfig,
            clipTimeRange: clip.timeRange,
            naturalSize: naturalSize,
            rawNaturalSize: naturalSize,
            finalScale: computed.finalScale,
            userScaleY: effectiveScaleY,
            normalizedOffsetY: normalizedOffsetY,
            adjustmentConfig: (adjConfig?.isNeutral == false) ? adjConfig : nil,
            isStillImage: true,
            stillImageURL: clip.mediaURL,
            isSolidColor: clip.properties["isSolidColor"]?.asBool ?? false,
            solidColorHex: clip.properties["solidColorHex"]?.asString,
            isProcedural: clip.properties["isProcedural"]?.asBool ?? false,
            proceduralConfig: clip.properties["proceduralConfig"]?.asString.flatMap { ProceduralConfiguration.decode(from: $0) },
            clip: clip
        )
    }

    static func makeEffectRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        guard let clip = findActiveClip(in: layer, range: range) else { return nil }
        let config = clip.properties["effectConfig"]?.asString.flatMap { EffectConfiguration.decode(from: $0) } ?? EffectConfiguration()
        let opacity = Float(clip.properties["opacity"]?.asNumber ?? 1.0)
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: .identity,
            opacity: opacity,
            maskParameters: nil,
            clipTimeRange: clip.timeRange,
            isEffect: true,
            effectConfig: config,
            clip: clip
        )
    }

    static func makeAdjustmentRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        guard let clip = findActiveClip(in: layer, range: range) else { return nil }
        let config = clip.properties["adjustmentConfig"]?.asString.flatMap { AdjustmentConfiguration.decode(from: $0) } ?? AdjustmentConfiguration()
        let opacity = Float(clip.properties["opacity"]?.asNumber ?? 1.0)
        return TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
            trackID: kCMPersistentTrackID_Invalid,
            transform: .identity,
            opacity: opacity,
            maskParameters: nil,
            clipTimeRange: clip.timeRange,
            isAdjustment: true,
            adjustmentConfig: config,
            clip: clip
        )
    }

    static func makeTextRenderInfo(
        layer: TimelineLayer,
        range: CMTimeRange
    ) -> TimelineCustomVideoCompositionInstruction.LayerRenderInfo? {
        guard let clip = findActiveClip(in: layer, range: range) else { return nil }
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
            textConfig: config,
            clip: clip
        )
    }

    private static func findActiveClip(in layer: TimelineLayer, range: CMTimeRange) -> TimelineClip? {
        let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
        return layer.clips.first {
            $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
        }
    }
}
