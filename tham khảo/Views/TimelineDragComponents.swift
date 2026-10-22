import AppKit

/// A sorted screen-space beat grid. A gesture builds it once; each motion uses O(log n).
struct TimelineSnapGrid: Sendable {
    struct Point: Sendable { let beat: Int; let x: CGFloat }
    let points: [Point]
    init(session: EditorSession, map: EditorTimeMap, pixelsPerSecond: Double) {
        let first = Int(ceil(-session.phase * session.baseBPM / 60))
        let last = Int(floor((session.duration - session.phase) * session.baseBPM / 60))
        points = last >= first ? (first...last).map {
            Point(beat: $0, x: 12 + CGFloat(map.outputTime(for: session.beatTime($0)) * pixelsPerSecond))
        } : []
    }
    func nearest(to x: CGFloat) -> Point? {
        guard !points.isEmpty else { return nil }
        var low = 0, high = points.count
        while low < high {
            let mid = (low + high) / 2
            if points[mid].x < x { low = mid + 1 } else { high = mid }
        }
        if low == 0 { return points[0] }
        if low == points.count { return points[low - 1] }
        return x - points[low - 1].x <= points[low].x - x ? points[low - 1] : points[low]
    }
}

/// The only moving visual. It lives above the editor, so vertical movement is not clipped
/// to the timeline lane. Mouse events pass through to the gesture owner.
final class TimelineDragOverlay: NSView {
    var kind: EditorFadeKind?
    var videoEffectKind: VideoEffectKind?
    var beatCount = 32
    var valid = true
    /// Horizontal offset (pts) from overlay's left edge to where it will snap on release.
    /// 0 when already at the snap position (resize mode). Drawn as a dashed guide line.
    var snapOffsetX: CGFloat = 0
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        (videoEffectKind != nil ? NSColor.systemOrange : (kind == nil ? NSColor.systemBlue : .systemPurple)).withAlphaComponent(0.88).setFill()
        let shape = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        shape.fill()
        // ── Snap indicator ──────────────────────────────────────────────────────
        // Dashed vertical line showing where the left edge will land on release.
        if abs(snapOffsetX) > 1 {
            let ix = snapOffsetX
            if ix > 1 && ix < bounds.width - 1 {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: ix, y: rect.minY + 2))
                p.line(to: NSPoint(x: ix, y: rect.maxY - 2))
                p.lineWidth = 1
                p.setLineDash([2, 2], count: 2, phase: 0)
                NSColor.white.withAlphaComponent(0.55).setStroke(); p.stroke()
            }
        }
        if let videoEffectKind {
            let path = NSBezierPath()
            let from = videoEffectKind == .fadeIn ? rect.maxY - 3 : rect.minY + 3
            let to = videoEffectKind == .fadeIn ? rect.minY + 3 : rect.maxY - 3
            path.move(to: NSPoint(x: rect.minX + 3, y: from)); path.line(to: NSPoint(x: rect.maxX - 3, y: to))
            NSColor.white.setStroke(); path.lineWidth = 1.5; path.stroke()
        } else if let kind = kind {
            let path = NSBezierPath()
            let left = rect.minX + 3, right = rect.maxX - 3
            path.move(to: NSPoint(x: left, y: kind == .fadeIn ? rect.maxY - 3 : rect.minY + 3))
            if kind == .fadeOutIn { path.line(to: NSPoint(x: rect.midX, y: rect.maxY - 3)) }
            path.line(to: NSPoint(x: right, y: kind == .fadeOut ? rect.maxY - 3 : rect.minY + 3))
            NSColor.white.setStroke(); path.lineWidth = 1.5; path.stroke()
        } else if rect.width > 65 {
            let text = beatCount % 4 == 0 && rect.width > 110 ? "\(beatCount / 4) nhịp • \(beatCount) phách" : "\(beatCount) phách"
            (text as NSString).draw(in: rect.insetBy(dx: 7, dy: 4), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.white])
        }
        (valid ? NSColor.white.withAlphaComponent(0.85) : .systemRed).setStroke()
        shape.lineWidth = valid ? 1 : 2; shape.stroke()
    }
}

final class CountBlockDragButton: ProToolButton {
    var onDrag: ((NSEvent) -> Void)?
    func applyProfessionalStyle() {
        configure(
            title: title.isEmpty ? "Voice Count" : title,
            symbolName: "waveform.badge.plus",
            iconSize: 12,
            iconWeight: .semibold,
            fontSize: 12,
            style: .secondary
        )
        setCustomTheme(
            bg: NSColor.systemBlue.withAlphaComponent(0.16),
            border: NSColor.systemBlue.withAlphaComponent(0.70),
            text: DS.Color.textPrimary,
            iconTint: NSColor.systemBlue
        )
        heightAnchor.constraint(equalToConstant: DS.Size.buttonHeight).isActive = true
        toolTip = "Kéo xuống timeline; block mới luôn có 8 nhịp (32 phách)."
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }; onDrag?(event)
    }
}

final class FadeDragButton: ProToolButton {
    var onDrag: ((NSEvent) -> Void)?
    func applyProfessionalStyle() {
        configure(
            title: title,
            symbolName: "circle.lefthalf.filled",
            iconSize: 12,
            iconWeight: .semibold,
            fontSize: 12,
            style: .secondary
        )
        setCustomTheme(
            bg: DS.Color.surfaceBg,
            border: NSColor.systemPurple.withAlphaComponent(0.55),
            text: DS.Color.textPrimary,
            iconTint: .systemPurple
        )
        heightAnchor.constraint(equalToConstant: DS.Size.buttonHeight).isActive = true
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }; onDrag?(event)
    }
}

final class VideoEffectDragButton: ProToolButton {
    var onDrag: ((NSEvent) -> Void)?
    func applyProfessionalStyle() {
        configure(title: title, symbolName: "sparkles.rectangle.stack", iconSize: 12, iconWeight: .semibold, fontSize: 12, style: .secondary)
        setCustomTheme(bg: NSColor.systemOrange.withAlphaComponent(0.12), border: NSColor.systemOrange.withAlphaComponent(0.65), text: DS.Color.textPrimary, iconTint: .systemOrange)
        heightAnchor.constraint(equalToConstant: DS.Size.buttonHeight).isActive = true
    }
    override func mouseDown(with event: NSEvent) { guard isEnabled else { return }; onDrag?(event) }
}
