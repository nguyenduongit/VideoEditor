import AppKit

enum InspectorMainTab: Int, CaseIterable {
    case video = 0
    case adjustment = 1
    case text = 2
    case audio = 3

    var title: String {
        switch self {
        case .video: return "Video"
        case .adjustment: return "Adjustment"
        case .text: return "Text"
        case .audio: return "Audio"
        }
    }

    var subTabs: [String] {
        switch self {
        case .video:
            return ["Khung hình", "Kéo chân AI", "Hiệu ứng"]
        case .adjustment:
            return ["Cơ bản", "Phong cách", "HSL"]
        case .text:
            return ["Nội dung & Vị trí", "Kiểu dáng", "Chuyển động"]
        case .audio:
            return ["Nhạc & Nhịp", "Fade & Trim"]
        }
    }
}

final class InspectorNavigationState {
    var mainTab: InspectorMainTab = .video
    private var subTabMemory: [InspectorMainTab: Int] = [:]

    func currentSubTab(for tab: InspectorMainTab) -> Int {
        let maxIndex = max(0, tab.subTabs.count - 1)
        return min(maxIndex, max(0, subTabMemory[tab] ?? 0))
    }

    func setSubTab(_ index: Int, for tab: InspectorMainTab) {
        let maxIndex = max(0, tab.subTabs.count - 1)
        subTabMemory[tab] = min(maxIndex, max(0, index))
    }
}

final class HeaderTabBarControl: NSSegmentedControl {
    override var isFlipped: Bool { true }
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }
    private var hoveredSegment: Int? = nil
    private var trackingArea: NSTrackingArea?

    override var selectedSegment: Int {
        didSet { needsDisplay = true }
    }

    override func setLabel(_ label: String, forSegment segment: Int) {
        super.setLabel(label, forSegment: segment)
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard segmentCount > 0, bounds.contains(loc) else {
            if hoveredSegment != nil { hoveredSegment = nil; needsDisplay = true }
            return
        }
        let segWidth = bounds.width / CGFloat(segmentCount)
        let idx = max(0, min(segmentCount - 1, Int(loc.x / segWidth)))
        if hoveredSegment != idx {
            hoveredSegment = idx
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredSegment = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location), segmentCount > 0 else { return }
        let segWidth = bounds.width / CGFloat(segmentCount)
        let clickedSeg = max(0, min(segmentCount - 1, Int(location.x / segWidth)))
        selectedSegment = clickedSeg
        needsDisplay = true
        sendAction(action, to: target)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard segmentCount > 0 else { return }
        let segWidth = bounds.width / CGFloat(segmentCount)

        // Base header background
        DS.Color.panelBg.setFill()
        bounds.fill()

        // 1. Bottom border line separating from sidebar body first
        let bottomBorder = NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        DS.Color.divider.setFill()
        bottomBorder.fill()

        for i in 0..<segmentCount {
            let startX = round(CGFloat(i) * segWidth)
            let endX = (i == segmentCount - 1) ? bounds.width : round(CGFloat(i + 1) * segWidth)
            let rect = NSRect(x: startX, y: 0, width: endX - startX, height: bounds.height)
            let isSelected = i == selectedSegment
            let isHovered = i == hoveredSegment && !isSelected

            if isSelected {
                DS.Color.surfaceBg.setFill()
                rect.fill()

                // Bottom active accent line - sits exactly on the bottom border
                let indicatorHeight: CGFloat = 2.5
                let indicatorRect = NSRect(x: rect.minX, y: bounds.height - indicatorHeight, width: rect.width, height: indicatorHeight)
                DS.Color.accent.setFill()
                indicatorRect.fill()
            } else if isHovered {
                DS.Color.hoverBg.setFill()
                rect.fill()
            }

            // Vertical divider between tabs
            if i < segmentCount - 1 {
                let divRect = NSRect(x: rect.maxX - 0.5, y: 8, width: 1, height: bounds.height - 16)
                DS.Color.divider.setFill()
                divRect.fill()
            }

            // Label text
            let title = label(forSegment: i) ?? ""
            let font: NSFont = isSelected ? .systemFont(ofSize: 12, weight: .bold) : .systemFont(ofSize: 12, weight: .medium)
            let color: NSColor = isSelected ? DS.Color.textPrimary : (isHovered ? DS.Color.textPrimary : DS.Color.textSecondary)
            let str = NSAttributedString(string: title, attributes: [
                .font: font,
                .foregroundColor: color
            ])
            let strSize = str.size()
            let textPoint = NSPoint(
                x: round(rect.midX - strSize.width / 2),
                y: round(rect.midY - strSize.height / 2)
            )
            str.draw(at: textPoint)
        }
    }
}
