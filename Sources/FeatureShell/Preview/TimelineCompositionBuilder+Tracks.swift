import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

extension TimelineCompositionBuilder {
    static func insertVideoTrack(
        clip: TimelineClip,
        asset: AVURLAsset,
        sourceRange: CMTimeRange,
        speed: Double,
        videoTrack: AVMutableCompositionTrack,
        layerInstruction: AVMutableVideoCompositionLayerInstruction?,
        canvasSize: CGSize,
        currentVideoTime: inout CMTime
    ) async {
        guard let assetVideo = try? await asset.loadTracks(withMediaType: .video).first else { return }
        let targetStart = clip.timeRange.start
        do {
            if targetStart > currentVideoTime {
                let gap = CMTimeSubtract(targetStart, currentVideoTime)
                videoTrack.insertEmptyTimeRange(CMTimeRange(start: currentVideoTime, duration: gap))
            }
            let insertAt = CMTimeMaximum(targetStart, currentVideoTime)
            let trackRange = (try? await assetVideo.load(.timeRange)) ?? CMTimeRange(start: .zero, duration: sourceRange.end)
            let availDur = CMTimeMaximum(.zero, CMTimeSubtract(trackRange.end, sourceRange.start))
            let actualSourceDur = CMTimeMinimum(sourceRange.duration, availDur)
            guard actualSourceDur > .zero else { return }

            let validSourceRange = CMTimeRange(start: sourceRange.start, duration: actualSourceDur)
            try videoTrack.insertTimeRange(validSourceRange, of: assetVideo, at: insertAt)
            let insertedDur = CMTimeMaximum(.zero, CMTimeSubtract(videoTrack.timeRange.end, insertAt))
            if insertedDur > .zero && (abs(speed - 1.0) > 0.001 || abs(CMTimeGetSeconds(insertedDur) - CMTimeGetSeconds(clip.timeRange.duration)) > 0.002) {
                let scaledRange = CMTimeRange(start: insertAt, duration: insertedDur)
                videoTrack.scaleTimeRange(scaledRange, toDuration: clip.timeRange.duration)
            }
            currentVideoTime = insertAt + clip.timeRange.duration

            let meta: VideoTrackMetadata
            if let cached = metadataCache.metadata(for: asset.url) {
                meta = cached
            } else {
                let transform = (try? await assetVideo.load(.preferredTransform)) ?? .identity
                let naturalSize = (try? await assetVideo.load(.naturalSize)) ?? CGSize(width: 1920, height: 1080)
                meta = VideoTrackMetadata(transform: transform, naturalSize: naturalSize)
                metadataCache.store(meta, for: asset.url)
            }
            applyVideoTransform(
                transform: meta.transform,
                naturalSize: meta.naturalSize,
                clip: clip,
                canvasSize: canvasSize,
                layerInstruction: layerInstruction,
                at: insertAt
            )
        } catch {
            logger.error("Insert video track failed: \(error.localizedDescription)")
        }
    }

    static func insertAudioTrack(
        clip: TimelineClip,
        asset: AVURLAsset,
        sourceRange: CMTimeRange,
        speed: Double,
        audioTrack: AVMutableCompositionTrack,
        currentAudioTime: inout CMTime
    ) async {
        let targetStart = clip.timeRange.start
        let assetAudio = try? await asset.loadTracks(withMediaType: .audio).first
        do {
            if targetStart > currentAudioTime {
                let gap = CMTimeSubtract(targetStart, currentAudioTime)
                audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: gap))
            }
            let insertAt = CMTimeMaximum(targetStart, currentAudioTime)
            if let assetAudio {
                try audioTrack.insertTimeRange(sourceRange, of: assetAudio, at: insertAt)
                if abs(speed - 1.0) > 0.001 {
                    let scaledRange = CMTimeRange(start: insertAt, duration: sourceRange.duration)
                    audioTrack.scaleTimeRange(scaledRange, toDuration: clip.timeRange.duration)
                }
            } else {
                audioTrack.insertEmptyTimeRange(CMTimeRange(start: insertAt, duration: clip.timeRange.duration))
            }
            currentAudioTime = insertAt + clip.timeRange.duration
        } catch {
            logger.error("Insert audio track failed: \(error.localizedDescription)")
        }
    }
}
