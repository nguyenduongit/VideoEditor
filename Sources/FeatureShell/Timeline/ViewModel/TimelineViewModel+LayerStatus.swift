import Foundation
import CoreMedia
import Domain
import DesignSystem

extension TimelineViewModel {
    public func toggleLock(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isLocked.toggle()
        onLayerLockToggled?(layerID, layers[index].isLocked)
    }

    public func toggleHide(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard layers[index].kind != .audio else { return }
        layers[index].isHidden.toggle()
        onLayerHideToggled?(layerID, layers[index].isHidden)
    }

    public func toggleMute(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isMuted.toggle()
        onLayerMuteToggled?(layerID, layers[index].isMuted)
    }

    public func layerHeight(for kind: ClipKind) -> CGFloat {
        kind.presentation.defaultLayerHeight
    }

    public var contentWidth: CGFloat {
        let totalSec = CMTimeGetSeconds(totalDuration)
        let totalWidth = CGFloat(totalSec) * pixelsPerSecond + TimelineZoom.trailingPadding
        return max(viewportWidth, totalWidth)
    }

    public var totalLayersHeight: CGFloat {
        layers.reduce(CGFloat.zero) { $0 + layerHeight(for: $1.kind) }
    }

    // MARK: - Hệ thống Công cụ Biên tập Nhanh (Auto Trim, Shift to Start 00:00, Mute Video)

    /// Xác định danh sách các clip mục tiêu để Auto Trim (ưu tiên các clip đang chọn nếu >= 2, ngược lại lấy Video & Audio chính).
    private func resolveOverlapTargetClips() -> [TimelineClip] {
        let unlockedClips = layers.filter { !$0.isLocked }.flatMap(\.clips)
        let selected = unlockedClips.filter { selectedClipIDs.contains($0.id) }
        if selected.count >= 2 {
            return selected
        }
        return unlockedClips.filter { $0.kind == .video || $0.kind == .audio }
    }

    /// Kiểm tra xem có thể thực hiện `Auto Trim` (Cắt gọn phần thừa 2 đầu ngoài đoạn giao nhau) hay không.
    public var canAutoTrim: Bool {
        let targets = resolveOverlapTargetClips()
        guard targets.count >= 2 else { return false }
        guard let maxStart = targets.map(\.timeRange.start).max(),
              let minEnd = targets.map(\.timeRange.end).min() else { return false }
        let overlapDur = CMTimeSubtract(minEnd, maxStart)
        guard overlapDur >= TimelineClip.minDuration else { return false }

        return targets.contains { clip in
            abs(CMTimeGetSeconds(clip.timeRange.start - maxStart)) > 0.005 ||
            abs(CMTimeGetSeconds(clip.timeRange.end - minEnd)) > 0.005
        }
    }

    /// Công cụ Hệ thống: Tự động cắt bỏ phần thừa ở cả 2 đầu của các clip mục tiêu theo đúng đoạn giao nhau (Overlap),
    /// đồng thời co/giãn các layer phụ (`Adjustment`, `Effect`) khớp theo đoạn giao nhau đó. Hỗ trợ Undo/Redo 1 bước.
    @discardableResult
    public func autoTrimOverlapClips() -> Bool {
        let targets = resolveOverlapTargetClips()
        guard targets.count >= 2,
              let overlapStart = targets.map(\.timeRange.start).max(),
              let overlapEnd = targets.map(\.timeRange.end).min() else { return false }
        let snappedStart = TimeRational.snapToFrame(time: overlapStart)
        let snappedDur = TimeRational.snapToFrame(time: CMTimeSubtract(overlapEnd, snappedStart))
        guard snappedDur >= TimelineClip.minDuration else { return false }

        let rationalStart = RationalTime(cmTime: snappedStart)
        let rationalDur = RationalTime(cmTime: snappedDur)
        var batchCommands: [TimelineCommand] = []

        for clip in targets {
            let headDelta = CMTimeMaximum(.zero, CMTimeSubtract(snappedStart, clip.timeRange.start))
            let newSourceStart: RationalTime?
            if clip.kind.hasFixedSourceDuration {
                let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
                let scaledDelta = CMTimeMultiplyByFloat64(headDelta, multiplier: speed)
                newSourceStart = RationalTime(cmTime: TimeRational.snapToFrame(time: clip.sourceStartTime + scaledDelta))
            } else {
                newSourceStart = nil
            }
            batchCommands.append(
                .trimClip(clipID: clip.id, newStart: rationalStart, newDuration: rationalDur, newSourceStart: newSourceStart)
            )
        }

        for layer in layers where !layer.isLocked && (layer.kind == .adjustment || layer.kind == .effect) {
            for auxClip in layer.clips where !targets.contains(where: { $0.id == auxClip.id }) {
                batchCommands.append(
                    .trimClip(clipID: auxClip.id, newStart: rationalStart, newDuration: rationalDur, newSourceStart: nil)
                )
            }
        }

        guard !batchCommands.isEmpty else { return false }
        if let executor = commandExecutor, !isApplyingCommand {
            return executor.execute(.batch(commands: batchCommands), title: "Auto Trim")
        }
        return false
    }

