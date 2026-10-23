import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct ClipHeaderBarView: View {
    private let name: String
    private let duration: CMTime
    private let kind: ClipKind

    public init(name: String, duration: CMTime, kind: ClipKind) {
        self.name = name
        self.duration = duration
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if kind == .audio {
                fadeHandle
            }

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

            if kind == .video || kind == .adjustment {
                Text(TimeRational.formatTimecode(time: duration))
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if kind == .audio {
                fadeHandle
            }
        }
        .padding(.horizontal, DSSpacing.xs)
        .frame(height: 16)
        .background(headerBackground)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var headerBackground: Color {
        switch kind {
        case .video:
            return DSColors.clipVideoHeader
        case .audio:
            return DSColors.clipAudioHeader
        case .adjustment:
            return DSColors.clipAdjustmentHeader
        default:
            return DSColors.clipHeaderBackground
        }
    }

    private var fadeHandle: some View {
        Circle()
            .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
            .background(Circle().fill(Color.black.opacity(0.4)))
            .frame(width: 7, height: 7)
    }
}
