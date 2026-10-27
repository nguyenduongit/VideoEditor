import SwiftUI
import AppKit
import Domain
import DesignSystem

public struct MediaDragThumbnailCardView: View {
    private let name: String
    private let type: MediaType
    private let thumbnail: NSImage?

    public init(name: String, type: MediaType, thumbnail: NSImage? = nil) {
        self.name = name
        self.type = type
        self.thumbnail = thumbnail
    }

    public var body: some View {
        ZStack {
            DSColors.blockBackground
            content
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.accent, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var content: some View {
        if type == .audio {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DSColors.accent)
                Text(String(localized: "AUDIO"))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
            }
        } else if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipped()
        } else {
            Image(systemName: type == .video ? "video.fill" : "photo.fill")
                .font(.system(size: 24))
                .foregroundStyle(DSColors.textSecondary)
        }
    }
}
