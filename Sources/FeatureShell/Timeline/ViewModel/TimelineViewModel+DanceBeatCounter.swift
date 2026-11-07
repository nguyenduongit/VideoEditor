import Foundation
import CoreMedia
import Domain

/// Extension trên TimelineViewModel cung cấp logic thêm và quản lý clip Dance Beat Counter.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.1 (Command / Undo-Redo).
extension TimelineViewModel {
    /// Kiểm tra xem timeline có thể thêm clip Dance Beat Counter hay không (cần có ít nhất một track audio chính).
    public var canAddDanceBeatCounter: Bool {
        layers.contains { layer in
            layer.kind == .audio && layer.clips.contains { $0.mediaURL != nil && !($0.properties["isBeatCounter"]?.asBool ?? false) }
        }
    }

    /// Trích xuất toàn bộ mốc thời gian beat nhạc thực tế từ các clip âm thanh trên timeline.
    public var timelineBeatTimes: [CMTime] {
        TimelineCompositionBuilder.resolveTimelineBeatTimes(from: layers)
    }

    /// Thêm một khối Dance Beat Counter vào timeline tại vị trí playhead (tự động snap trúng vạch nhịp).
    @discardableResult
    public func addDanceBeatCounter(
        named name: String = "Dance Beat Counter",
        durationSeconds: Double? = nil,
        at proposedTime: CMTime? = nil
    ) -> TimelineClip? {
        let allBeats = TimelineCompositionBuilder.resolveTimelineBeatTimes(from: layers)
        let playhead = proposedTime ?? currentTime
        let targetStart = findSnappedBeatStart(for: playhead, in: allBeats)

        let resolvedDuration: CMTime
        if let sec = durationSeconds, sec > 0 {
            resolvedDuration = TimeRational.snapToFrame(time: CMTime(seconds: sec, preferredTimescale: 600))
        } else {
            resolvedDuration = calculateDefaultBeatCounterDuration(from: targetStart, in: allBeats)
        }

        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)
        var properties = dependencies.propertyRegistry.defaultProperties(for: .audio)
        properties["isBeatCounter"] = .bool(true)
        properties["volume"] = .number(1.0)
        properties["fadeIn"] = .number(0.0)
        properties["fadeOut"] = .number(0.0)

        let clip = TimelineClip(
            assetID: nil,
            name: name,
            kind: .audio,
            timeRange: timeRange,
            properties: properties
        )

        var simulatedLayers = layers
        let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
        applyAddedClips([(clip, layerID)])
        selectedClipIDs = [clip.id]
        return clip
    }

    // MARK: - Private Helpers

    private func findSnappedBeatStart(for time: CMTime, in beats: [CMTime]) -> CMTime {
        guard !beats.isEmpty else {
            return TimeRational.snapToFrame(time: time)
        }

        let timeSec = CMTimeGetSeconds(time)
        // Tìm beat gần nhất với thời điểm playhead
        var closest = beats[0]
        var minDiff = abs(CMTimeGetSeconds(closest) - timeSec)

        for beat in beats {
            let diff = abs(CMTimeGetSeconds(beat) - timeSec)
            if diff < minDiff {
                minDiff = diff
                closest = beat
            }
        }

        return closest
    }

    private func calculateDefaultBeatCounterDuration(from start: CMTime, in beats: [CMTime]) -> CMTime {
        let futureBeats = beats.filter { $0 >= start }.sorted { CMTimeCompare($0, $1) < 0 }
        // Mặc định tạo khối dài 2 vòng 8 (16 phách) nếu có đủ beat
        if futureBeats.count >= 17 {
            let span = CMTimeSubtract(futureBeats[16], start)
            if span > .zero { return span }
        } else if futureBeats.count >= 9 {
            let span = CMTimeSubtract(futureBeats[8], start)
            if span > .zero { return span }
        }

        return CMTime(seconds: 8.0, preferredTimescale: 600)
    }
}

