import SwiftUI
import CoreMedia
import Domain
import DesignSystem

public struct TimelineRulerRowView: View {
    public let canvasWidth: CGFloat
    public let viewportWidth: CGFloat
    public let pixelsPerSecond: CGFloat
    public let scrollOffset: CGFloat
    public let isVScrollable: Bool
    public let playheadState: TimelinePlayheadState
    public let snapCandidatesProvider: () -> [CMTime]

    public init(
        canvasWidth: CGFloat,
        viewportWidth: CGFloat,
        pixelsPerSecond: CGFloat,
        scrollOffset: CGFloat,
        isVScrollable: Bool,
        playheadState: TimelinePlayheadState,
        snapCandidatesProvider: @escaping () -> [CMTime]
    ) {
        self.canvasWidth = canvasWidth
        self.viewportWidth = viewportWidth
        self.pixelsPerSecond = pixelsPerSecond
        self.scrollOffset = scrollOffset
        self.isVScrollable = isVScrollable
        self.playheadState = playheadState
        self.snapCandidatesProvider = snapCandidatesProvider
    }

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            leftBar
            ruler
            if isVScrollable {
                Color.clear
                    .frame(width: DSSize.timelineBottomBuffer, height: DSSize.rulerHeight)
                    .background(DSColors.layerHeaderBackground)
            }
        }
        .frame(height: DSSize.rulerHeight)
    }

    private var leftBar: some View {
        Text(String(localized: "\(playheadState.fps) fps"))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DSColors.textSecondary)
            .frame(width: DSSize.layerHeaderWidth, height: DSSize.rulerHeight)
            .background(DSColors.layerHeaderBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(DSColors.blockBorder), alignment: .bottom)
            .overlay(Rectangle().frame(width: 1).foregroundStyle(DSColors.blockBorder), alignment: .trailing)
    }

    private var ruler: some View {
        TimelineRulerView(
            canvasWidth: canvasWidth,
            pixelsPerSecond: pixelsPerSecond,
            playheadState: playheadState,
            scrollOffset: scrollOffset,
            viewportWidth: viewportWidth,
            snapCandidatesProvider: snapCandidatesProvider
        )
        .offset(x: -scrollOffset)
        .frame(width: viewportWidth, height: DSSize.rulerHeight, alignment: .leading)
        .clipped()
    }
}
