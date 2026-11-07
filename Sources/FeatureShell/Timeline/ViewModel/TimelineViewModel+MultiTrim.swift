import Foundation
import CoreMedia
import Domain

/// Extension trên TimelineViewModel cung cấp logic tính toán và thực thi batch trim handle đồng loạt khi chọn nhiều clip.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R7.1 (Command / Undo-Redo).
extension TimelineViewModel {
    /// Tính toán delta dời trim hiệu dụng sau khi đã clamp an toàn theo giới hạn tập thể của toàn bộ các clip được chọn.
    public func clampedGroupTrimDelta(isLeft: Bool, proposedDelta: CMTime) -> CMTime {
        let limits = isLeft
            ? TimelineGroupTrimEngine.calculateLeftLimits(layers: layers, selectedClipIDs: selectedClipIDs)
            : TimelineGroupTrimEngine.calculateRightLimits(layers: layers, selectedClipIDs: selectedClipIDs)
        return TimelineGroupTrimEngine.clamp(delta: proposedDelta, limits: limits)
    }

    /// Cập nhật offset dời visual đồng loạt trong thời gian thực khi đang kéo trim handle.
    public func updateGroupTrim(isLeft: Bool, dx: CGFloat) {
        let pps = pixelsPerSecond
        let ppf = pps / CGFloat(TimeRational.defaultFPS)
        let frameAlignedDx = round(dx / ppf) * ppf
        let rawDeltaSec = Double(frameAlignedDx / pps)
        let proposedDelta = CMTime(seconds: rawDeltaSec, preferredTimescale: 600)
        let effectiveDelta = clampedGroupTrimDelta(isLeft: isLeft, proposedDelta: proposedDelta)
        let effectiveOffset = CGFloat(CMTimeGetSeconds(effectiveDelta)) * pps

        if isLeft {
            groupTrimLeftOffset = effectiveOffset
        } else {
            groupTrimRightOffset = effectiveOffset
        }
    }

    /// Reset toàn bộ visual trim offset về 0 khi kết thúc hoặc huỷ kéo.
    public func resetGroupTrim() {
        groupTrimLeftOffset = 0
        groupTrimRightOffset = 0
    }

    /// Thực thi lưu và áp dụng thay đổi trim đồng loạt cho toàn bộ các clip được chọn (hỗ trợ Undo/Redo qua TimelineCommand.batch).
    public func commitGroupTrim(isLeft: Bool, delta: CMTime) {
        defer { resetGroupTrim() }
        guard delta != .zero else { return }

        var targets: [(clip: TimelineClip, layerID: UUID)] = []
        for layer in layers {
            for clip in layer.clips where selectedClipIDs.contains(clip.id) {
                targets.append((clip, layer.id))
            }
        }
        guard !targets.isEmpty else { return }

        let commands = targets.compactMap { target -> TimelineCommand? in
            let (newStart, newDuration, newSourceStart) = computeTrimmedValues(
                for: target.clip,
                isLeft: isLeft,
                delta: delta
            )
            return TimelineCommand.trimClip(
                clipID: target.clip.id,
                newStart: RationalTime(cmTime: newStart),
                newDuration: RationalTime(cmTime: newDuration),
                newSourceStart: newSourceStart.map { RationalTime(cmTime: $0) }
            )
        }

        if let executor = commandExecutor, !isApplyingCommand {
            _ = executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            return
        }

        applyDirectGroupTrim(targets: targets, isLeft: isLeft, delta: delta)
    }

    // MARK: - Private Helpers

    private func computeTrimmedValues(
        for clip: TimelineClip,
        isLeft: Bool,
        delta: CMTime
    ) -> (newStart: CMTime, newDuration: CMTime, newSourceStart: CMTime?) {
        let minDur = TimeRational.time(forFrame: 1)
        if isLeft {
            let proposedStart = CMTimeAdd(clip.timeRange.start, delta)
            let snappedStart = CMTimeMaximum(.zero, TimeRational.snapToFrame(time: proposedStart))
            let proposedDur = CMTimeSubtract(clip.timeRange.duration, delta)
            let snappedDur = CMTimeMaximum(minDur, TimeRational.snapToFrame(time: proposedDur))

            let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
            let deltaSourceSec = CMTimeGetSeconds(delta) * speed
            let proposedSourceSec = max(0.0, CMTimeGetSeconds(clip.sourceStartTime) + deltaSourceSec)
            let snappedSource = TimeRational.snapToFrame(time: CMTime(seconds: proposedSourceSec, preferredTimescale: 600))
            return (snappedStart, snappedDur, snappedSource)
        } else {
            let proposedDur = CMTimeAdd(clip.timeRange.duration, delta)
            let snappedDur = CMTimeMaximum(minDur, TimeRational.snapToFrame(time: proposedDur))
            return (clip.timeRange.start, snappedDur, nil)
        }
    }

    private func applyDirectGroupTrim(
        targets: [(clip: TimelineClip, layerID: UUID)],
        isLeft: Bool,
        delta: CMTime
    ) {
        for target in targets {
            guard let layerIndex = layers.firstIndex(where: { $0.id == target.layerID }),
                  let clipIndex = layers[layerIndex].clips.firstIndex(where: { $0.id == target.clip.id }) else {
                continue
            }
            let (newStart, newDuration, newSourceStart) = computeTrimmedValues(
                for: target.clip,
                isLeft: isLeft,
                delta: delta
            )
            layers[layerIndex].clips[clipIndex].trim(
                newStart: newStart,
                newDuration: newDuration,
                newSourceStart: newSourceStart
            )
            layers[layerIndex].sortClips()
        }
        cleanEmptyLayers()
        onClipsTrimmed?()
    }
}

