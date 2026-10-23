import Testing
import SwiftUI
import DesignSystem
import Domain
@testable import FeatureShell

@Suite("TimelineVerticalScrollTests")
@MainActor
struct TimelineVerticalScrollTests {
    @Test("TimelineVerticalScrollBarView initialization and token consistency")
    func testTimelineVerticalScrollBarViewInit() {
        let binding = Binding.constant(CGFloat(20.0))
        let view = TimelineVerticalScrollBarView(
            scrollOffset: binding,
            contentHeight: 600,
            viewportHeight: 300,
            onScrollTo: { _ in }
        )
        _ = view
        #expect(DSSize.timelineBottomBuffer == 16)
        #expect(DSSize.slimScrollerHeight == 7)
    }

    @Test("TimelineVerticalScrollBarMath non-scrollable when content fits viewport")
    func testTimelineVerticalScrollBarMathNotScrollable() {
        let math = TimelineVerticalScrollBarMath(
            containerHeight: 400,
            contentHeight: 300,
            viewportHeight: 400,
            scrollOffset: 0
        )
        #expect(!math.isScrollable)
        #expect(math.thumbY == 0)
    }

    @Test("TimelineVerticalScrollBarMath calculations when content exceeds viewport")
    func testTimelineVerticalScrollBarMathScrollable() {
        let math = TimelineVerticalScrollBarMath(
            containerHeight: 500,
            contentHeight: 1200,
            viewportHeight: 400,
            scrollOffset: 200
        )
        #expect(math.isScrollable)
        #expect(math.maxScroll == 800)
        #expect(math.trackHeight == 492)
        #expect(math.thumbHeight >= 36)
        #expect(math.thumbY > 0 && math.thumbY < math.maxThumbTravel)

        let clickOffset = math.scrollOffset(forClickY: 4)
        #expect(clickOffset == 0)

        let dragScroll = math.scrollOffset(forDragTranslation: 60, startOffset: 200)
        #expect(dragScroll > 200)

        let clampedMin = math.scrollOffset(forDragTranslation: -1000, startOffset: 200)
        #expect(clampedMin == 0)

        let clampedMax = math.scrollOffset(forDragTranslation: 2000, startOffset: 200)
        #expect(clampedMax == math.maxScroll)
    }

    @Test("TimelineViewModel totalLayersHeight calculation")
    func testTimelineViewModelTotalLayersHeight() {
        let vm = TimelineViewModel()
        #expect(vm.totalLayersHeight == 0)

        let videoLayer = TimelineLayer(name: "V1", kind: .video)
        let audioLayer = TimelineLayer(name: "A1", kind: .audio)
        let textLayer = TimelineLayer(name: "T1", kind: .text)

        vm.layers = [videoLayer, audioLayer, textLayer]
        let expectedHeight = DSSize.videoLayerHeight + DSSize.mediaLayerHeight + DSSize.compactLayerHeight
        #expect(vm.totalLayersHeight == expectedHeight)
    }

    @Test("TimelineTopBuffer token and minimum top spacer math")
    func testTimelineTopBufferAndSpacerCalculation() {
        #expect(DSSize.timelineTopBuffer == 80)

        // Case 1: Few layers where availableHeight - totalLayersHeight > 80
        let availableHeight: CGFloat = 400
        let totalLayersHeightFew: CGFloat = 100
        let spacerFew = max(DSSize.timelineTopBuffer, availableHeight - totalLayersHeightFew)
        #expect(spacerFew == 300)
        #expect(spacerFew + totalLayersHeightFew == availableHeight)

        // Case 2: Many layers where availableHeight - totalLayersHeight < 80
        let totalLayersHeightMany: CGFloat = 380
        let spacerMany = max(DSSize.timelineTopBuffer, availableHeight - totalLayersHeightMany)
        #expect(spacerMany == 80)
        #expect(spacerMany + totalLayersHeightMany == 460)
        #expect(spacerMany + totalLayersHeightMany > availableHeight)
    }

    @Test("TimelineVerticalScrollBarView supports custom backgroundColor")
    func testTimelineVerticalScrollBarViewCustomBackground() {
        let binding = Binding.constant(CGFloat(0))
        let view = TimelineVerticalScrollBarView(
            scrollOffset: binding,
            contentHeight: 800,
            viewportHeight: 400,
            backgroundColor: DSColors.blockBackground,
            onScrollTo: { _ in }
        )
        _ = view
        #expect(DSSize.sidebarWidth == 400)
    }

    @Test("DSVerticalScrollView initializes and preserves gutter buffer")
    func testDSVerticalScrollViewGutterBuffer() {
        let scrollView = DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
            Text("Test Content")
        }
        _ = scrollView
        #expect(DSSize.timelineBottomBuffer == 16)
        #expect(DSSize.sidebarWidth == 400)
    }

    @Test("TimelineVerticalScrollBarView thumb renders symmetrically with balanced margins")
    func testTimelineVerticalScrollBarViewRenderedSymmetry() {
        let binding = Binding.constant(CGFloat(50))
        let view = TimelineVerticalScrollBarView(
            scrollOffset: binding,
            contentHeight: 1200,
            viewportHeight: 400,
            backgroundColor: DSColors.blockBackground,
            onScrollTo: { _ in }
        )
        .frame(width: DSSize.timelineBottomBuffer, height: 200)

        let renderer = ImageRenderer(content: view)
        guard let cgImage = renderer.cgImage else {
            Issue.record("Failed to render TimelineVerticalScrollBarView")
            return
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        #expect(rep.pixelsWide == Int(DSSize.timelineBottomBuffer))

        var leftMargin = 0
        var rightMargin = 0
        var thumbWidth = 0
        for x in 0..<rep.pixelsWide {
            let r = Int((rep.colorAt(x: x, y: 20)?.redComponent ?? 0) * 255)
            if r > 80 {
                thumbWidth += 1
            } else if thumbWidth == 0 {
                leftMargin += 1
            } else {
                rightMargin += 1
            }
        }
        #expect(thumbWidth == Int(DSSize.slimScrollerHeight))
        #expect(abs(leftMargin - rightMargin) <= 1)
    }

    @Test("Sidebar width tokens align exactly with scrollbar gutter")
    func testSidebarWidthTokensAlignment() {
        let controlsWidth = DSSize.inspectorColumnWidth * 4 + DSSize.inspectorColumnSpacing * 3
        let paddingWidth = DSSize.inspectorContentPadding + DSSpacing.md
        let totalContentWidth = controlsWidth + paddingWidth
        #expect(totalContentWidth == 384)
        #expect(totalContentWidth + DSSize.timelineBottomBuffer == DSSize.sidebarWidth)
    }
}
