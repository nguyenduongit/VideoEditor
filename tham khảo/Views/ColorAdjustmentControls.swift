import AppKit

// UI components (InspectorCheckbox, InspectorSectionHeader, InspectorTrackSliderView, InspectorStepperBox, InspectorSliderRow)
// are centralized in Sources/DesignSystem/InspectorComponents.swift

// MARK: - HSL Color Ring Button
public final class HSLColorRingButton: NSButton {
    public let color: NSColor
    public var isSelectedRing: Bool = false {
        didSet { needsDisplay = true }
    }
    public var onClick: (() -> Void)?

    public init(name: String, color: NSColor, isSelected: Bool = false) {
        self.color = color
        self.isSelectedRing = isSelected
        super.init(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        self.title = name
        self.isBordered = false
        self.target = self
        self.action = #selector(btnClicked)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 28) }

    @objc private func btnClicked() {
        onClick?()
    }

    public override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)

        if isSelectedRing {
            // Outer ring
            let outerRadius: CGFloat = 13.0
            let outerRect = NSRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)
            let outerPath = NSBezierPath(ovalIn: outerRect)
            outerPath.lineWidth = 1.6
            color.setStroke()
            outerPath.stroke()

            // Inner filled dot
            let innerRadius: CGFloat = 8.5
            let innerRect = NSRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
            let innerPath = NSBezierPath(ovalIn: innerRect)
            color.setFill()
            innerPath.fill()
        } else {
            // Hollow ring
            let ringRadius: CGFloat = 11.5
            let ringRect = NSRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
            let ringPath = NSBezierPath(ovalIn: ringRect)
            ringPath.lineWidth = 3.0
            color.setStroke()
            ringPath.stroke()
        }
    }
}

