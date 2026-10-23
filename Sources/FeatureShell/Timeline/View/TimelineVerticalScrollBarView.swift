import SwiftUI
import DesignSystem

public struct TimelineVerticalScrollBarMath: Sendable {
    public let isScrollable: Bool
    public let trackHeight: CGFloat
    public let thumbHeight: CGFloat
    public let maxScroll: CGFloat
    public let maxThumbTravel: CGFloat
    public let thumbY: CGFloat

    public init(
        containerHeight: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        scrollOffset: CGFloat,
        trackPadding: CGFloat = 4.0,
        minThumbHeight: CGFloat = 36.0
    ) {
        let availableHeight = max(1.0, containerHeight)
        self.trackHeight = max(1.0, availableHeight - trackPadding * 2)
        self.isScrollable = contentHeight > viewportHeight && viewportHeight > 0
        let ratio = isScrollable ? min(1.0, viewportHeight / contentHeight) : 1.0
        self.thumbHeight = isScrollable ? max(minThumbHeight, min(trackHeight, trackHeight * ratio)) : trackHeight
        self.maxScroll = max(1.0, contentHeight - viewportHeight)
        self.maxThumbTravel = max(1.0, trackHeight - thumbHeight)
        let clampedOffset = max(0.0, min(maxScroll, scrollOffset))
        self.thumbY = isScrollable ? (clampedOffset / maxScroll) * maxThumbTravel : 0
    }

    public func scrollOffset(forClickY clickY: CGFloat, trackPadding: CGFloat = 4.0) -> CGFloat {
        let adjustedClick = clickY - trackPadding
        let targetThumbY = max(0, min(maxThumbTravel, adjustedClick - thumbHeight / 2))
        return (targetThumbY / maxThumbTravel) * maxScroll
    }

    public func scrollOffset(forDragTranslation translation: CGFloat, startOffset: CGFloat) -> CGFloat {
        let scrollDelta = (translation / maxThumbTravel) * maxScroll
        return max(0.0, min(maxScroll, startOffset + scrollDelta))
    }
}

public struct TimelineVerticalScrollBarView: View {
    @Binding private var scrollOffset: CGFloat
    private let contentHeight: CGFloat
    private let viewportHeight: CGFloat
    private let backgroundColor: Color
    private let onScrollTo: (CGFloat) -> Void

    @State private var isDragging: Bool = false
    @State private var dragStartOffset: CGFloat?
    @State private var isHovered: Bool = false

    public init(
        scrollOffset: Binding<CGFloat>,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        backgroundColor: Color = DSColors.layerTrackBackground,
        onScrollTo: @escaping (CGFloat) -> Void
    ) {
        self._scrollOffset = scrollOffset
        self.contentHeight = contentHeight
        self.viewportHeight = viewportHeight
        self.backgroundColor = backgroundColor
        self.onScrollTo = onScrollTo
    }

    public var body: some View {
        GeometryReader { geo in
            let math = TimelineVerticalScrollBarMath(
                containerHeight: geo.size.height,
                contentHeight: contentHeight,
                viewportHeight: viewportHeight,
                scrollOffset: scrollOffset
            )

            ZStack(alignment: .top) {
                backgroundColor
                    .frame(width: DSSize.timelineBottomBuffer)

                if math.isScrollable {
                    RoundedRectangle(cornerRadius: DSSize.slimScrollerHeight / 2)
                        .fill(DSColors.scrollerTrack)
                        .frame(width: DSSize.slimScrollerHeight, height: math.trackHeight)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                onScrollTo(math.scrollOffset(forClickY: value.location.y))
                            }
                        )

                    VStack(spacing: DSSpacing.none) {
                        Color.clear
                            .frame(width: DSSize.timelineBottomBuffer, height: 4 + math.thumbY)
                            .allowsHitTesting(false)

                        ZStack {
                            RoundedRectangle(cornerRadius: DSSize.slimScrollerHeight / 2)
                                .fill(isHovered || isDragging ? DSColors.scrollerThumbHover : DSColors.scrollerThumb)
                                .frame(width: DSSize.slimScrollerHeight, height: math.thumbHeight)
                        }
                        .frame(width: DSSize.timelineBottomBuffer, height: math.thumbHeight)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let start = dragStartOffset ?? scrollOffset
                                    if dragStartOffset == nil {
                                        dragStartOffset = start
                                        isDragging = true
                                    }
                                    let targetScroll = math.scrollOffset(forDragTranslation: value.translation.height, startOffset: start)
                                    onScrollTo(targetScroll)
                                }
                                .onEnded { _ in
                                    dragStartOffset = nil
                                    isDragging = false
                                }
                        )
                        .onHover { isHovered = $0 }

                        Spacer(minLength: 0)
                            .allowsHitTesting(false)
                    }
                    .frame(width: DSSize.timelineBottomBuffer, height: max(1.0, geo.size.height))
                }
            }
            .frame(width: DSSize.timelineBottomBuffer)
        }
        .frame(width: DSSize.timelineBottomBuffer)
    }
}
