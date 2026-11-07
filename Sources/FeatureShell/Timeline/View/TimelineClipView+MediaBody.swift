import SwiftUI
import CoreMedia
import Domain
import DesignSystem

extension TimelineClipView {
    @ViewBuilder
    func clipMediaBody(width: CGFloat) -> some View {
        let bodyH = max(10, height - 22)
        let activeSrc = activeSourceStartTime
        if clip.kind.presentation.hasFilmstrip {
            VideoThumbnailFilmstripView(
                clip: clip,
                activeSourceStartTime: activeSrc,
                thumbnailService: thumbnailService,
                waveformService: waveformService,
                pixelsPerSecond: pixelsPerSecond,
                width: width,
                height: bodyH,
                isMuted: isMuted
            )
        } else if clip.properties["isBeatCounter"]?.asBool == true {
            DanceBeatCounterStripView(
                clip: clip,
                width: width,
                height: bodyH,
                pixelsPerSecond: pixelsPerSecond,
                beatTimes: beatTimes
            )
            .opacity(isAudioMuted ? 0.35 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isAudioMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.waveformAudioBackground)
        } else if clip.kind.presentation.hasWaveform {
            let inSec = clip.properties["fadeIn"]?.asNumber ?? 0.0
            let outSec = clip.properties["fadeOut"]?.asNumber ?? 0.0
            let speed = clip.properties["speed"]?.asNumber ?? 1.0
            AudioWaveformView(
                url: clip.mediaURL,
                service: waveformService,
                sourceStartTime: activeSrc,
                sourceDuration: clip.maxDuration,
                pixelsPerSecond: pixelsPerSecond,
                fadeIn: inSec,
                fadeOut: outSec,
                clipDuration: clip.timeRange.duration,
                speed: speed
            )
            .opacity(isAudioMuted ? 0.35 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isAudioMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.waveformAudioBackground)
        } else {
            Spacer(minLength: 0)
        }
    }
}

