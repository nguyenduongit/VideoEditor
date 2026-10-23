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
            !layer.isHidden && layer.kind == .video && layer.clips.contains { clip in
                TimelineMaskParameters.extract(from: clip.properties).isMaskActive
                    || hasActiveGrid(in: clip)
                    || hasActiveAutoPan(in: clip)
            }
        }
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
              let config = GridConfiguration.decode(from: configStr) else {
            return false
        }
        return !config.isDefault
    }

    static func buildMaskVideoComposition(
        for layers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        aspectRatio: CanvasAspectRatio,
        duration: CMTime
    ) -> AVMutableVideoComposition? {
        let canvasSize = aspectRatio.renderSize
        let safeDuration = CMTimeMaximum(duration, CMTime(value: 1, timescale: 30))
        let timeRanges = computeInstructionTimeRanges(layers: layers, duration: safeDuration)
        let videoLayers = layers.filter { !$0.isHidden && $0.kind == .video }

        let customInstructions = buildInstructions(
            timeRanges: timeRanges,
            videoLayers: videoLayers,
            composition: composition,
            layerTrackIDs: layerTrackIDs,
            canvasSize: canvasSize
        )
        guard !customInstructions.isEmpty else { return nil }

        let videoComposition = AVMutableVideoComposition()
        let size = (canvasSize.width > 0 && canvasSize.height > 0) ? canvasSize : CGSize(width: 1920, height: 1080)
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.customVideoCompositorClass = TimelineVideoCompositor.self
        videoComposition.instructions = customInstructions
        logger.notice("buildMaskVideoComposition: created videoComposition with \(customInstructions.count) instructions")
        return videoComposition
    }

    private static func buildInstructions(
        timeRanges: [CMTimeRange],
        videoLayers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        canvasSize: CGSize
    ) -> [AVVideoCompositionInstructionProtocol] {
        var customInstructions: [AVVideoCompositionInstructionProtocol] = []
        for range in timeRanges {
            var layerInfos: [TimelineCustomVideoCompositionInstruction.LayerRenderInfo] = []
            for layer in videoLayers {
                guard let trackID = layerTrackIDs[layer.id],
                      composition.track(withTrackID: trackID) != nil else { continue }

                let midTime = CMTimeAdd(range.start, CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5))
                guard let clip = layer.clips.first(where: {
                    $0.timeRange.containsTime(midTime) || ($0.timeRange.start <= range.start && $0.timeRange.end >= range.end)
                }) else { continue }
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
                let oriented = meta.naturalSize.applying(meta.transform)
                let srcW = max(1.0, abs(oriented.width))
                let srcH = max(1.0, abs(oriented.height))

                layerInfos.append(
                    TimelineCustomVideoCompositionInstruction.LayerRenderInfo(
                        trackID: trackID,
                        transform: computed.transform,
                        opacity: computed.opacity,
                        maskParameters: maskParams,
                        gridConfig: (gridConfig?.isDefault == false) ? gridConfig : nil,
                        autoPanConfig: autoPanConfig,
                        clipTimeRange: clip.timeRange,
                        naturalSize: CGSize(width: srcW, height: srcH),
                        finalScale: computed.finalScale
                    )
                )
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

    private static func computeInstructionTimeRanges(layers: [TimelineLayer], duration: CMTime) -> [CMTimeRange] {
        var points: [CMTime] = [.zero, duration]
        for layer in layers where !layer.isHidden && layer.kind == .video {
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
