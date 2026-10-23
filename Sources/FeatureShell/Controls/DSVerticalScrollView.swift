import SwiftUI
import AppKit
import DesignSystem

/// Container view providing vertical scrolling with a permanently pre-allocated scrollbar track.
/// Guarantees zero layout shift when content expands or overflows.
/// Complies with R3.1, R3.4, R8.1, and R8.2 of AGENTS.md.
public struct DSVerticalScrollView<Content: View>: View {
    private let backgroundColor: Color
    private let content: Content

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var enclosingScrollView: NSScrollView?

    public init(
        backgroundColor: Color = DSColors.blockBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let availableW = geo.size.width
            let availableH = geo.size.height
            let scrollerW = DSSize.timelineBottomBuffer
            let contentW = max(0, availableW - scrollerW)

            HStack(spacing: DSSpacing.none) {
                scrollContentView(width: contentW, availableH: availableH)
                scrollBarView(width: scrollerW, availableH: availableH)
            }
            .frame(width: availableW, height: availableH)
            .clipped()
            .onAppear {
                viewportHeight = availableH
                if let sv = enclosingScrollView {
                    updateMetrics(from: sv)
                }
            }
            .onChange(of: availableH) { _, newH in
                viewportHeight = newH
                if let sv = enclosingScrollView {
                    updateMetrics(from: sv)
                }
            }
        }
    }

    private func scrollContentView(width: CGFloat, availableH: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .frame(width: width)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DSContentHeightPreferenceKey.self,
                            value: geo.size.height
                        )
                    }
                )
                .background(
                    DSVerticalScrollViewAnchor(
                        onScrollViewFound: { sv in
                            enclosingScrollView = sv
                            updateMetrics(from: sv)
                        },
                        onMetricsChanged: { offset, cHeight, vHeight in
                            scrollOffset = offset
                            if cHeight > 0 {
                                contentHeight = max(contentHeight, cHeight)
                            }
                            viewportHeight = vHeight > 0 ? vHeight : availableH
                        }
                    )
                )
        }
        .frame(width: width, height: availableH)
        .clipped()
        .onPreferenceChange(DSContentHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 {
                contentHeight = newHeight
                if enclosingScrollView != nil {
                    let maxScroll = max(0, newHeight - viewportHeight)
                    if scrollOffset > maxScroll {
                        scrollTo(targetY: maxScroll)
                    }
                }
            }
        }
    }

    private func scrollBarView(width: CGFloat, availableH: CGFloat) -> some View {
        TimelineVerticalScrollBarView(
            scrollOffset: $scrollOffset,
            contentHeight: contentHeight,
            viewportHeight: viewportHeight > 0 ? viewportHeight : availableH,
            backgroundColor: backgroundColor,
            onScrollTo: { targetY in
                scrollTo(targetY: targetY)
            }
        )
        .frame(width: width, height: availableH)
    }

    private func updateMetrics(from sv: NSScrollView) {
        scrollOffset = sv.contentView.bounds.origin.y
        contentHeight = sv.documentView?.bounds.height ?? 0
        viewportHeight = sv.contentView.bounds.height
    }

    private func scrollTo(targetY: CGFloat) {
        guard let sv = enclosingScrollView else { return }
        let maxScroll = max(0, contentHeight - viewportHeight)
        let clampedY = max(0, min(maxScroll, targetY))
        let pt = NSPoint(x: sv.contentView.bounds.origin.x, y: clampedY)
        sv.contentView.scroll(to: pt)
        sv.reflectScrolledClipView(sv.contentView)
        scrollOffset = clampedY
    }
}

/// AppKit anchor reporting scroll metrics and observing content frame changes.
public struct DSVerticalScrollViewAnchor: NSViewRepresentable {
    let onScrollViewFound: (NSScrollView) -> Void
    let onMetricsChanged: (CGFloat, CGFloat, CGFloat) -> Void

    public func makeNSView(context: Context) -> DSVerticalScrollViewAnchorNSView {
        let view = DSVerticalScrollViewAnchorNSView()
        view.onScrollViewFound = onScrollViewFound
        view.onMetricsChanged = onMetricsChanged
        return view
    }

    public func updateNSView(_ nsView: DSVerticalScrollViewAnchorNSView, context: Context) {
        nsView.onScrollViewFound = onScrollViewFound
        nsView.onMetricsChanged = onMetricsChanged
        nsView.reportMetrics()
    }

    public static func dismantleNSView(_ nsView: DSVerticalScrollViewAnchorNSView, coordinator: ()) {
        nsView.cleanup()
    }
}

public final class DSVerticalScrollViewAnchorNSView: NSView {
    var onScrollViewFound: ((NSScrollView) -> Void)?
    var onMetricsChanged: ((CGFloat, CGFloat, CGFloat) -> Void)?
    private var boundsObserver: Any?
    private var frameObserver: Any?

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportMetrics()
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        reportMetrics()
    }

    func reportMetrics() {
        guard let sv = enclosingScrollView else { return }
        sv.hasVerticalScroller = false
        sv.verticalScroller = nil
        onScrollViewFound?(sv)
        setupObservers(for: sv)
        sendMetrics(from: sv)
        DispatchQueue.main.async { [weak self] in
            guard let self, let sv = self.enclosingScrollView else { return }
            self.sendMetrics(from: sv)
        }
    }

    private func setupObservers(for sv: NSScrollView) {
        if boundsObserver == nil {
            sv.contentView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: sv.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let sv = self.enclosingScrollView else { return }
                    self.sendMetrics(from: sv)
                }
            }
        }
        if frameObserver == nil, let doc = sv.documentView {
            doc.postsFrameChangedNotifications = true
            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: doc,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let sv = self.enclosingScrollView else { return }
                    self.sendMetrics(from: sv)
                }
            }
        }
    }

    private func sendMetrics(from sv: NSScrollView) {
        let offset = sv.contentView.bounds.origin.y
        let contentH = sv.documentView?.bounds.height ?? 0
        let viewportH = sv.contentView.bounds.height
        onMetricsChanged?(offset, contentH, viewportH)
    }

    func cleanup() {
        if let obs = boundsObserver {
            NotificationCenter.default.removeObserver(obs)
            boundsObserver = nil
        }
        if let obs = frameObserver {
            NotificationCenter.default.removeObserver(obs)
            frameObserver = nil
        }
    }
}

public struct DSContentHeightPreferenceKey: PreferenceKey {
    public static let defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = max(value, next)
        }
    }
}

