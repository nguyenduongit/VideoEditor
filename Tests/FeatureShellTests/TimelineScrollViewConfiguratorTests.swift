import Testing
import AppKit
import SwiftUI
import DesignSystem
@testable import FeatureShell

@Suite("TimelineScrollViewConfiguratorTests")
@MainActor
struct TimelineScrollViewConfiguratorTests {
    @Test("DarkSlimScroller is compatible with overlay scrollers")
    func testDarkSlimScrollerCompatibility() {
        #expect(DarkSlimScroller.isCompatibleWithOverlayScrollers == true)
    }

    @Test("DarkSlimScroller width matches DSSize token")
    func testDarkSlimScrollerWidth() {
        let width = DarkSlimScroller.scrollerWidth(for: .regular, scrollerStyle: .overlay)
        #expect(width == DSSize.slimScrollerHeight)
    }

    @Test("TimelineScrollViewConfigurator sets dark slim scroller and overlay style on NSScrollView")
    @MainActor
    func testConfiguratorSetsOverlayAndDarkScroller() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        let configuratorView = TimelineScrollViewConfiguratorNSView()
        scrollView.documentView = configuratorView

        configuratorView.configure()

        #expect(scrollView.scrollerStyle == .overlay)
        #expect(scrollView.scrollerKnobStyle == .dark)
        #expect(scrollView.horizontalScroller is DarkSlimScroller)
    }

    @Test("TimelineBottomBuffer token is positive")
    func testTimelineBottomBufferToken() {
        #expect(DSSize.timelineBottomBuffer > 0)
        #expect(DSSize.slimScrollerHeight < DSSize.timelineBottomBuffer)
    }
}
