import Foundation
import Testing
@testable import Domain

struct TimelineZoomTests {
    @Test func testDefaultAndClamp() {
        #expect(TimelineZoom.defaultPPS == 60.0)
        #expect(TimelineZoom.minZoomRatio == 0.25)
        #expect(TimelineZoom.minPPS(basePPS: 60.0) == 15.0)
        #expect(TimelineZoom.maxPPS(basePPS: 60.0) == 960.0)

        #expect(TimelineZoom.clamp(pps: 5.0, basePPS: 60.0) == 15.0)
        #expect(TimelineZoom.clamp(pps: 2000.0, basePPS: 60.0) == 960.0)
        #expect(TimelineZoom.clamp(pps: 120.0, basePPS: 60.0) == 120.0)
    }

    @Test func testZoomInAndOut() {
        let base: CGFloat = 60.0
        let zoomedIn = TimelineZoom.zoomIn(from: base, basePPS: base)
        #expect(zoomedIn > base)

        let zoomedOut = TimelineZoom.zoomOut(from: base, basePPS: base)
        #expect(zoomedOut < base)

        let maxVal = TimelineZoom.maxPPS(basePPS: base)
        let clampedMax = TimelineZoom.zoomIn(from: maxVal, basePPS: base)
        #expect(clampedMax == maxVal)

        let minVal = TimelineZoom.minPPS(basePPS: base)
        let clampedMin = TimelineZoom.zoomOut(from: minVal, basePPS: base)
        #expect(clampedMin == minVal)
    }

    @Test func testZoomWithDelta() {
        let base: CGFloat = 60.0

        let zoomUp = TimelineZoom.zoomWithDelta(current: base, delta: 5.0, basePPS: base)
        #expect(zoomUp > base)

        let zoomDown = TimelineZoom.zoomWithDelta(current: base, delta: -5.0, basePPS: base)
        #expect(zoomDown < base)
    }

    @Test func testPercentages() {
        let base: CGFloat = 60.0
        #expect(TimelineZoom.percentage(for: base, basePPS: base) == 100)
        #expect(TimelineZoom.percentageString(for: base, basePPS: base) == "100%")

        let minVal = TimelineZoom.minPPS(basePPS: base)
        #expect(TimelineZoom.percentage(for: minVal, basePPS: base) == 25)
        #expect(TimelineZoom.percentageString(for: minVal, basePPS: base) == "25%")
    }

    @Test func testBasePPSCalculationAndLongDuration() {
        // 10s duration, 1100pt viewport -> 1000pt available / 10s = 100 px/s
        let basePPS10s = TimelineZoom.basePPS(for: 10.0, viewportWidth: 1100.0)
        #expect(basePPS10s == 100.0)
        #expect(TimelineZoom.percentage(for: basePPS10s, basePPS: basePPS10s) == 100)
        #expect(TimelineZoom.percentageString(for: basePPS10s, basePPS: basePPS10s) == "100%")

        // Trailing padding is 100pt
        #expect(TimelineZoom.trailingPadding == 100.0)

        // 0s duration -> defaults to defaultPPS
        #expect(TimelineZoom.basePPS(for: 0.0, viewportWidth: 1100.0) == 60.0)

        // Video longer than 2 minutes (e.g. 140s), 1100pt viewport -> 1000pt available / 140s ≈ 7.14 px/s
        let basePPS140s = TimelineZoom.basePPS(for: 140.0, viewportWidth: 1100.0)
        #expect(basePPS140s < 10.0)
        #expect(TimelineZoom.percentage(for: basePPS140s, basePPS: basePPS140s) == 100)
        #expect(TimelineZoom.percentageString(for: basePPS140s, basePPS: basePPS140s) == "100%")

        // 25% limit is 25% of the 100% base
        let minPPS140s = TimelineZoom.minPPS(basePPS: basePPS140s)
        #expect(TimelineZoom.percentage(for: minPPS140s, basePPS: basePPS140s) == 25)
        #expect(TimelineZoom.percentageString(for: minPPS140s, basePPS: basePPS140s) == "25%")
    }

    @Test func testAnchoredScrollOffset() {
        // Zoom in anchored at cursorX = 300
        let offsetZoomIn = TimelineZoom.anchoredScrollOffset(
            currentScrollOffset: 200.0,
            cursorXInViewport: 300.0,
            oldPPS: 50.0,
            newPPS: 100.0,
            newContentWidth: 3000.0,
            viewportWidth: 1000.0
        )
        #expect(offsetZoomIn == 700.0)

        // Time under cursor remains identical before and after zoom
        let timeBefore = (200.0 + 300.0) / 50.0 // 10.0s
        let timeAfter = (offsetZoomIn + 300.0) / 100.0 // 10.0s
        #expect(abs(timeBefore - timeAfter) < 0.0001)

        // Zoom out anchored at cursorX = 300
        let offsetZoomOut = TimelineZoom.anchoredScrollOffset(
            currentScrollOffset: 700.0,
            cursorXInViewport: 300.0,
            oldPPS: 100.0,
            newPPS: 50.0,
            newContentWidth: 1500.0,
            viewportWidth: 1000.0
        )
        #expect(offsetZoomOut == 200.0)

        // Clamping to 0 when zooming out near origin
        let clampedZero = TimelineZoom.anchoredScrollOffset(
            currentScrollOffset: 10.0,
            cursorXInViewport: 500.0,
            oldPPS: 100.0,
            newPPS: 20.0,
            newContentWidth: 1500.0,
            viewportWidth: 1000.0
        )
        #expect(clampedZero == 0.0)

        // Clamping to max scroll (newContentWidth - viewportWidth)
        let clampedMax = TimelineZoom.anchoredScrollOffset(
            currentScrollOffset: 400.0,
            cursorXInViewport: 100.0,
            oldPPS: 50.0,
            newPPS: 200.0,
            newContentWidth: 1500.0,
            viewportWidth: 1000.0
        )
        #expect(clampedMax == 500.0) // 1500 - 1000 = 500.0
    }
}
