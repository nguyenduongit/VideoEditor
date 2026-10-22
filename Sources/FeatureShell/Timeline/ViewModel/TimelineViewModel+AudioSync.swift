import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Determines whether the currently selected clips (exactly 2 clips with audio/video) can be auto-aligned.
    public var canSyncAudio: Bool {
        guard selectedClipIDs.count == 2 else { return false }
        let selectedClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        guard selectedClips.count == 2 else { return false }
        guard selectedClips.allSatisfy({ $0.mediaURL != nil }) else { return false }
        return selectedClips.allSatisfy { $0.kind == .video || $0.kind == .audio }
    }

    /// Automatically aligns the two selected clips by analyzing their acoustic waveforms.
    public func syncSelectedAudio() {
        guard canSyncAudio, !isSyncingAudio else { return }
        let selectedClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        guard selectedClips.count == 2 else { return }

        // Video clip acts as anchor/reference; audio clip is the target to be aligned.
        let refClip: TimelineClip
        let targetClip: TimelineClip
        if let video = selectedClips.first(where: { $0.kind == .video }),
           let audio = selectedClips.first(where: { $0.kind == .audio }) {
            refClip = video
            targetClip = audio
        } else {
            refClip = selectedClips[0]
            targetClip = selectedClips[1]
        }

        guard let refURL = refClip.mediaURL, let targetURL = targetClip.mediaURL else { return }
        guard let alignmentService = audioAlignmentService else {
            onAudioSyncResult?(false, "Dịch vụ đồng bộ âm thanh chưa được khởi tạo.")
            return
        }

        isSyncingAudio = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isSyncingAudio = false }

            let matchResult = await alignmentService.calculateAlignmentOffset(
                sourceURL1: refURL,
                sourceURL2: targetURL
            )

            guard let matchResult, matchResult.isMatch else {
                let msg = "Không tìm thấy điểm khớp âm thanh (độ tương quan thấp)."
                self.onAudioSyncResult?(false, msg)
                return
            }

            self.applyAlignment(
                offsetSeconds: matchResult.offsetSeconds,
                refClip: refClip,
                targetClip: targetClip
            )

            let successMsg = "Đã khớp âm thanh thành công (Độ lệch: \(String(format: "%+.2fs", matchResult.offsetSeconds)), độ tin cậy: \(String(format: "%.1f%%", matchResult.correlation * 100)))."
            self.onAudioSyncResult?(true, successMsg)
        }
    }

    private func applyAlignment(
        offsetSeconds: Double,
        refClip: TimelineClip,
        targetClip: TimelineClip
    ) {
        // Formula: T_target = T_ref - S_ref + S_target + offset
        let tRefSec = CMTimeGetSeconds(refClip.timeRange.start)
        let sRefSec = CMTimeGetSeconds(refClip.sourceStartTime)
        let sTargetSec = CMTimeGetSeconds(targetClip.sourceStartTime)

        let proposedStartSec = tRefSec - sRefSec + sTargetSec + offsetSeconds

        guard let targetLayerIndex = layers.firstIndex(where: { $0.clips.contains { $0.id == targetClip.id } }) else { return }
        let targetLayerID = layers[targetLayerIndex].id

        if proposedStartSec >= 0 {
            let targetCMTime = CMTime(seconds: proposedStartSec, preferredTimescale: 600)
            let snappedStart = TimeRational.snapToFrame(time: targetCMTime)
            let rationalStart = RationalTime(cmTime: snappedStart)

            if let executor = commandExecutor, !isApplyingCommand {
                executor.execute(
                    .moveClip(clipID: targetClip.id, targetLayerID: targetLayerID, newStartTime: rationalStart),
                    title: "Khớp âm thanh"
                )
            } else {
                if let clipIdx = layers[targetLayerIndex].clips.firstIndex(where: { $0.id == targetClip.id }) {
                    layers[targetLayerIndex].clips[clipIdx].shift(to: snappedStart)
                    onClipsTrimmed?()
                }
            }
        } else {
            let negativeOffset = -proposedStartSec
            let advanceCMTime = CMTime(seconds: negativeOffset, preferredTimescale: 600)
            let newSourceStart = targetClip.sourceStartTime + advanceCMTime
            let newDurationCM = CMTimeMaximum(TimelineClip.minDuration, targetClip.timeRange.duration - advanceCMTime)

            let rationalStart = RationalTime.zero
            let rationalDuration = RationalTime(cmTime: newDurationCM)
            let rationalSourceStart = RationalTime(cmTime: newSourceStart)

            if let executor = commandExecutor, !isApplyingCommand {
                executor.execute(
                    .trimClip(
                        clipID: targetClip.id,
                        newStart: rationalStart,
                        newDuration: rationalDuration,
                        newSourceStart: rationalSourceStart
                    ),
                    title: "Khớp âm thanh"
                )
            } else {
                if let clipIdx = layers[targetLayerIndex].clips.firstIndex(where: { $0.id == targetClip.id }) {
                    layers[targetLayerIndex].clips[clipIdx].trim(
                        newStart: .zero,
                        newDuration: newDurationCM,
                        newSourceStart: newSourceStart
                    )
                    onClipsTrimmed?()
                }
            }
        }
    }
}
