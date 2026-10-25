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

    /// Thực thi đồng bộ âm thanh và tự động cắt phần nhạc thừa cho AI Agent (tự động đưa Video & Audio từ Media Library xuống nếu Timeline đang trống).
    public func performAISyncAudio(
        availableAssets: [MediaAsset],
        muteVideo: Bool = true
    ) async -> (isSuccess: Bool, message: String) {
        let preservedSelection = selectedClipIDs
        var allClips = layers.flatMap(\.clips)

        if !allClips.contains(where: { $0.kind == .video }),
           let videoAsset = availableAssets.first(where: { $0.type == .video }) {
            addAsset(videoAsset, at: .zero)
            allClips = layers.flatMap(\.clips)
        }

        if !allClips.contains(where: { $0.kind == .audio }),
           let audioAsset = availableAssets.first(where: { $0.type == .audio }) {
            addAsset(audioAsset, at: .zero)
            allClips = layers.flatMap(\.clips)
        }

        selectedClipIDs = preservedSelection

        guard let refClip = allClips.first(where: { $0.kind == .video }),
              let targetClip = allClips.first(where: { $0.kind == .audio }),
              let refURL = refClip.mediaURL,
              let targetURL = targetClip.mediaURL else {
            return (false, "Cần có ít nhất 1 clip Video và 1 clip Audio trong Media Library hoặc trên Timeline để đồng bộ.")
        }

        var offsetSec = 0.0
        var correlationPct = 0.0
        if let alignmentService = audioAlignmentService,
           let matchResult = await alignmentService.calculateAlignmentOffset(sourceURL1: refURL, sourceURL2: targetURL),
           matchResult.isMatch {
            offsetSec = matchResult.offsetSeconds
            correlationPct = Double(matchResult.correlation) * 100.0
        }

        applyTwoWayOverlapTrim(
            offsetSeconds: offsetSec,
            refClip: refClip,
            targetClip: targetClip,
            muteVideo: muteVideo
        )
        selectedClipIDs = preservedSelection

        let muteNote = muteVideo ? ", đã tắt tiếng video gốc" : ""
        if correlationPct > 0 {
            return (true, "Đã đồng bộ sóng âm (lệch \(String(format: "%+.2fs", offsetSec)), tương quan \(String(format: "%.0f%%", correlationPct)))\(muteNote) và cắt gọn phần thừa ở cả 2 đầu của Video và Audio.")
        } else {
            return (true, "Đã căn chỉnh nhạc khớp với đầu video\(muteNote) và cắt bỏ phần thừa ở 2 đầu của Video và Audio.")
        }
    }

    private func applyTwoWayOverlapTrim(
        offsetSeconds: Double,
        refClip: TimelineClip,
        targetClip: TimelineClip,
        muteVideo: Bool = true
    ) {
        let tRefSec = CMTimeGetSeconds(refClip.timeRange.start)
        let sRefSec = CMTimeGetSeconds(refClip.sourceStartTime)
        let sTargetSec = CMTimeGetSeconds(targetClip.sourceStartTime)
        let relativeShift = (tRefSec - sRefSec) + sTargetSec + offsetSeconds

        var videoSourceStart = refClip.sourceStartTime
        var videoAvailDur = refClip.timeRange.duration
        var audioSourceStart = targetClip.sourceStartTime
        var audioAvailDur = targetClip.timeRange.duration

        if relativeShift > 0 {
            let cutHead = TimeRational.snapToFrame(time: CMTime(seconds: relativeShift, preferredTimescale: 600))
            videoSourceStart = refClip.sourceStartTime + cutHead
            videoAvailDur = CMTimeMaximum(TimelineClip.minDuration, refClip.timeRange.duration - cutHead)
        } else if relativeShift < 0 {
            let cutHead = TimeRational.snapToFrame(time: CMTime(seconds: -relativeShift, preferredTimescale: 600))
            audioSourceStart = targetClip.sourceStartTime + cutHead
            audioAvailDur = CMTimeMaximum(TimelineClip.minDuration, targetClip.timeRange.duration - cutHead)
        }

        let commonDuration = TimeRational.snapToFrame(time: CMTimeMinimum(videoAvailDur, audioAvailDur))
        let rationalZero = RationalTime.zero
        let rationalDur = RationalTime(cmTime: commonDuration)

        var batchCommands: [TimelineCommand] = [
            .trimClip(
                clipID: refClip.id,
                newStart: rationalZero,
                newDuration: rationalDur,
                newSourceStart: RationalTime(cmTime: videoSourceStart)
            ),
            .trimClip(
                clipID: targetClip.id,
                newStart: rationalZero,
                newDuration: rationalDur,
                newSourceStart: RationalTime(cmTime: audioSourceStart)
            )
        ]

        if muteVideo {
            var videoProps = refClip.properties
            videoProps["volume"] = .number(0.0)
            batchCommands.append(.updateClipProperties(clipID: refClip.id, properties: videoProps))
            if let videoLayer = layers.first(where: { $0.clips.contains(where: { $0.id == refClip.id }) }) {
                batchCommands.append(
                    .setLayerStatus(
                        layerID: videoLayer.id,
                        isLocked: videoLayer.isLocked,
                        isHidden: videoLayer.isHidden,
                        isMuted: true
                    )
                )
            }
        }

        for layer in layers where layer.kind == .adjustment {
            for adjClip in layer.clips {
                batchCommands.append(
                    .trimClip(clipID: adjClip.id, newStart: rationalZero, newDuration: rationalDur, newSourceStart: nil)
                )
            }
        }

        if let executor = commandExecutor, !isApplyingCommand {
            executor.execute(.batch(commands: batchCommands), title: "Đồng bộ & Cắt phần thừa 2 đầu")
        }
    }

    func applyAlignment(
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

        let targetStartCM: CMTime
        let targetSourceStartCM: CMTime
        let availableDurationCM: CMTime

        if proposedStartSec >= 0 {
            let targetCMTime = CMTime(seconds: proposedStartSec, preferredTimescale: 600)
            targetStartCM = TimeRational.snapToFrame(time: targetCMTime)
            targetSourceStartCM = targetClip.sourceStartTime
            availableDurationCM = targetClip.timeRange.duration
        } else {
            let negativeOffset = -proposedStartSec
            let advanceCMTime = CMTime(seconds: negativeOffset, preferredTimescale: 600)
            targetStartCM = .zero
            targetSourceStartCM = targetClip.sourceStartTime + advanceCMTime
            availableDurationCM = CMTimeMaximum(TimelineClip.minDuration, targetClip.timeRange.duration - advanceCMTime)
        }

        // Tail Auto-Trim: Cap audio duration so it doesn't exceed the reference clip's end time (matching tham khao)
        let refEnd = refClip.timeRange.end
        let maxAllowedDuration = CMTimeMaximum(TimelineClip.minDuration, refEnd - targetStartCM)
        let effectiveDuration = CMTimeMinimum(availableDurationCM, maxAllowedDuration)

        let rationalStart = RationalTime(cmTime: targetStartCM)
        let rationalDuration = RationalTime(cmTime: effectiveDuration)
        let rationalSourceStart = RationalTime(cmTime: targetSourceStartCM)

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
                    newStart: targetStartCM,
                    newDuration: effectiveDuration,
                    newSourceStart: targetSourceStartCM
                )
                onClipsTrimmed?()
            }
        }
    }
}
