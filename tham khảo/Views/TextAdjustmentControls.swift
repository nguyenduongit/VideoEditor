import AppKit

// MARK: - Color Palette Swatch Button
public final class ColorSwatchButton: NSButton {
    public let hexColor: String
    public var isSelectedColor: Bool = false {
        didSet { needsDisplay = true }
    }
    public var onSelect: ((String) -> Void)?

    public init(hex: String, isSelected: Bool = false) {
        self.hexColor = hex
        self.isSelectedColor = isSelected
        super.init(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        self.title = hex
        self.isBordered = false
        self.bezelStyle = .circular
        self.wantsLayer = true
        self.target = self
        self.action = #selector(clicked)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { NSSize(width: 26, height: 26) }

    @objc private func clicked() {
        onSelect?(hexColor)
    }

    private func color(from hex: String) -> NSColor {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    public override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 10.0
        let swatchColor = color(from: hexColor)

        if isSelectedColor {
            // Outer cyan ring
            let outerPath = NSBezierPath(ovalIn: NSRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
            NSColor(red: 0.05, green: 0.72, blue: 0.86, alpha: 1.0).setStroke()
            outerPath.lineWidth = 2.0
            outerPath.stroke()

            // Inner circle with gap
            let innerPath = NSBezierPath(ovalIn: NSRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
            swatchColor.setFill()
            innerPath.fill()
        } else {
            let circlePath = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            swatchColor.setFill()
            circlePath.fill()

            // Subtle border around light swatches (like white)
            let border = NSColor(white: 0.35, alpha: 0.8)
            border.setStroke()
            circlePath.lineWidth = 1.0
            circlePath.stroke()
        }
    }
}

// MARK: - Color Palette Row View
public final class ColorPaletteRow: NSView {
    public static let standardColors = [
        "#FFFFFF", // White
        "#FFFF00", // Yellow
        "#F21429", // Red
        "#00F0FF", // Cyan
        "#E040FB", // Magenta / Purple
        "#FF6D00", // Orange
        "#00E676", // Green
        "#000000"  // Black
    ]

    public var selectedHex: String = "#FFFFFF" {
        didSet {
            for btn in buttons {
                btn.isSelectedColor = btn.hexColor.caseInsensitiveCompare(selectedHex) == .orderedSame
            }
        }
    }
    public var onSelect: ((String) -> Void)?
    private var buttons: [ColorSwatchButton] = []

    public init(selectedHex: String = "#FFFFFF", colors: [String] = standardColors, onSelect: @escaping (String) -> Void) {
        self.selectedHex = selectedHex
        self.onSelect = onSelect
        super.init(frame: .zero)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY

        for hex in colors {
            let btn = ColorSwatchButton(hex: hex, isSelected: hex.caseInsensitiveCompare(selectedHex) == .orderedSame)
            btn.onSelect = { [weak self] chosenHex in
                self?.selectedHex = chosenHex
                self?.onSelect?(chosenHex)
            }
            buttons.append(btn)
            stack.addArrangedSubview(btn)
        }

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Preset Selection Card Button
public final class PresetSelectionCard: NSButton {
    public let presetId: Int
    public var isSelectedPreset: Bool = false {
        didSet { updateAppearance() }
    }
    public var onSelect: ((Int) -> Void)?

    public init(id: Int, icon: String, title: String, isSelected: Bool = false) {
        self.presetId = id
        self.isSelectedPreset = isSelected
        super.init(frame: .zero)

        self.title = "\(icon) \(title)"
        self.font = .systemFont(ofSize: 12, weight: .semibold)
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 6.0
        self.layer?.borderWidth = 1.5
        self.target = self
        self.action = #selector(clicked)

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 32)
    }

    @objc private func clicked() {
        onSelect?(presetId)
    }

    private func updateAppearance() {
        if isSelectedPreset {
            layer?.backgroundColor = NSColor(red: 0.05, green: 0.72, blue: 0.86, alpha: 0.15).cgColor
            layer?.borderColor = NSColor(red: 0.05, green: 0.72, blue: 0.86, alpha: 1.0).cgColor
            contentTintColor = NSColor(red: 0.05, green: 0.72, blue: 0.86, alpha: 1.0)
        } else {
            layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
            layer?.borderColor = NSColor(white: 0.22, alpha: 1.0).cgColor
            contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        }
    }
}
