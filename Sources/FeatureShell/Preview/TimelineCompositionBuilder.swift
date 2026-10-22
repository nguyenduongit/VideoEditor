import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os


struct TimelineCompositionBuilder {
    static let logger = Logger(subsystem: "com.videoeditor", category: "TimelineCompositionBuilder")

    static func buildTracks(
        for composition: AVMutableComposition,
        from layers: [TimelineLayer],
        aspectRatio: CanvasAspectRatio = .ratio16x9
    ) async -> (trackMap: [UUID: [CMPersistentTrackID]], instructions: [AVMutableVideoCompositionLayerInstruction], renderSize: CGSize) {
        var trackMap: [UUID: [CMPersistentTrackID]] = [:]
        var instructions: [AVMutableVideoCompositionLayerInstruction] = []
        let canvasSize = aspectRatio.renderSize

        for layer in layers {
            var videoTrack: AVMutableCompositionTrack?
            if layer.kind == .video {
                videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            }

            var audioTrack: AVMutableCompositionTrack?
            if layer.kind == .video || layer.kind == .audio {
                audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                if let track = audioTrack {
                    trackMap[layer.id, default: []].append(track.trackID)
                }
            }

            var layerInstruction: AVMutableVideoCompositionLayerInstruction?
            if let videoTrack {
                let inst = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                if layer.isHidden {
                    inst.setOpacity(0.0, at: .zero)
                }
                layerInstruction = inst
                instructions.append(inst)
            }

            await insertLayerClips(
                layer,
                intoVideo: videoTrack,
                audio: audioTrack,
                layerInstruction: layerInstruction,
                canvasSize: canvasSize
            )
        }
        return (trackMap, instructions, canvasSize)
    }

    static func buildVideoComposition(
        for layers: [TimelineLayer],
        composition: AVMutableComposition,
        layerTrackIDs: [UUID: CMPersistentTrackID],
        aspectRatio: CanvasAspectRatio,
        duration: CMTime
    ) -> AVMutableVideoComposition? {
        if hasActiveMask(in: layers) {
            return buildMaskVideoComposition(
                for: layers,
                composition: composition,
                layerTrackIDs: layerTrackIDs,
                aspectRatio: aspectRatio,
                duration: duration
            )
        }

        var instructions: [AVMutableVideoCompositionLayerInstruction] = []
        let canvasSize = aspectRatio.renderSize

        for layer in layers where layer.kind == .video {
            guard let trackID = layerTrackIDs[layer.id],
                  let videoTrack = composition.track(withTrackID: trackID) else { continue }
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

            if layer.isHidden {
                layerInstruction.setOpacity(0.0, at: .zero)
            } else {
                var currentVideoTime: CMTime = .zero
                let sortedClips = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
                for clip in sortedClips {
                    guard let url = clip.mediaURL,
                          let meta = VideoMetadataCache.shared.metadata(for: url) else { continue }
                    let targetStart = clip.timeRange.start
                    let insertAt = CMTimeMaximum(targetStart, currentVideoTime)
                    currentVideoTime = insertAt + clip.timeRange.duration

                    applyVideoTransform(
                        transform: meta.transform,
                        naturalSize: meta.naturalSize,
                        clip: clip,
                        canvasSize: canvasSize,
                        layerInstruction: layerInstruction,
                        at: insertAt
                    )
                }
            }
            instructions.append(layerInstruction)
        }

        guard !instructions.isEmpty else { return nil }
        return makeVideoComposition(
            layerInstructions: instructions,
            renderSize: canvasSize,
            duration: duration
        )
    }

    static func makeVideoComposition(
        layerInstructions: [AVMutableVideoCompositionLayerInstruction],
        renderSize: CGSize,
        duration: CMTime
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        let size = (renderSize.width > 0 && renderSize.height > 0) ? renderSize : CGSize(width: 1920, height: 1080)
        videoComposition.renderSize = size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        let safeDuration = CMTimeMaximum(duration, CMTime(value: 1, timescale: 30))
        instruction.timeRange = CMTimeRange(start: .zero, duration: safeDuration)
        instruction.layerInstructions = layerInstructions
        videoComposition.instructions = [instruction]
        return videoComposition
    }