    /// Checks whether any selected clip on an unlocked track has a gap before it (can be compacted backward toward 00:00 or a preceding clip).
    public var canCompactBackward: Bool {
        guard !selectedClipIDs.isEmpty else { return false }
        for layer in layers where !layer.isLocked {
            var backwardCursor = CMTime.zero
            let sortedClips = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
            for clip in sortedClips {
                if selectedClipIDs.contains(clip.id) {
                    if CMTimeGetSeconds(clip.timeRange.start - backwardCursor) > 0.005 {
                        return true
                    }
                    backwardCursor = clip.timeRange.end
                } else {
                    backwardCursor = clip.timeRange.end
                }
            }
        }
        return false
    }

    /// Compacts ONLY the selected clips backward along their respective tracks, snapping flush against the preceding clip's end or `00:00`.
    @discardableResult
    public func compactSelectedClipsBackward() -> Bool {
        guard !selectedClipIDs.isEmpty else { return false }
        var batchCommands: [TimelineCommand] = []

        for layer in layers where !layer.isLocked {
            var backwardCursor = CMTime.zero
            let sortedClips = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
            for clip in sortedClips {
                if selectedClipIDs.contains(clip.id) {
                    let targetStart = TimeRational.snapToFrame(time: backwardCursor)
                    if CMTimeGetSeconds(clip.timeRange.start - targetStart) > 0.005 {
                        batchCommands.append(
                            .moveClip(
                                clipID: clip.id,
                                targetLayerID: layer.id,
                                newStartTime: RationalTime(cmTime: targetStart)
                            )
                        )
                        backwardCursor = CMTimeAdd(targetStart, clip.timeRange.duration)
                    } else {
                        backwardCursor = clip.timeRange.end
                    }
                } else {
                    backwardCursor = clip.timeRange.end
                }
            }
        }

        guard !batchCommands.isEmpty else { return false }
        if let executor = commandExecutor, !isApplyingCommand {
            return executor.execute(.batch(commands: batchCommands), title: "Compact Backward")
        }
        return false
    }

    /// Legacy alias for automated workflow pipelines (used when no explicit selection exists).
    public var canShiftToStart: Bool {
        canCompactBackward
    }

    /// Automated pipeline helper: compacts selected clips backward, or compacts all unlocked clips to `00:00` when invoked without selection in AI workflows.
    @discardableResult
    public func shiftClipsToTimelineStart() -> Bool {
        if !selectedClipIDs.isEmpty {
            return compactSelectedClipsBackward()
        }
        let unlockedLayers = layers.filter { !$0.isLocked }
        let allUnlockedClips = unlockedLayers.flatMap(\.clips)
        guard let minStart = allUnlockedClips.map(\.timeRange.start).min(),
              CMTimeGetSeconds(minStart) > 0.005 else { return false }

        var batchCommands: [TimelineCommand] = []
        for layer in unlockedLayers {
            let clipsInLayer = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
            for clip in clipsInLayer {
                let shiftedStart = TimeRational.snapToFrame(time: CMTimeMaximum(.zero, clip.timeRange.start - minStart))
                let rationalStart = RationalTime(cmTime: shiftedStart)
                let rationalDur = RationalTime(cmTime: clip.timeRange.duration)
                let rationalSrc = clip.kind.hasFixedSourceDuration ? RationalTime(cmTime: clip.sourceStartTime) : nil
                batchCommands.append(
                    .trimClip(clipID: clip.id, newStart: rationalStart, newDuration: rationalDur, newSourceStart: rationalSrc)
                )
            }
        }

        guard !batchCommands.isEmpty else { return false }
        if let executor = commandExecutor, !isApplyingCommand {
            return executor.execute(.batch(commands: batchCommands), title: "Compact Backward")
        }
        return false
    }

    /// Mutes all unlocked video tracks and sets clip audio volume to 0 with 1-step Undo/Redo support.
    @discardableResult
    public func muteVideoTracks() -> Bool {
        var batchCommands: [TimelineCommand] = []
        for layer in layers where !layer.isLocked && layer.kind == .video {
            for clip in layer.clips {
                var props = clip.properties
                props["volume"] = .number(0.0)
                props["isClipMuted"] = .bool(true)
                batchCommands.append(.updateClipProperties(clipID: clip.id, properties: props))
            }
            if !layer.isMuted {
                batchCommands.append(
                    .setLayerStatus(layerID: layer.id, isLocked: layer.isLocked, isHidden: layer.isHidden, isMuted: true)
                )
            }
        }
        guard !batchCommands.isEmpty else { return false }
        if let executor = commandExecutor, !isApplyingCommand {
            return executor.execute(.batch(commands: batchCommands), title: "Mute Video Tracks")
        }
        return false
    }
}
