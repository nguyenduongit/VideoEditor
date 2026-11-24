import SwiftUI
import Domain
import DesignSystem

/// Animated CoreGraphics thumbnail preview for Audiogram Stickers in the left library sidebar.
public struct AudiogramStickerThumbnailView: View {
    public let config: StickerAudiogramConfiguration
    @State private var isHovered: Bool = false
    @State private var hoverStart: TimeInterval = Date.timeIntervalSinceReferenceDate

    public init(config: StickerAudiogramConfiguration) {
        self.config = config
    }

    public var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isHovered)) { context in
            let elapsed = isHovered
                ? max(0.0, (context.date.timeIntervalSinceReferenceDate - hoverStart).truncatingRemainder(dividingBy: 3.0))
                : 0.65
            let frame = AudioReactiveSampler.sample(
                atTimelineTime: elapsed,
                tracks: [],
                bandCount: config.barCount,
                sensitivity: config.sensitivity,
                reactsToBeat: config.reactsToBeat,
                fallbackBPM: 120.0
            )
            if let cg = AudiogramVectorRenderer.render(
                config: config,
                frame: frame,
                targetSize: CGSize(width: 96, height: 64),
                time: elapsed
            ) {
                Image(decorative: cg, scale: 2.0)
                    .resizable()
                    .scaledToFit()
                    .padding(DSSpacing.xs)
            } else {
                Image(systemName: config.style.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: config.primaryColorHex))
            }
        }
        .onHover { hovering in
            if hovering && !isHovered {
                hoverStart = Date.timeIntervalSinceReferenceDate
            }
            isHovered = hovering
        }
    }
}