    private static func insertLayerClips(
        _ layer: TimelineLayer,
        intoVideo videoTrack: AVMutableCompositionTrack?,
        audio audioTrack: AVMutableCompositionTrack?,
        layerInstruction: AVMutableVideoCompositionLayerInstruction?,
        canvasSize: CGSize
    ) async {
        var currentVideoTime: CMTime = .zero
        var currentAudioTime: CMTime = .zero
        let sortedClips = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }

        for clip in sortedClips {
            guard let url = clip.mediaURL else { continue }
            let asset = AVURLAsset(url: url)
            guard let assetDuration = try? await asset.load(.duration) else { continue }
            let durSec = CMTimeGetSeconds(assetDuration)
            guard durSec.isFinite && !durSec.isNaN && durSec > 0 else { continue }

            let remainingAsset = CMTimeSubtract(assetDuration, clip.sourceStartTime)
            guard remainingAsset > .zero else { continue }
            let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
            let neededSource = CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: speed)
            let sourceDuration = CMTimeMinimum(neededSource, remainingAsset)
            let sourceRange = CMTimeRange(start: clip.sourceStartTime, duration: sourceDuration)

            if clip.kind == .video, let videoTrack {
                await insertVideoTrack(
                    clip: clip,
                    asset: asset,
                    sourceRange: sourceRange,
                    speed: speed,
                    videoTrack: videoTrack,
                    layerInstruction: layerInstruction,
                    canvasSize: canvasSize,
                    currentVideoTime: &currentVideoTime
                )
            }
            if (clip.kind == .video || clip.kind == .audio), let audioTrack {
                await insertAudioTrack(
                    clip: clip,
                    asset: asset,
                    sourceRange: sourceRange,
                    speed: speed,
                    audioTrack: audioTrack,
                    currentAudioTime: &currentAudioTime
                )
            }
        }
    }


    static func computeTransform(
        transform: CGAffineTransform,
        naturalSize: CGSize,
        clip: TimelineClip,
        canvasSize: CGSize
    ) -> (transform: CGAffineTransform, opacity: Float) {
        let oriented = naturalSize.applying(transform)
        let srcW = max(1.0, abs(oriented.width))
        let srcH = max(1.0, abs(oriented.height))

        let baseScale = min(canvasSize.width / srcW, canvasSize.height / srcH)
        let userScale = clip.properties["scale"]?.asNumber ?? 1.0
        let userPosX = clip.properties["positionX"]?.asNumber ?? 0.0
        let userPosY = clip.properties["positionY"]?.asNumber ?? 0.0
        let userRotation = clip.properties["rotation"]?.asNumber ?? 0.0
        let userOpacity = clip.properties["opacity"]?.asNumber ?? 1.0

        let finalScale = baseScale * userScale
        let dx = (canvasSize.width - srcW * finalScale) / 2.0 + userPosX
        let dy = (canvasSize.height - srcH * finalScale) / 2.0 + userPosY

        var finalTransform = transform
            .concatenating(CGAffineTransform(scaleX: finalScale, y: finalScale))
            .concatenating(CGAffineTransform(translationX: dx, y: dy))

        if userRotation != 0.0 {
            let radians = userRotation * .pi / 180.0
            let cx = canvasSize.width / 2.0 + userPosX
            let cy = canvasSize.height / 2.0 + userPosY
            let rot = CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: radians)
                .translatedBy(x: -cx, y: -cy)
            finalTransform = finalTransform.concatenating(rot)
        }

        return (finalTransform, Float(userOpacity))
    }

    static func applyVideoTransform(
        transform: CGAffineTransform,
        naturalSize: CGSize,
        clip: TimelineClip,
        canvasSize: CGSize,
        layerInstruction: AVMutableVideoCompositionLayerInstruction?,
        at insertAt: CMTime
    ) {
        let computed = computeTransform(
            transform: transform,
            naturalSize: naturalSize,
            clip: clip,
            canvasSize: canvasSize
        )
        layerInstruction?.setTransform(computed.transform, at: insertAt)
        if computed.opacity < 1.0 {
            layerInstruction?.setOpacity(computed.opacity, at: insertAt)
        }
    }
}
