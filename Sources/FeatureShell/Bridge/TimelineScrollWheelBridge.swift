import AppKit
import SwiftUI

public struct TimelineScrollWheelBridge: NSViewRepresentable {
    private let onCmdScrollWheel: (CGFloat, CGFloat) -> Void
    private let onResetZoom: () -> Void
    private let onZoomIn: () -> Void
    private let onZoomOut: () -> Void
    private let onTogglePlayPause: () -> Void
    private let onUndo: () -> Void
    private let onRedo: () -> Void

    public init(
        onCmdScrollWheel: @escaping (CGFloat, CGFloat) -> Void,
        onResetZoom: @escaping () -> Void = {},
        onZoomIn: @escaping () -> Void = {},
        onZoomOut: @escaping () -> Void = {},
        onTogglePlayPause: @escaping () -> Void = {},
        onUndo: @escaping () -> Void = {},
        onRedo: @escaping () -> Void = {}
    ) {
        self.onCmdScrollWheel = onCmdScrollWheel
        self.onResetZoom = onResetZoom
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.onTogglePlayPause = onTogglePlayPause
        self.onUndo = onUndo
        self.onRedo = onRedo
    }

    public func makeNSView(context: Context) -> TimelineScrollWheelNSView {
        let view = TimelineScrollWheelNSView()
        view.onCmdScrollWheel = onCmdScrollWheel
        view.onResetZoom = onResetZoom
        view.onZoomIn = onZoomIn
        view.onZoomOut = onZoomOut
        view.onTogglePlayPause = onTogglePlayPause
        view.onUndo = onUndo
        view.onRedo = onRedo
        return view
    }

    public func updateNSView(_ nsView: TimelineScrollWheelNSView, context: Context) {
        nsView.onCmdScrollWheel = onCmdScrollWheel
        nsView.onResetZoom = onResetZoom
        nsView.onZoomIn = onZoomIn
        nsView.onZoomOut = onZoomOut
        nsView.onTogglePlayPause = onTogglePlayPause
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
    }

    public static func dismantleNSView(_ nsView: TimelineScrollWheelNSView, coordinator: ()) {
        nsView.cleanup()
    }
}

public final class TimelineScrollWheelNSView: NSView {
    public var onCmdScrollWheel: ((CGFloat, CGFloat) -> Void)?
    public var onResetZoom: (() -> Void)?
    public var onZoomIn: (() -> Void)?
    public var onZoomOut: (() -> Void)?
    public var onTogglePlayPause: (() -> Void)?
    public var onUndo: (() -> Void)?
    public var onRedo: (() -> Void)?
    private var eventMonitor: Any?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMonitor()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMonitor()
    }

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    private func setupMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] event in
            guard let self, let window = self.window, event.window == window else {
                return event
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.type == .keyDown {
                return self.handleKeyDown(event: event, flags: flags)
            }
            if event.type == .scrollWheel {
                return self.handleScrollWheel(event: event, flags: flags)
            }
            return event
        }
    }

    private func handleKeyDown(event: NSEvent, flags: NSEvent.ModifierFlags) -> NSEvent? {
        if event.keyCode == 49 {
            if let window = self.window, let responder = window.firstResponder, responder is NSTextView {
                return event
            }
            onTogglePlayPause?()
            return nil
        }

        let chars = event.charactersIgnoringModifiers?.lowercased()
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)
        let isZ = chars == "z" || event.keyCode == 6

        if isCmd && !isShift && isZ {
            if let window = self.window, let responder = window.firstResponder, (responder is NSTextView || responder is NSTextField) {
                return event
            }
            onUndo?()
            return nil
        }
        if isCmd && isShift && isZ {
            if let window = self.window, let responder = window.firstResponder, (responder is NSTextView || responder is NSTextField) {
                return event
            }
            onRedo?()
            return nil
        }
        if isShift && !isCmd && chars == "z" {
            onResetZoom?()
            return nil
        }
        if isCmd && (chars == "=" || chars == "+") {
            onZoomIn?()
            return nil
        }
        if isCmd && chars == "-" {
            onZoomOut?()
            return nil
        }
        return event
    }

    private func handleScrollWheel(event: NSEvent, flags: NSEvent.ModifierFlags) -> NSEvent? {
        guard flags.contains(.command) else {
            return event
        }
        let localPoint = convert(event.locationInWindow, from: nil)
        guard bounds.contains(localPoint) else {
            return event
        }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.scrollingDeltaY * 2.5)
        if delta != 0 {
            onCmdScrollWheel?(delta, localPoint.x)
        }
        return nil
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cleanup()
        }
    }

    public func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

public struct TimelineScrollViewAnchor: NSViewRepresentable {
    private let onScrollViewFound: (NSScrollView) -> Void
    private let onScrollChanged: ((CGFloat, CGFloat) -> Void)?

    public init(
        onScrollViewFound: @escaping (NSScrollView) -> Void,
        onScrollChanged: ((CGFloat, CGFloat) -> Void)? = nil
    ) {
        self.onScrollViewFound = onScrollViewFound
        self.onScrollChanged = onScrollChanged
    }

    public func makeNSView(context: Context) -> TimelineScrollViewAnchorNSView {
        let view = TimelineScrollViewAnchorNSView()
        view.onScrollViewFound = onScrollViewFound
        view.onScrollChanged = onScrollChanged
        return view
    }

    public func updateNSView(_ nsView: TimelineScrollViewAnchorNSView, context: Context) {
        nsView.onScrollViewFound = onScrollViewFound
        nsView.onScrollChanged = onScrollChanged
        nsView.reportScrollView()
    }

    public static func dismantleNSView(_ nsView: TimelineScrollViewAnchorNSView, coordinator: ()) {
        nsView.cleanup()
    }
}

public final class TimelineScrollViewAnchorNSView: NSView {
    var onScrollViewFound: ((NSScrollView) -> Void)?
    var onScrollChanged: ((CGFloat, CGFloat) -> Void)?
    private var scrollObserver: Any?

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportScrollView()
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        reportScrollView()
    }

    func reportScrollView() {
        guard let sv = enclosingScrollView else { return }
        onScrollViewFound?(sv)
        setupScrollObserver(for: sv)
    }

    private func setupScrollObserver(for sv: NSScrollView) {
        guard scrollObserver == nil else { return }
        sv.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: sv.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let sv = self.enclosingScrollView else { return }
                self.onScrollChanged?(sv.contentView.bounds.origin.x, sv.contentView.bounds.origin.y)
            }
        }
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cleanup()
        }
    }

    func cleanup() {
        if let obs = scrollObserver {
            NotificationCenter.default.removeObserver(obs)
            scrollObserver = nil
        }
    }
}
