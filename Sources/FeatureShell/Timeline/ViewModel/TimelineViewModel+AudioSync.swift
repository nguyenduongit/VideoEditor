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
            onAudioSyncResult?(false, "Audio alignment service is not initialized.")
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
                let msg = "No matching audio alignment point found (low correlation)."
                self.onAudioSyncResult?(false, msg)
                return
            }

            self.applyAlignment(
                offsetSeconds: matchResult.offsetSeconds,
                refClip: refClip,
                targetClip: targetClip
            )

            let successMsg = "Audio synced successfully (Offset: \(String(format: "%+.2fs", matchResult.offsetSeconds)), confidence: \(String(format: "%.1f%%", matchResult.correlation * 100)))."
            self.onAudioSyncResult?(true, successMsg)
        }
    }

    /// Thực thi công cụ nguyên tử `Sync Audio`: chỉ phân tích waveform và gióng khớp vị trí Audio theo Video gốc (không tự ý cắt hay mute).
    public func performAISyncAudio(
        availableAssets: [MediaAsset]
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
            return (false, "At least 1 Video clip and 1 Audio clip are required in the Media Library or on the Timeline to sync.")
        }

        var offsetSec = 0.0
        var correlationPct = 0.0
        if let alignmentService = audioAlignmentService,
           let matchResult = await alignmentService.calculateAlignmentOffset(sourceURL1: refURL, sourceURL2: targetURL),
           matchResult.isMatch {
            offsetSec = matchResult.offsetSeconds
            correlationPct = Double(matchResult.correlation) * 100.0
        }

        applyAlignment(
            offsetSeconds: offsetSec,
            refClip: refClip,
            targetClip: targetClip,
            capTailToReference: false
        )
        selectedClipIDs = preservedSelection

        if correlationPct > 0 {
            return (true, "Waveform synced (offset \(String(format: "%+.2fs", offsetSec)), correlation \(String(format: "%.0f%%", correlationPct))).")
        } else {
            return (true, "Aligned audio track to the start of the video.")
        }
    }

    func applyAlignment(
        offsetSeconds: Double,
        refClip: TimelineClip,
        targetClip: TimelineClip,
        capTailToReference: Bool = true
    ) {
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

        let effectiveDuration: CMTime
        if capTailToReference {
            let refEnd = refClip.timeRange.end
            let maxAllowedDuration = CMTimeMaximum(TimelineClip.minDuration, refEnd - targetStartCM)
            effectiveDuration = CMTimeMinimum(availableDurationCM, maxAllowedDuration)
        } else {
            effectiveDuration = availableDurationCM
        }

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
                title: "Sync Audio"
            )
        } else if let clipIdx = layers[targetLayerIndex].clips.firstIndex(where: { $0.id == targetClip.id }) {
            layers[targetLayerIndex].clips[clipIdx].trim(
                newStart: targetStartCM,
                newDuration: effectiveDuration,
                newSourceStart: targetSourceStartCM
            )
            onClipsTrimmed?()
        }
    }
}
