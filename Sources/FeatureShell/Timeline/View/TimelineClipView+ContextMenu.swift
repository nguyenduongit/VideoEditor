import SwiftUI
import CoreMedia
import Domain

extension TimelineClipView {
    @ViewBuilder
    var clipContextMenu: some View {
        commonEditSection
        Divider()
        attributesSection
        Divider()
        kindSpecificSection
        Divider()
        destructiveSection
    }

    @ViewBuilder
    private var commonEditSection: some View {
        Button { contextActions?.onCut(clip.id) } label: {
            Label(String(localized: "Cut"), systemImage: "scissors")
        }
        Button { contextActions?.onCopy(clip.id) } label: {
            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
        }
        Button { contextActions?.onPaste() } label: {
            Label(String(localized: "Paste at Playhead"), systemImage: "clipboard")
        }
        .disabled(!(contextActions?.canPasteClip ?? false))

        Button { contextActions?.onDuplicate(clip.id) } label: {
            Label(String(localized: "Duplicate"), systemImage: "plus.square.on.square")
        }
        if canSplitAtPlayhead {
            Button { contextActions?.onSplitAtPlayhead(clip.id) } label: {
                Label(String(localized: "Split at Playhead"), systemImage: "rectangle.split.2x1")
            }
        }
    }

    @ViewBuilder
    private var attributesSection: some View {
        Button { contextActions?.onCopyAttributes(clip.id) } label: {
            Label(String(localized: "Copy Attributes"), systemImage: "eyedropper")
        }
        Button { contextActions?.onPasteAttributes(clip.id) } label: {
            Label(String(localized: "Paste Attributes..."), systemImage: "paintbrush")
        }
        .disabled(!(contextActions?.canPasteAttributes ?? false))

        Button { contextActions?.onResetAttributes(clip.id) } label: {
            Label(String(localized: "Reset Attributes"), systemImage: "arrow.counterclockwise")
        }
    }

    @ViewBuilder
    private var kindSpecificSection: some View {
        switch clip.kind {
        case .video:
            videoSpecificMenu
        case .audio:
            audioSpecificMenu
        case .image:
            transformSubmenu
            durationSubmenu(includeMatchBelow: false)
        case .text:
            textSpecificMenu
        case .adjustment:
            durationSubmenu(includeMatchBelow: true)
            saveAsPresetButton
        case .effect:
            durationSubmenu(includeMatchBelow: true)
        case .sticker:
            transformSubmenu
            speedSubmenu
            durationSubmenu(includeMatchBelow: true)
        }
    }

    @ViewBuilder
    private var videoSpecificMenu: some View {
        if canExtractAudio {
            Button { onExtractAudio?() } label: {
                Label(String(localized: "Extract Audio"), systemImage: "waveform.badge.plus")
            }
        }
        muteClipAudioButton
        speedSubmenu
        transformSubmenu
    }

    @ViewBuilder
    private var audioSpecificMenu: some View {
        muteClipAudioButton
        beatMarkersSubmenu
        audioFadeSubmenu
        speedSubmenu
    }

    @ViewBuilder
    private var textSpecificMenu: some View {
        Button { contextActions?.onApplyTextStyleToTrack(clip.id) } label: {
            Label(String(localized: "Apply Style to All Text in Track"), systemImage: "textformat.size")
        }
        durationSubmenu(includeMatchBelow: true)
        saveAsPresetButton
    }

    private var muteClipAudioButton: some View {
        let isMutedClip = (clip.properties["volume"]?.asNumber ?? 1.0) <= 0.001
        return Button { contextActions?.onToggleMuteClipAudio(clip.id) } label: {
            Label(
                isMutedClip ? String(localized: "Unmute Clip Audio") : String(localized: "Mute Clip Audio"),
                systemImage: isMutedClip ? "speaker.wave.2" : "speaker.slash"
            )
        }
    }

    private var saveAsPresetButton: some View {
        Button { onSavePreset?(clip) } label: {
            Label(String(localized: "Save as Preset..."), systemImage: "square.and.arrow.down")
        }
    }

    private var speedSubmenu: some View {
        Menu {
            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { spd in
                Button("\(String(format: "%.1f", spd))x") {
                    contextActions?.onSetSpeed(clip.id, spd)
                }
            }
        } label: {
            Label(String(localized: "Speed"), systemImage: "gauge.with.needle")
        }
    }

    private var transformSubmenu: some View {
        Menu {
            Button(String(localized: "Flip Horizontal")) { contextActions?.onFlip(clip.id, true) }
            Button(String(localized: "Flip Vertical")) { contextActions?.onFlip(clip.id, false) }
            Divider()
            Button(String(localized: "Reset Transform")) { contextActions?.onResetTransform(clip.id) }
        } label: {
            Label(String(localized: "Transform"), systemImage: "crop.rotate")
        }
    }

    private func durationSubmenu(includeMatchBelow: Bool) -> some View {
        Menu {
            ForEach([2.0, 3.0, 5.0, 10.0], id: \.self) { sec in
                Button("\(Int(sec))s") { contextActions?.onSetDuration(clip.id, sec) }
            }
            if includeMatchBelow {
                Divider()
                Button(String(localized: "Match Below Video / Timeline")) {
                    contextActions?.onMatchDurationBelow(clip.id)
                }
            }
        } label: {
            Label(String(localized: "Duration"), systemImage: "clock")
        }
    }

    private var beatMarkersSubmenu: some View {
        Menu {
            Button(String(localized: "Auto Detect Major Beats (Beat 1)")) { contextActions?.onAutoMarkBeats(clip.id, .majorOnly) }
            Button(String(localized: "Auto Detect All Beats (Beat 2)")) { contextActions?.onAutoMarkBeats(clip.id, .allBeats) }
            Divider()
            Button(String(localized: "Add / Remove Beat at Playhead")) { contextActions?.onToggleBeatAtPlayhead(clip.id) }
            Button(String(localized: "Clear All Beats")) { contextActions?.onClearBeats(clip.id) }
        } label: {
            Label(String(localized: "Beat Markers"), systemImage: "metronome")
        }
    }

    private var audioFadeSubmenu: some View {
        Menu {
            Button(String(localized: "Fade In / Out 0.5s")) { contextActions?.onSetAudioFade(clip.id, 0.5) }
            Button(String(localized: "Fade In / Out 1.0s")) { contextActions?.onSetAudioFade(clip.id, 1.0) }
            Divider()
            Button(String(localized: "Clear Fades")) { contextActions?.onSetAudioFade(clip.id, 0.0) }
        } label: {
            Label(String(localized: "Audio Fade"), systemImage: "waveform.path.ecg")
        }
    }

    private var destructiveSection: some View {
        Button(role: .destructive) {
            contextActions?.onDelete(clip.id)
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }

    private var canExtractAudio: Bool {
        clip.kind == .video && clip.mediaURL != nil && clip.properties["isAudioExtracted"]?.asBool != true
    }

    private var canSplitAtPlayhead: Bool {
        guard let playhead = contextActions?.playheadTime else { return false }
        let snapped = TimeRational.snapToFrame(time: playhead)
        return snapped > clip.timeRange.start && snapped < clip.timeRange.end
            && (snapped - clip.timeRange.start) >= TimelineClip.minDuration
            && (clip.timeRange.end - snapped) >= TimelineClip.minDuration
    }
}
