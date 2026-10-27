import SwiftUI
import Domain
import DesignSystem

public struct PreviewView: View {
    private let viewModel: ShellViewModel

    public init(viewModel: ShellViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSBlockContainer {
            VStack(spacing: DSSpacing.none) {
                viewportArea
                bottomBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var viewportArea: some View {
        ZStack {
            DSColors.windowBackground
            workingCanvas
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var workingCanvas: some View {
        ZStack {
            Color.black
            previewContent
                .clipped()
            if viewModel.activePreviewAsset == nil {
                PreviewObjectManipulatorView(
                    timelineViewModel: viewModel.timelineViewModel,
                    inspectorViewModel: viewModel.inspectorViewModel,
                    canvasSize: viewModel.aspectRatio.renderSize
                )
            }
            MaskOnScreenOverlayView(
                inspectorViewModel: viewModel.inspectorViewModel,
                canvasSize: viewModel.aspectRatio.renderSize
            )
            GridOnScreenOverlayView(
                inspectorViewModel: viewModel.inspectorViewModel,
                canvasSize: viewModel.aspectRatio.renderSize
            )
        }
        .aspectRatio(viewModel.aspectRatio.ratio, contentMode: .fit)
        .overlay(
            Rectangle()
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var previewContent: some View {
        if let asset = viewModel.activePreviewAsset {
            assetPreviewContent(for: asset)
        } else {
            timelineContent
        }
    }

    @ViewBuilder
    private func assetPreviewContent(for asset: MediaAsset) -> some View {
        switch asset.type {
        case .video:
            if let player = viewModel.avPlayer {
                VideoPlayerBridge(player: player)
            }
        case .audio:
            audioAssetPreview(for: asset)
        case .image:
            if let nsImage = viewModel.previewImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private func audioAssetPreview(for asset: MediaAsset) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "music.note")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DSColors.accent)
            Text(asset.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.windowBackground)
    }

    private var timelineContent: some View {
        ZStack {
            VideoPlayerBridge(player: viewModel.playbackEngine.player)
                .opacity((viewModel.isTimelineVideoActive || viewModel.isPlaying) ? 1.0 : 0.0)
            if let nsImage = viewModel.timelinePreviewImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private var bottomBar: some View {
        ZStack {
            HStack {
                Spacer()
                DSPlayPauseButton(
                    isPlaying: viewModel.isPlaying,
                    action: { viewModel.togglePlayPause() }
                )
                .keyboardShortcut(.space, modifiers: [])
                .opacity(viewModel.canPlayback ? 1.0 : 0.5)
                .disabled(!viewModel.canPlayback)
                Spacer()
            }

            HStack {
                Spacer()
                DSRatioSelector(
                    selectedTitle: viewModel.aspectRatio.title,
                    options: CanvasAspectRatio.allCases.map(\.title),
                    onSelect: { title in
                        if let selected = CanvasAspectRatio.allCases.first(where: { $0.title == title }) {
                            viewModel.setAspectRatio(selected)
                        }
                    }
                )
                .padding(.trailing, DSSpacing.md)
            }
        }
        .frame(height: DSSize.previewBottomBarHeight)
        .background(DSColors.blockBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .top
        )
    }
}
