import SwiftUI
import AppKit
import Domain
import DesignSystem

public struct MediaDragThumbnailCardView: View {
    private let name: String
    private let kind: ClipKind
    private let thumbnail: NSImage?

    public init(name: String, type: MediaType, thumbnail: NSImage? = nil) {
        self.name = name
        self.kind = type.clipKind
        self.thumbnail = thumbnail
    }

    public init(name: String, kind: ClipKind, thumbnail: NSImage? = nil) {
        self.name = name
        self.kind = kind
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
                .stroke(kind.presentation.borderColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var content: some View {
        if let thumbnail, (kind == .video || kind == .image) {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipped()
        } else {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: kind.presentation.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(kind.color)
                Text(kind.title.uppercased())
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
    }
}
