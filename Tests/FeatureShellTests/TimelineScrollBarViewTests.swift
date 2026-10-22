import Testing
import SwiftUI
import DesignSystem
@testable import FeatureShell

@Suite("TimelineScrollBarViewTests")
@MainActor
struct TimelineScrollBarViewTests {
    @Test("TimelineScrollBarView initialization and token consistency")
    func testTimelineScrollBarViewInit() {
        let binding = Binding.constant(CGFloat(50.0))
        let view = TimelineScrollBarView(
            scrollOffset: binding,
            contentWidth: 1000,
            viewportWidth: 400,
            onScrollTo: { _ in }
        )
        _ = view
        #expect(DSSize.timelineBottomBuffer == 16)
        #expect(DSSize.slimScrollerHeight == 7)
    }

    @Test("TimelineScrollBarMath non-scrollable when content fits viewport")
    func testTimelineScrollBarMathNotScrollable() {
        let math = TimelineScrollBarMath(
            containerWidth: 500,
            contentWidth: 400,
            viewportWidth: 500,
            scrollOffset: 0
        )
        #expect(!math.isScrollable)
        #expect(math.thumbX == 0)
    }

    @Test("TimelineScrollBarMath scrollable math and travel calculations")
    func testTimelineScrollBarMathScrollable() {
        let math = TimelineScrollBarMath(
            containerWidth: 800,
            contentWidth: 2000,
            viewportWidth: 500,
            scrollOffset: 300
        )
        #expect(math.isScrollable)
        #expect(math.maxScroll == 1500)
        #expect(math.trackWidth == 792)
        #expect(math.thumbWidth > 36)
        #expect(math.thumbX > 0 && math.thumbX < math.maxThumbTravel)

        let clickOffset = math.scrollOffset(forClickX: 4)
        #expect(clickOffset == 0)

        let dragScroll = math.scrollOffset(forDragTranslation: 50, startOffset: 300)
        #expect(dragScroll > 300)

        let clampedMin = math.scrollOffset(forDragTranslation: -1000, startOffset: 300)
        #expect(clampedMin == 0)

        let clampedMax = math.scrollOffset(forDragTranslation: 2000, startOffset: 300)
        #expect(clampedMax == math.maxScroll)
    }
}