// MARK: - HSL Color Rings Row View (Eyedropper + 8 Color Rings)
public final class HSLColorRingsRow: NSView {
    public static let standardColors: [(name: String, color: NSColor, hueGradient: [NSColor], satGradient: [NSColor], brightGradient: [NSColor])] = [
        // 0: Red
        (
            "Đỏ",
            NSColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1.0),
            [NSColor(red: 0.97, green: 0.22, blue: 0.54, alpha: 1.0), NSColor(red: 1.0, green: 0.16, blue: 0.23, alpha: 1.0), NSColor(red: 1.0, green: 0.63, blue: 0.23, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1.0)],
            [NSColor(red: 0.20, green: 0.05, blue: 0.04, alpha: 1.0), NSColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1.0), NSColor.white]
        ),
        // 1: Orange
        (
            "Cam",
            NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1.0),
            [NSColor(red: 1.00, green: 0.25, blue: 0.15, alpha: 1.0), NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1.0), NSColor(red: 1.00, green: 0.85, blue: 0.10, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1.0)],
            [NSColor(red: 0.25, green: 0.12, blue: 0.02, alpha: 1.0), NSColor(red: 1.00, green: 0.58, blue: 0.00, alpha: 1.0), NSColor.white]
        ),
        // 2: Yellow
        (
            "Vàng",
            NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0),
            [NSColor(red: 1.00, green: 0.55, blue: 0.05, alpha: 1.0), NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0), NSColor(red: 0.55, green: 0.85, blue: 0.15, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0)],
            [NSColor(red: 0.25, green: 0.20, blue: 0.02, alpha: 1.0), NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0), NSColor.white]
        ),
        // 3: Green
        (
            "Lục",
            NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0),
            [NSColor(red: 0.75, green: 0.85, blue: 0.10, alpha: 1.0), NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0), NSColor(red: 0.10, green: 0.80, blue: 0.75, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)],
            [NSColor(red: 0.04, green: 0.20, blue: 0.08, alpha: 1.0), NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0), NSColor.white]
        ),
        // 4: Cyan
        (
            "Cyan",
            NSColor(red: 0.20, green: 0.68, blue: 0.90, alpha: 1.0),
            [NSColor(red: 0.15, green: 0.80, blue: 0.60, alpha: 1.0), NSColor(red: 0.20, green: 0.68, blue: 0.90, alpha: 1.0), NSColor(red: 0.15, green: 0.45, blue: 0.95, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 0.20, green: 0.68, blue: 0.90, alpha: 1.0)],
            [NSColor(red: 0.03, green: 0.18, blue: 0.25, alpha: 1.0), NSColor(red: 0.20, green: 0.68, blue: 0.90, alpha: 1.0), NSColor.white]
        ),
        // 5: Blue
        (
            "Lam",
            NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0),
            [NSColor(red: 0.15, green: 0.70, blue: 0.95, alpha: 1.0), NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0), NSColor(red: 0.55, green: 0.30, blue: 0.95, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)],
            [NSColor(red: 0.02, green: 0.12, blue: 0.28, alpha: 1.0), NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0), NSColor.white]
        ),
        // 6: Purple
        (
            "Tím",
            NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0),
            [NSColor(red: 0.25, green: 0.40, blue: 0.95, alpha: 1.0), NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0), NSColor(red: 0.95, green: 0.25, blue: 0.65, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)],
            [NSColor(red: 0.18, green: 0.06, blue: 0.24, alpha: 1.0), NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0), NSColor.white]
        ),
        // 7: Magenta
        (
            "Hồng",
            NSColor(red: 1.00, green: 0.18, blue: 0.55, alpha: 1.0),
            [NSColor(red: 0.70, green: 0.25, blue: 0.90, alpha: 1.0), NSColor(red: 1.00, green: 0.18, blue: 0.55, alpha: 1.0), NSColor(red: 1.00, green: 0.20, blue: 0.20, alpha: 1.0)],
            [NSColor(white: 0.45, alpha: 1.0), NSColor(red: 1.00, green: 0.18, blue: 0.55, alpha: 1.0)],
            [NSColor(red: 0.25, green: 0.04, blue: 0.14, alpha: 1.0), NSColor(red: 1.00, green: 0.18, blue: 0.55, alpha: 1.0), NSColor.white]
        )
    ]

    public var selectedIndex: Int = 0 {
        didSet {
            for (idx, btn) in ringButtons.enumerated() {
                btn.isSelectedRing = (idx == selectedIndex)
            }
        }
    }
    public var onSelect: ((Int) -> Void)?
    public var onEyedropper: (() -> Void)?

    private let eyedropperBtn = NSButton()
    public private(set) var ringButtons: [HSLColorRingButton] = []

    public init(selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void) {
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        super.init(frame: .zero)

        // Setup eyedropper button
        eyedropperBtn.bezelStyle = .circular
        eyedropperBtn.isBordered = false
        eyedropperBtn.wantsLayer = true
        eyedropperBtn.layer?.backgroundColor = NSColor(white: 0.18, alpha: 1.0).cgColor
        eyedropperBtn.layer?.cornerRadius = 14.0
        eyedropperBtn.image = NSImage(systemSymbolName: "eyedropper.halffull", accessibilityDescription: "Pick Color") ?? NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Pick Color")
        eyedropperBtn.contentTintColor = NSColor(white: 0.88, alpha: 1.0)
        eyedropperBtn.target = self
        eyedropperBtn.action = #selector(eyedropperClicked)
        eyedropperBtn.toolTip = "Chấm màu từ khung hình"

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.distribution = .equalSpacing

        stack.addArrangedSubview(eyedropperBtn)
        eyedropperBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eyedropperBtn.widthAnchor.constraint(equalToConstant: 28),
            eyedropperBtn.heightAnchor.constraint(equalToConstant: 28)
        ])

        for (idx, item) in Self.standardColors.enumerated() {
            let ring = HSLColorRingButton(name: item.name, color: item.color, isSelected: idx == selectedIndex)
            ring.toolTip = "\(item.name)"
            ring.onClick = { [weak self] in
                self?.selectedIndex = idx
                self?.onSelect?(idx)
            }
            ringButtons.append(ring)
            stack.addArrangedSubview(ring)
        }

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func eyedropperClicked() {
        onEyedropper?()
    }
}
