import SwiftUI
import DesignSystem

public struct TimelineScrollBarMath: Sendable {
    public let isScrollable: Bool
    public let trackWidth: CGFloat
    public let thumbWidth: CGFloat
    public let maxScroll: CGFloat
    public let maxThumbTravel: CGFloat
    public let thumbX: CGFloat

    public init(
        containerWidth: CGFloat,
        contentWidth: CGFloat,
        viewportWidth: CGFloat,
        scrollOffset: CGFloat,
        trackPadding: CGFloat = 4.0,
        minThumbWidth: CGFloat = 36.0
    ) {
        let availableWidth = max(1.0, containerWidth)
        self.trackWidth = max(1.0, availableWidth - trackPadding * 2)
        self.isScrollable = contentWidth > viewportWidth && viewportWidth > 0
        let ratio = isScrollable ? min(1.0, viewportWidth / contentWidth) : 1.0
        self.thumbWidth = isScrollable ? max(minThumbWidth, min(trackWidth, trackWidth * ratio)) : trackWidth
        self.maxScroll = max(1.0, contentWidth - viewportWidth)
        self.maxThumbTravel = max(1.0, trackWidth - thumbWidth)
        let clampedOffset = max(0.0, min(maxScroll, scrollOffset))
        self.thumbX = isScrollable ? (clampedOffset / maxScroll) * maxThumbTravel : 0
    }

    public func scrollOffset(forClickX clickX: CGFloat, trackPadding: CGFloat = 4.0) -> CGFloat {
        let adjustedClick = clickX - trackPadding
        let targetThumbX = max(0, min(maxThumbTravel, adjustedClick - thumbWidth / 2))
        return (targetThumbX / maxThumbTravel) * maxScroll
    }

    public func scrollOffset(forDragTranslation translation: CGFloat, startOffset: CGFloat) -> CGFloat {
        let scrollDelta = (translation / maxThumbTravel) * maxScroll
        return max(0.0, min(maxScroll, startOffset + scrollDelta))
    }
}

public struct TimelineScrollBarView: View {
    @Binding private var scrollOffset: CGFloat
    private let contentWidth: CGFloat
    private let viewportWidth: CGFloat
    private let onScrollTo: (CGFloat) -> Void

    @State private var isDragging: Bool = false
    @State private var dragStartOffset: CGFloat?
    @State private var isHovered: Bool = false

    public init(
        scrollOffset: Binding<CGFloat>,
        contentWidth: CGFloat,
        viewportWidth: CGFloat,
        onScrollTo: @escaping (CGFloat) -> Void
    ) {
        self._scrollOffset = scrollOffset
        self.contentWidth = contentWidth
        self.viewportWidth = viewportWidth
        self.onScrollTo = onScrollTo
    }

    public var body: some View {
        GeometryReader { geo in
            let math = TimelineScrollBarMath(
                containerWidth: geo.size.width,
                contentWidth: contentWidth,
                viewportWidth: viewportWidth,
                scrollOffset: scrollOffset
            )

            ZStack(alignment: .leading) {
                DSColors.layerTrackBackground
                    .frame(height: DSSize.timelineBottomBuffer)

                if math.isScrollable {
                    RoundedRectangle(cornerRadius: DSSize.slimScrollerHeight / 2)
                        .fill(DSColors.scrollerTrack)
                        .frame(width: math.trackWidth, height: DSSize.slimScrollerHeight)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                onScrollTo(math.scrollOffset(forClickX: value.location.x))
                            }
                        )

                    HStack(spacing: DSSpacing.none) {
                        Color.clear
                            .frame(width: 4 + math.thumbX, height: DSSize.timelineBottomBuffer)
                            .allowsHitTesting(false)

                        ZStack {
                            RoundedRectangle(cornerRadius: DSSize.slimScrollerHeight / 2)
                                .fill(isHovered || isDragging ? DSColors.scrollerThumbHover : DSColors.scrollerThumb)
                                .frame(width: math.thumbWidth, height: DSSize.slimScrollerHeight)
                        }
                        .frame(width: math.thumbWidth, height: DSSize.timelineBottomBuffer)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let start = dragStartOffset ?? scrollOffset
                                    if dragStartOffset == nil {
                                        dragStartOffset = start
                                        isDragging = true
                                    }
                                    let targetScroll = math.scrollOffset(forDragTranslation: value.translation.width, startOffset: start)
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
                    .frame(width: max(1.0, geo.size.width), height: DSSize.timelineBottomBuffer)
                }
            }
            .frame(height: DSSize.timelineBottomBuffer)
        }
        .frame(height: DSSize.timelineBottomBuffer)
    }
}
