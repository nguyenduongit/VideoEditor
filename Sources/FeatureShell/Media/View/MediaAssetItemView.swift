import AppKit
import SwiftUI
import Domain
import DesignSystem

public struct MediaAssetItemView: View {
    private let asset: MediaAsset
    private let isSelected: Bool
    private let thumbnail: Image?
    private let onSelect: (Bool) -> Void
    private let onAddToTimeline: (() -> Void)?
    @State private var isHovered = false

    public init(
        asset: MediaAsset,
        isSelected: Bool,
        thumbnail: Image?,
        onSelect: @escaping (Bool) -> Void,
        onAddToTimeline: (() -> Void)? = nil
    ) {
        self.asset = asset
        self.isSelected = isSelected
        self.thumbnail = thumbnail
        self.onSelect = onSelect
        self.onAddToTimeline = onAddToTimeline
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            squareThumbnailBox
            fileNameLabel
        }
        .contentShape(Rectangle())
        .overlay(
            MediaAssetDragBridgeView(
                asset: asset,
                onSelect: onSelect,
                onAddToTimeline: onAddToTimeline,
                onHover: { isHovered = $0 }
            )
        )
    }

    private var squareThumbnailBox: some View {
        ZStack {
            DSColors.windowBackground
            thumbnailContent
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(
                    isSelected ? DSColors.accent : DSColors.blockBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                plusButton
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var plusButton: some View {
        Button(action: {
            onAddToTimeline?()
        }) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.16, green: 0.79, blue: 0.38))
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.xs)
        .help("Add to Timeline")
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if asset.type == .audio {
            audioWaveformIcon
        } else if let thumbnail {
            thumbnail
                .resizable()
                .scaledToFit()
                .padding(DSSpacing.xs)
        } else {
            fallbackMediaIcon
        }
    }

    private var audioWaveformIcon: some View {
        VStack(spacing: DSSpacing.xs) {
            Image(systemName: "waveform")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DSColors.accent)
            Text("AUDIO")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)
        }
    }

    private var fallbackMediaIcon: some View {
        Image(systemName: asset.type == .video ? "video.fill" : "photo.fill")
            .font(.system(size: 24))
            .foregroundStyle(DSColors.textSecondary)
    }

    private var fileNameLabel: some View {
        Text(asset.name)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
