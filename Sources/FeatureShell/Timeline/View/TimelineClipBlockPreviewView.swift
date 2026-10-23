import SwiftUI
import AppKit
import CoreMedia
import Domain
import DesignSystem

public struct TimelineClipBlockPreviewView: View {
    private let name: String
    private let duration: CMTime
    private let kind: ClipKind
    private let width: CGFloat
    private let height: CGFloat
    private let thumbnail: NSImage?

    public init(
        name: String,
        duration: CMTime,
        kind: ClipKind,
        width: CGFloat,
        height: CGFloat,
        thumbnail: NSImage? = nil
    ) {
        self.name = name
        self.duration = duration
        self.kind = kind
        self.width = width
        self.height = height
        self.thumbnail = thumbnail
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(clipBackgroundColor)

            VStack(spacing: 0) {
                headerBar
                bodyContent
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))

            borderOverlay
        }
        .frame(width: width, height: height)
    }

    private var clipBackgroundColor: Color {
        switch kind {
        case .video: return DSColors.clipVideo.opacity(0.85)
        case .audio: return DSColors.clipAudio.opacity(0.85)
        case .image: return DSColors.clipImage.opacity(0.85)
        case .text: return DSColors.clipText.opacity(0.85)
        case .adjustment: return DSColors.clipAdjustment.opacity(0.85)
        }
    }

    private var headerBar: some View {
        HStack(spacing: DSSpacing.xs) {
            if kind == .adjustment {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Text(name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(TimeRational.formatTimecode(time: duration))
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, DSSpacing.xs)
        .frame(height: 16)
        .background(headerBackground)
        .overlay(
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var headerBackground: Color {
        switch kind {
        case .video: return DSColors.clipVideoHeader
        case .audio: return DSColors.clipAudioHeader
        case .adjustment: return DSColors.clipAdjustmentHeader
        default: return DSColors.clipHeaderBackground
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        let bodyH = max(10, height - 16)
        if kind == .video {
            let waveH: CGFloat = 30.0
            let filmH = max(10, bodyH - waveH)
            VStack(spacing: 0) {
                filmstripView(height: filmH)
                previewWaveform(height: waveH, background: DSColors.waveformVideoBackground)
            }
        } else if kind == .audio {
            previewWaveform(height: bodyH, background: DSColors.waveformAudioBackground)
        } else {
            Spacer(minLength: 0)
        }
    }

    private func filmstripView(height: CGFloat) -> some View {
        let thumbHeight = height
        let thumbWidth = max(24.0, thumbHeight * (16.0 / 9.0))
        let slotCount = max(1, Int(ceil(width / thumbWidth)))

        return HStack(spacing: 0) {
            ForEach(0..<slotCount, id: \.self) { _ in
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbWidth, height: thumbHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(DSColors.clipVideo)
                        .frame(width: thumbWidth, height: thumbHeight)
                }
            }
        }
        .frame(width: width, height: thumbHeight, alignment: .leading)
        .clipped()
    }

    private func previewWaveform(height: CGFloat, background: Color) -> some View {
        let barWidth: CGFloat = 2.0
        let barSpacing: CGFloat = 1.0
        let barCount = max(8, Int(width / (barWidth + barSpacing)))

        return HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                previewWaveformBar(index: index, maxHeight: height)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
        .background(background)
        .clipped()
        .overlay(
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5),
            alignment: .top
        )
    }

    private func previewWaveformBar(index: Int, maxHeight: CGFloat) -> some View {
        let cycle = sin(Double(index) * 0.18) * 0.5 + 0.5
        let h = max(4.0, maxHeight * CGFloat(0.25 + 0.70 * cycle))
        let isPeak = cycle > 0.82
        let peakH = isPeak ? max(2.0, h * 0.28) : 0
        let baseH = max(2.0, h - peakH)

        return VStack(spacing: 0) {
            if isPeak {
                Rectangle().fill(DSColors.waveformPeak).frame(height: peakH)
            }
            Rectangle().fill(DSColors.waveformBar).frame(height: baseH)
        }
        .frame(width: 2.0)
    }

    private var borderOverlay: some View {
        let borderColor: Color = {
            switch kind {
            case .video: return Color(red: 0.15, green: 0.65, blue: 0.65)
            case .audio: return Color(red: 0.20, green: 0.50, blue: 0.90)
            default: return Color.white.opacity(0.4)
            }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(borderColor, lineWidth: 1.5)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2.5)
                Spacer()
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2.5)
            }
        }
        .allowsHitTesting(false)
    }
}
