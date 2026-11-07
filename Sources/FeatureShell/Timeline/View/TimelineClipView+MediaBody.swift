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

    /// Đường line mảnh hiển thị trực quan tỷ lệ thời lượng `[In (Cyan) | Loop (Mint Green) | Out (Amber)]`
    /// ngay dưới đáy khối Text / Sticker Clip trên Timeline.
    @ViewBuilder
    func clipAnimationDurationLine(width: CGFloat, duration: CMTime) -> some View {
        if let anim = resolvedClipAnimation,
           anim.hasInAnimation || anim.hasOutAnimation || anim.hasLoopAnimation {
            let totalSec = max(0.1, CMTimeGetSeconds(duration))
            let inRatio = anim.hasInAnimation ? min(1.0, max(0.0, anim.inDuration / totalSec)) : 0.0
            let outRatio = anim.hasOutAnimation ? min(max(0.0, 1.0 - inRatio), max(0.0, anim.outDuration / totalSec)) : 0.0
            let loopRatio = max(0.0, 1.0 - inRatio - outRatio)

            let inW = width * CGFloat(inRatio)
            let loopW = width * CGFloat(loopRatio)
            let outW = width * CGFloat(outRatio)

            HStack(spacing: 0) {
                if inW > 0.5 {
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.82, blue: 0.95))
                        .frame(width: inW, height: 2.5)
                }
                if loopW > 0.5 {
                    Rectangle()
                        .fill(anim.hasLoopAnimation ? Color(red: 0.20, green: 0.88, blue: 0.55) : Color.clear)
                        .frame(width: loopW, height: 2.5)
                }
                if outW > 0.5 {
                    Rectangle()
                        .fill(Color(red: 0.98, green: 0.68, blue: 0.20))
                        .frame(width: outW, height: 2.5)
                }
            }
            .frame(width: width, height: 2.5, alignment: .leading)
        }
    }

    private var resolvedClipAnimation: TextAnimationConfiguration? {
        if clip.kind == .text,
           let json = clip.properties["textConfig"]?.asString,
           let cfg = TextConfiguration.decode(from: json) {
            return cfg.animation
        }
        if clip.kind == .sticker,
           let json = clip.properties["stickerConfig"]?.asString,
           let cfg = StickerConfiguration.decode(from: json) {
            return cfg.animation
        }
        return nil
    }
}

