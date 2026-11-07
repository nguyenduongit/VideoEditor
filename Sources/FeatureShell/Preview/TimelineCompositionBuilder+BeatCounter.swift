import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

/// Extension hỗ trợ chèn các phân đoạn âm thanh đếm nhịp (Dance Beat Counter) vào AVMutableComposition.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R8.3 (AVFoundation).
extension TimelineCompositionBuilder {
    private static let beatLogger = Logger(subsystem: "VideoEditor", category: "BeatCounterComposition")

    /// Trích xuất toàn bộ mốc beat trên Timeline từ các clip âm thanh có cấu hình beat.
    public static func resolveTimelineBeatTimes(from layers: [TimelineLayer]) -> [CMTime] {
        var allBeats: [CMTime] = []
        for layer in layers {
            for clip in layer.clips {
                if let config = AudioBeatConfiguration.from(clip: clip), !config.markers.isEmpty {
                    allBeats.append(contentsOf: config.timelineBeatTimes(for: clip))
                }
            }
        }
        allBeats.sort { CMTimeCompare($0, $1) < 0 }

        var unique: [CMTime] = []
        for beat in allBeats {
            if let last = unique.last {
                if abs(CMTimeGetSeconds(CMTimeSubtract(beat, last))) > 0.005 {
                    unique.append(beat)
                }
            } else {
                unique.append(beat)
            }
        }
        return unique
    }

    /// Chèn các đoạn âm thanh đếm nhịp cho clip Dance Beat Counter vào `AVMutableCompositionTrack`.
    static func insertBeatCounterClip(
        clip: TimelineClip,
        allLayers: [TimelineLayer],
        audioTrack: AVMutableCompositionTrack,
        currentAudioTime: inout CMTime
    ) async {
        let beatTimes = resolveTimelineBeatTimes(from: allLayers)
        let items = DanceBeatCounterSchedule.schedule(beatTimes: beatTimes, within: clip.timeRange)
        guard !items.isEmpty else {
            insertEmptyPadding(for: clip.timeRange, audioTrack: audioTrack, currentAudioTime: &currentAudioTime)
            return
        }

        let targetStart = clip.timeRange.start
        if targetStart > currentAudioTime {
            let gap = CMTimeSubtract(targetStart, currentAudioTime)
            audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: gap))
            currentAudioTime = targetStart
        }

        for (index, item) in items.enumerated() {
            let beatTime = item.time
            if beatTime > currentAudioTime {
                let gap = CMTimeSubtract(beatTime, currentAudioTime)
                audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: gap))
                currentAudioTime = beatTime
            }

            guard let asset = VoiceAssetCache.shared.voiceAsset(for: item.voiceNumber),
                  let voiceTrack = try? await asset.loadTracks(withMediaType: .audio).first,
                  let assetDuration = try? await asset.load(.duration) else {
                continue
            }

            let nextTime = (index + 1 < items.count) ? items[index + 1].time : clip.timeRange.end
            let availableDuration = CMTimeSubtract(nextTime, beatTime)
            guard availableDuration > .zero else { continue }

            let durationToInsert = CMTimeMinimum(assetDuration, availableDuration)
            let sourceRange = CMTimeRange(start: .zero, duration: durationToInsert)

            do {
                try audioTrack.insertTimeRange(sourceRange, of: voiceTrack, at: beatTime)
                currentAudioTime = CMTimeAdd(beatTime, durationToInsert)
            } catch {
                beatLogger.error("Failed to insert voice track for beat \(item.voiceNumber): \(error.localizedDescription)")
            }
        }

        let clipEnd = clip.timeRange.end
        if clipEnd > currentAudioTime {
            let trailingGap = CMTimeSubtract(clipEnd, currentAudioTime)
            audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: trailingGap))
            currentAudioTime = clipEnd
        }
    }

    private static func insertEmptyPadding(
        for timeRange: CMTimeRange,
        audioTrack: AVMutableCompositionTrack,
        currentAudioTime: inout CMTime
    ) {
        if timeRange.start > currentAudioTime {
            let gap = CMTimeSubtract(timeRange.start, currentAudioTime)
            audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: gap))
        }
        let insertAt = CMTimeMaximum(timeRange.start, currentAudioTime)
        audioTrack.insertEmptyTimeRange(CMTimeRange(start: insertAt, duration: timeRange.duration))
        currentAudioTime = insertAt + timeRange.duration
    }
}

