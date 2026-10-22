import AppKit
import SwiftUI
import DesignSystem

public final class DarkSlimScroller: NSScroller {
    override public class var isCompatibleWithOverlayScrollers: Bool {
        true
    }

    override public class func scrollerWidth(for controlSize: ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        DSSize.slimScrollerHeight
    }

    override public func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.55).setFill()
        let path = NSBezierPath(roundedRect: slotRect, xRadius: slotRect.height / 2, yRadius: slotRect.height / 2)
        path.fill()
    }

    override public func drawKnob() {
        let knobRect = rect(for: .knob)
        guard knobRect.width > 0 && knobRect.height > 0 else { return }
        let pillRect = knobRect.insetBy(dx: 0, dy: 1)
        let radius = pillRect.height / 2
        let path = NSBezierPath(roundedRect: pillRect, xRadius: radius, yRadius: radius)
        NSColor(red: 0.38, green: 0.42, blue: 0.48, alpha: 0.85).setFill()
        path.fill()
    }
}

public struct TimelineScrollViewConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> TimelineScrollViewConfiguratorNSView {
        TimelineScrollViewConfiguratorNSView()
    }

    public func updateNSView(_ nsView: TimelineScrollViewConfiguratorNSView, context: Context) {
        nsView.configure()
    }
}

public final class TimelineScrollViewConfiguratorNSView: NSView {
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configure()
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configure()
    }

    public func configure() {
        guard let scrollView = enclosingScrollView else { return }
        if !(scrollView.horizontalScroller is DarkSlimScroller) {
            scrollView.horizontalScroller = DarkSlimScroller()
        }
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .dark
    }
}
