import SwiftUI
import Domain

extension TimelineClipView {
    @ViewBuilder
    var clipContextMenu: some View {
        if canExtractAudio {
            Button {
                onExtractAudio?()
            } label: {
                Label("Tách âm thanh", systemImage: "waveform.badge.plus")
            }
        }

        if clip.kind == .text {
            Button {
                onSavePreset?(clip)
            } label: {
                Label(String(localized: "Save as Preset..."), systemImage: "square.and.arrow.down")
            }
        }
    }

    private var canExtractAudio: Bool {
        clip.kind == .video && clip.mediaURL != nil && clip.properties["isAudioExtracted"]?.asBool != true
    }
}

