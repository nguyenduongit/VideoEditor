import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Hiển thị các vạch nhịp và số đếm (1 2 3 4 5 6 7 8, 2 2 3...) trực quan bên trong clip Dance Beat Counter trên Timeline.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R2.4 (DesignSystem).
public struct DanceBeatCounterStripView: View {
    let clip: TimelineClip
    let width: CGFloat
    let height: CGFloat
    let pixelsPerSecond: CGFloat
    let beatTimes: [CMTime]

    public init(
        clip: TimelineClip,
        width: CGFloat,
        height: CGFloat,
        pixelsPerSecond: CGFloat,
        beatTimes: [CMTime]
    ) {
        self.clip = clip
        self.width = width
        self.height = height
        self.pixelsPerSecond = pixelsPerSecond
        self.beatTimes = beatTimes
    }

    private var scheduledItems: [DanceBeatVoiceItem] {
        DanceBeatCounterSchedule.schedule(beatTimes: beatTimes, within: clip.timeRange)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            backgroundPattern

            if scheduledItems.isEmpty {
                placeholderLabel
            } else {
                beatsOverlay
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var backgroundPattern: some View {
        Rectangle()
            .fill(DSColors.waveformAudioBackground.opacity(0.85))
    }

    private var placeholderLabel: some View {
        HStack {
            Image(systemName: "figure.dance")
                .font(.system(size: 10))
            Text("Dance Beat Counter (Nhịp 8)")
                .font(.system(size: 9.5, weight: .medium))
        }
        .foregroundStyle(DSColors.textSecondary.opacity(0.7))
        .padding(.horizontal, DSSpacing.sm)
    }

    private var beatsOverlay: some View {
        ForEach(scheduledItems, id: \.time) { item in
            let relSec = max(0.0, CMTimeGetSeconds(item.time - clip.timeRange.start))
            let xPos = CGFloat(relSec) * pixelsPerSecond

            if xPos >= 0 && xPos <= width {
                beatMarkerView(for: item)
                    .position(x: xPos, y: height / 2)
            }
        }
    }

    @ViewBuilder
    private func beatMarkerView(for item: DanceBeatVoiceItem) -> some View {
        let isDownbeat = item.beatInRound == 1
        VStack(spacing: 2) {
            Rectangle()
                .fill(isDownbeat ? DSColors.accent : Color.white.opacity(0.4))
                .frame(width: isDownbeat ? 1.5 : 1, height: isDownbeat ? 10 : 6)

            Text("\(item.voiceNumber)")
                .font(.system(size: isDownbeat ? 9.5 : 8, weight: isDownbeat ? .bold : .medium, design: .rounded))
                .foregroundStyle(isDownbeat ? DSColors.accent : Color.white.opacity(0.8))

            Spacer(minLength: 0)
        }
        .frame(width: 24, height: height)
    }
}
