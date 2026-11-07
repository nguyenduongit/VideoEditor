import Foundation
import CoreMedia
import Domain

/// Audio inspection and volume mute state extension for InspectorViewModel.
/// Complies with R3.1 (<= 300 lines) and R6.2 of AGENTS.md.
extension InspectorViewModel {
    public var isSelectedClipLayerMuted: Bool {
        guard let clipID = selectedClip?.id,
              let timelineViewModel else { return false }
        return timelineViewModel.layers.first(where: { layer in
            layer.clips.contains(where: { $0.id == clipID })
        })?.isMuted ?? false
    }

    public var isVolumeMuted: Bool {
        isSelectedClipLayerMuted || currentVolume <= 0.001
    }

    public var currentVolume: Double {
        liveNumber(for: "volume", default: 1.0)
    }

    public var volumeLeadingIcon: String {
        isVolumeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }

    public var volumeLeadingIconHelp: String {
        if isSelectedClipLayerMuted {
            return String(localized: "Layer đang tắt tiếng — Click để bật tiếng Layer")
        } else if currentVolume <= 0.001 {
            return String(localized: "Clip đang tắt tiếng — Click để khôi phục âm lượng")
        } else {
            return String(localized: "Click để tắt tiếng nhanh")
        }
    }

    public func toggleVolumeMute() {
        guard let clip = selectedClip, let timelineViewModel else { return }

        // If the layer is muted on the timeline, unmuting the layer is prioritized
        if isSelectedClipLayerMuted,
           let layer = timelineViewModel.layers.first(where: { $0.clips.contains(where: { $0.id == clip.id }) }) {
            timelineViewModel.toggleMute(for: layer.id)
            return
        }

        // Toggle clip-level volume
        let vol = currentVolume
        if vol > 0.001 {
            preMuteVolumeByClipID[clip.id] = vol
            liveProperties["volume"] = .number(0.0)
        } else {
            let restored = preMuteVolumeByClipID[clip.id] ?? 1.0
            liveProperties["volume"] = .number(max(0.05, restored))
        }

        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        if let executor = timelineViewModel.commandExecutor {
            executor.execute(cmd)
        } else {
            timelineViewModel.updateClipLiveProperties(clipID: clip.id, properties: liveProperties)
        }
        syncWithSelection()
    }
}

