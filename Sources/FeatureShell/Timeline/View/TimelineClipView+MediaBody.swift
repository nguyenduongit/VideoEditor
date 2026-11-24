import SwiftUI
import CoreMedia
import Domain
import DesignSystem

extension TimelineClipView {
    @ViewBuilder
    func clipMediaBody(width: CGFloat) -> some View {
        let bodyH = max(10, height - DSSize.clipHeaderHeight)
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
            let volume = clip.properties["volume"]?.asNumber ?? 1.0
            AudioWaveformView(
                url: clip.mediaURL,
                service: waveformService,
                sourceStartTime: activeSrc,
                sourceDuration: clip.maxDuration,
                pixelsPerSecond: pixelsPerSecond,
                fadeIn: inSec,
                fadeOut: outSec,
                clipDuration: clip.timeRange.duration,
                speed: speed,
                volume: volume
            )
            .opacity(isAudioMuted ? 0.35 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isAudioMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColors.waveformAudioBackground)
        } else {
            Spacer(minLength: 0)
        }
    }

    /// Thin indicator bar showing `[In (Cyan) | Loop (Mint Green) | Out (Amber)]` phase proportions
    /// at the bottom of a Text or Sticker clip on the Timeline.
    @ViewBuilder
    func clipAnimationDurationLine(width: CGFloat, duration: CMTime) -> some View {
        let totalSec = max(0.1, CMTimeGetSeconds(duration))
        if clip.kind == .text, let anim = resolvedTextAnimation, anim.hasScriptAnimation {
            let cycleSec = TextAnimationScriptRegistry.shared.script(for: anim.scriptId)?.loopCycleDuration ?? 1.0
            let phases = anim.resolvedPhases(forClipDuration: totalSec, baseCycleSeconds: cycleSec)
            phaseStrip(inSec: phases.inDuration, outSec: phases.outDuration, totalSec: totalSec, width: width)
        } else if clip.kind == .sticker, let stickerAnim = resolvedStickerAnimation, stickerAnim.hasScriptAnimation {
            let cycleSec = StickerAnimationScriptRegistry.shared.script(for: stickerAnim.scriptId)?.baseCycleSeconds ?? 1.0
            let phases = stickerAnim.resolvedPhases(forClipDuration: totalSec, baseCycleSeconds: cycleSec)
            phaseStrip(inSec: phases.inDuration, outSec: phases.outDuration, totalSec: totalSec, width: width)
        }
    }

    private func phaseStrip(inSec: Double, outSec: Double, totalSec: Double, width: CGFloat) -> some View {
        let inW = width * CGFloat(min(1.0, max(0.0, inSec / totalSec)))
        let outW = width * CGFloat(min(1.0, max(0.0, outSec / totalSec)))
        let loopW = max(0.0, width - inW - outW)
        return HStack(spacing: 0) {
            if inW > 0.5 {
                Rectangle()
                    .fill(Color(red: 0.18, green: 0.82, blue: 0.95))
                    .frame(width: inW, height: 2.5)
            }
            if loopW > 0.5 {
                Rectangle()
                    .fill(Color(red: 0.20, green: 0.88, blue: 0.55))
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

    private var resolvedTextAnimation: TextAnimationConfiguration? {
        guard clip.kind == .text,
              let json = clip.properties["textConfig"]?.asString,
              let cfg = TextConfiguration.decode(from: json) else {
            return nil
        }
        return cfg.animation
    }

    private var resolvedStickerAnimation: StickerAnimationConfiguration? {
        guard clip.kind == .sticker,
              let json = clip.properties["stickerConfig"]?.asString,
              let cfg = StickerConfiguration.decode(from: json) else {
            return nil
        }
        return cfg.animation
    }
}

