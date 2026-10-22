import AppKit

// MARK: - Inspector Checkbox (CapCut / Pro Style 18x18px)
public final class InspectorCheckbox: NSButton {
    public var isChecked: Bool {
        get { state == .on }
        set {
            state = newValue ? .on : .off
            needsDisplay = true
        }
    }
    public var onToggle: ((Bool) -> Void)?
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?

    public init(checked: Bool = true) {
        super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        self.title = ""
        self.setButtonType(.switch)
        self.state = checked ? .on : .off
        self.isBordered = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: 18, height: 18)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    public override func performClick(_ sender: Any?) {
        guard isEnabled else { return }
        isChecked.toggle()
        sendAction(action, to: target)
        onToggle?(isChecked)
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isChecked.toggle()
        sendAction(action, to: target)
        onToggle?(isChecked)
    }

    public override var isFlipped: Bool { true }

    public override func draw(_ dirtyRect: NSRect) {
        let boxRect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: boxRect, xRadius: 4.5, yRadius: 4.5)

        if isChecked {
            let cyan = NSColor(red: 0.05, green: 0.72, blue: 0.86, alpha: 1.0)
            let hoverCyan = NSColor(red: 0.15, green: 0.80, blue: 0.94, alpha: 1.0)
            (isHovered ? hoverCyan : cyan).setFill()
            path.fill()

            let center = NSPoint(x: boxRect.midX, y: boxRect.midY)
            let checkPath = NSBezierPath()
            let p1 = NSPoint(x: center.x - 3.6, y: center.y - 0.5)
            let p2 = NSPoint(x: center.x - 1.2, y: center.y + 2.5)
            let p3 = NSPoint(x: center.x + 3.6, y: center.y - 2.5)
            checkPath.move(to: p1)
            checkPath.line(to: p2)
            checkPath.line(to: p3)
            checkPath.lineWidth = 2.0
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            NSColor.white.setStroke()
            checkPath.stroke()
        } else {
            let bg = isHovered ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.14, alpha: 1.0)
            bg.setFill()
            path.fill()

            let border = isHovered ? NSColor(white: 0.50, alpha: 1.0) : NSColor(white: 0.35, alpha: 1.0)
            border.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }
}

// MARK: - Inspector Section Header
public final class InspectorSectionHeader: NSView {
    public let checkbox = InspectorCheckbox()
    public let titleLabel = NSTextField(labelWithString: "")
    public let resetButton = NSButton()
    public var onReset: (() -> Void)?

    public init(
        title: String,
        showsCheckbox: Bool = false,
        isChecked: Bool = true,
        showsReset: Bool = true,
        onToggle: ((Bool) -> Void)? = nil,
        onReset: (() -> Void)? = nil
    ) {
        self.onReset = onReset
        super.init(frame: .zero)

        checkbox.isChecked = isChecked
        checkbox.onToggle = onToggle
        checkbox.isHidden = !showsCheckbox

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = NSColor(white: 0.93, alpha: 1.0)

        resetButton.bezelStyle = .regularSquare
        resetButton.isBordered = false
        resetButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Reset")
        resetButton.contentTintColor = NSColor(white: 0.70, alpha: 1.0)
        resetButton.toolTip = "Đặt lại \(title)"
        resetButton.target = self
        resetButton.action = #selector(resetClicked)
        resetButton.isHidden = !showsReset

        addSubview(checkbox)
        addSubview(titleLabel)
        addSubview(resetButton)

        checkbox.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        if showsCheckbox {
            NSLayoutConstraint.activate([
                checkbox.leadingAnchor.constraint(equalTo: leadingAnchor),
                checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
                checkbox.widthAnchor.constraint(equalToConstant: 18),
                checkbox.heightAnchor.constraint(equalToConstant: 18),
                titleLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            resetButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            resetButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            resetButton.widthAnchor.constraint(equalToConstant: 22),
            resetButton.heightAnchor.constraint(equalToConstant: 22),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    // Overload matching original CapCutSectionHeader signature
    public convenience init(title: String, isChecked: Bool = true, onToggle: ((Bool) -> Void)? = nil, onReset: (() -> Void)? = nil) {
        self.init(title: title, showsCheckbox: true, isChecked: isChecked, showsReset: true, onToggle: onToggle, onReset: onReset)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public var isEnabled: Bool = true {
        didSet {
            checkbox.isEnabled = isEnabled
            resetButton.isEnabled = isEnabled
            alphaValue = isEnabled ? 1.0 : 0.4
        }
    }

    @objc private func resetClicked() {
        onReset?()
    }
}

// MARK: - Inspector Track Slider View (NSSlider Subclass with CapCut Pro Aesthetics)
public final class InspectorTrackSliderView: NSSlider {
    public var range: ClosedRange<Double> = -100...100 {
        didSet {
            minValue = range.lowerBound
            maxValue = range.upperBound
        }
    }
    public var defaultValue: Double = 0.0
    public var step: Double = 1.0
    public var trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)]
    public var onValueChanged: ((Double) -> Void)?

    public var value: Double {
        get { doubleValue }
        set {
            let clamped = max(range.lowerBound, min(range.upperBound, newValue))
            doubleValue = clamped
            needsDisplay = true
        }
    }

    private var isDragging = false

    public init(
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        step: Double = 1.0,
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)]
    ) {
        self.range = range
        self.defaultValue = defaultValue
        self.step = step
        self.trackColors = trackColors
        super.init(frame: .zero)
        self.minValue = range.lowerBound
        self.maxValue = range.upperBound
        self.doubleValue = max(range.lowerBound, min(range.upperBound, value))
        self.isContinuous = true
        wantsLayer = true
    }

    // Convenience matching original CapCutTrackSliderView signature
    public convenience init(
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)]
    ) {
        self.init(value: value, range: range, defaultValue: defaultValue, step: 1.0, trackColors: trackColors)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var thumbWidth: CGFloat { 12.0 }
    private var thumbHeight: CGFloat { 18.0 }

    private func thumbCenterX(for val: Double) -> CGFloat {
        let usableWidth = bounds.width - thumbWidth
        guard usableWidth > 0, range.upperBound > range.lowerBound else { return bounds.width / 2 }
        let progress = (val - range.lowerBound) / (range.upperBound - range.lowerBound)
        return (thumbWidth / 2.0) + CGFloat(progress) * usableWidth
    }

    private func value(for x: CGFloat) -> Double {
        let usableWidth = bounds.width - thumbWidth
        guard usableWidth > 0 else { return defaultValue }
        let clampedX = max(thumbWidth / 2.0, min(bounds.width - thumbWidth / 2.0, x))
        let progress = Double((clampedX - thumbWidth / 2.0) / usableWidth)
        let rawVal = range.lowerBound + progress * (range.upperBound - range.lowerBound)
        if step > 0 {
            let stepsCount = round((rawVal - range.lowerBound) / step)
            let stepped = range.lowerBound + stepsCount * step
            return max(range.lowerBound, min(range.upperBound, stepped))
        }
        return max(range.lowerBound, min(range.upperBound, rawVal))
    }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            value = defaultValue
            sendAction(action, to: target)
            onValueChanged?(value)
            needsDisplay = true
            return
        }
        isDragging = true
        let point = convert(event.locationInWindow, from: nil)
        value = value(for: point.x)
        sendAction(action, to: target)
        onValueChanged?(value)
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        value = value(for: point.x)
        sendAction(action, to: target)
        onValueChanged?(value)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    public override func draw(_ dirtyRect: NSRect) {
        let trackHeight: CGFloat = 3.5
        let trackY = (bounds.height - trackHeight) / 2.0
        let trackRect = NSRect(x: thumbWidth / 2.0, y: trackY, width: max(0, bounds.width - thumbWidth), height: trackHeight)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: trackHeight / 2.0, yRadius: trackHeight / 2.0)

        if trackColors.count > 1 {
            let gradient = NSGradient(colors: trackColors)
            gradient?.draw(in: trackPath, angle: 0)
        } else if let singleColor = trackColors.first {
            singleColor.setFill()
            trackPath.fill()
        }

        let centerX = thumbCenterX(for: value)
        let thumbRect = NSRect(
            x: centerX - thumbWidth / 2.0,
            y: (bounds.height - thumbHeight) / 2.0,
            width: thumbWidth,
            height: thumbHeight
        )

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2.5
        shadow.set()

        let thumbPath = NSBezierPath(roundedRect: thumbRect, xRadius: 6.0, yRadius: 6.0)
        NSColor.white.setFill()
        thumbPath.fill()

        NSShadow().set()

        NSColor(white: 0.85, alpha: 1.0).setStroke()
        thumbPath.lineWidth = 0.5
        thumbPath.stroke()
    }
}

// MARK: - Inspector Stepper Box (54x24px with Chevrons & Unit Support)
public final class InspectorStepperBox: NSView, NSTextFieldDelegate {
    public var value: Double = 0.0 {
        didSet {
            updateText()
        }
    }
    public var range: ClosedRange<Double> = -100...100
    public var step: Double = 1.0
    public var decimalPlaces: Int = 0
    public var unit: String = ""
    public var onValueChanged: ((Double) -> Void)?

    private let textField = NSTextField()

    public init(
        value: Double = 0.0,
        range: ClosedRange<Double> = -100...100,
        step: Double = 1.0,
        decimalPlaces: Int = 0,
        unit: String = ""
    ) {
        self.value = value
        self.range = range
        self.step = step
        self.decimalPlaces = decimalPlaces
        self.unit = unit
        super.init(frame: NSRect(x: 0, y: 0, width: 54, height: 24))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
        layer?.cornerRadius = 4.0
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.22, alpha: 1.0).cgColor

        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        textField.textColor = NSColor(white: 0.92, alpha: 1.0)
        textField.alignment = .center
        textField.delegate = self
        textField.target = self
        textField.action = #selector(textCommitted)

        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 18)
        ])

        updateText()
    }

    // Convenience matching original CapCutStepperBox
    public convenience init(value: Double = 0.0, range: ClosedRange<Double> = -100...100) {
        self.init(value: value, range: range, step: 1.0, decimalPlaces: 0, unit: "")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateText() {
        if decimalPlaces > 0 {
            let fmt = "%.\(decimalPlaces)f"
            textField.stringValue = String(format: fmt, value) + unit
        } else {
            let intVal = Int(round(value))
            textField.stringValue = "\(intVal)" + unit
        }
    }

    @objc private func textCommitted() {
        var rawStr = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unit.isEmpty {
            rawStr = rawStr.replacingOccurrences(of: unit.trimmingCharacters(in: .whitespaces), with: "")
        }
        rawStr = rawStr.replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "s", with: "")
            .replacingOccurrences(of: "°", with: "")
            .replacingOccurrences(of: "×", with: "")
            .replacingOccurrences(of: "x", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let parsed = Double(rawStr) {
            let clamped = max(range.lowerBound, min(range.upperBound, parsed))
            if step > 0 {
                let stepsCount = round((clamped - range.lowerBound) / step)
                value = max(range.lowerBound, min(range.upperBound, range.lowerBound + stepsCount * step))
            } else {
                value = clamped
            }
            onValueChanged?(value)
        }
        updateText()
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
        textCommitted()
    }

    public func stepUp() {
        let nextVal = value + step
        let clamped = max(range.lowerBound, min(range.upperBound, nextVal))
        value = (decimalPlaces > 0) ? (round(clamped * pow(10, Double(decimalPlaces))) / pow(10, Double(decimalPlaces))) : round(clamped)
        onValueChanged?(value)
        updateText()
    }

    public func stepDown() {
        let nextVal = value - step
        let clamped = max(range.lowerBound, min(range.upperBound, nextVal))
        value = (decimalPlaces > 0) ? (round(clamped * pow(10, Double(decimalPlaces))) / pow(10, Double(decimalPlaces))) : round(clamped)
        onValueChanged?(value)
        updateText()
    }

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x >= bounds.width - 16 {
            if point.y > bounds.height / 2 {
                stepUp()
            } else {
                stepDown()
            }
            return
        }
        window?.makeFirstResponder(textField)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rightX = bounds.width - 9.0
        let midY = bounds.height / 2.0

        let chevronColor = NSColor(white: 0.65, alpha: 1.0)
        chevronColor.setStroke()

        // Up arrow
        let upPath = NSBezierPath()
        upPath.move(to: NSPoint(x: rightX - 3.2, y: midY + 2.5))
        upPath.line(to: NSPoint(x: rightX, y: midY + 5.8))
        upPath.line(to: NSPoint(x: rightX + 3.2, y: midY + 2.5))
        upPath.lineWidth = 1.3
        upPath.stroke()

        // Down arrow
        let downPath = NSBezierPath()
        downPath.move(to: NSPoint(x: rightX - 3.2, y: midY - 2.5))
        downPath.line(to: NSPoint(x: rightX, y: midY - 5.8))
        downPath.line(to: NSPoint(x: rightX + 3.2, y: midY - 2.5))
        downPath.lineWidth = 1.3
        downPath.stroke()
    }
}

// MARK: - Inspector Slider Row (Unified Golden Standard)
public final class InspectorSliderRow: NSView {
    public let titleLabel = NSTextField(labelWithString: "")
    public let sliderView: InspectorTrackSliderView
    public let stepperBox: InspectorStepperBox
    public var displayMultiplier: Double = 1.0

    public init(
        title: String,
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        step: Double = 1.0,
        displayMultiplier: Double = 1.0,
        decimalPlaces: Int = 0,
        unit: String = "",
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)],
        onChange: @escaping (Double) -> Void
    ) {
        self.displayMultiplier = displayMultiplier
        self.sliderView = InspectorTrackSliderView(
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: step,
            trackColors: trackColors
        )
        self.stepperBox = InspectorStepperBox(
            value: value * displayMultiplier,
            range: (range.lowerBound * displayMultiplier)...(range.upperBound * displayMultiplier),
            step: step * displayMultiplier,
            decimalPlaces: decimalPlaces,
            unit: unit
        )
        super.init(frame: .zero)

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.78, alpha: 1.0)

        addSubview(titleLabel)
        addSubview(sliderView)
        addSubview(stepperBox)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderView.translatesAutoresizingMaskIntoConstraints = false
        stepperBox.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            sliderView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            sliderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sliderView.trailingAnchor.constraint(equalTo: stepperBox.leadingAnchor, constant: -10),
            sliderView.heightAnchor.constraint(equalToConstant: 24),

            stepperBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            stepperBox.centerYAnchor.constraint(equalTo: sliderView.centerYAnchor),
            stepperBox.widthAnchor.constraint(equalToConstant: 54),
            stepperBox.heightAnchor.constraint(equalToConstant: 24),

            bottomAnchor.constraint(equalTo: sliderView.bottomAnchor)
        ])

        sliderView.onValueChanged = { [weak self] val in
            guard let self = self else { return }
            self.stepperBox.value = val * self.displayMultiplier
            onChange(val)
        }

        stepperBox.onValueChanged = { [weak self] stepVal in
            guard let self = self else { return }
            let actualVal = (self.displayMultiplier != 0) ? (stepVal / self.displayMultiplier) : stepVal
            self.sliderView.value = actualVal
            self.sliderView.sendAction(self.sliderView.action, to: self.sliderView.target)
            onChange(actualVal)
        }
    }

    // Convenience without displayMultiplier
    public convenience init(
        title: String,
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        step: Double = 1.0,
        decimalPlaces: Int = 0,
        unit: String = "",
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)],
        onChange: @escaping (Double) -> Void
    ) {
        self.init(
            title: title,
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: step,
            displayMultiplier: 1.0,
            decimalPlaces: decimalPlaces,
            unit: unit,
            trackColors: trackColors,
            onChange: onChange
        )
    }

    // Convenience matching original CapCutSliderRow
    public convenience init(
        title: String,
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)],
        onChange: @escaping (Double) -> Void
    ) {
        self.init(
            title: title,
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: 1.0,
            displayMultiplier: 1.0,
            decimalPlaces: 0,
            unit: "",
            trackColors: trackColors,
            onChange: onChange
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateValue(_ val: Double) {
        sliderView.value = val
        stepperBox.value = val * displayMultiplier
    }

    public func display(_ val: Double) {
        updateValue(val)
    }

    public var range: ClosedRange<Double> {
        get { sliderView.range }
        set {
            sliderView.range = newValue
            stepperBox.range = newValue
        }
    }

    public func updateTrackColors(_ colors: [NSColor]) {
        sliderView.trackColors = colors
        sliderView.needsDisplay = true
    }

    public var isEnabled: Bool = true {
        didSet {
            sliderView.isEnabled = isEnabled
            stepperBox.isHidden = !isEnabled
            alphaValue = isEnabled ? 1.0 : 0.4
        }
    }
}

// MARK: - Inspector Toggle Row (Interactive Checkbox + Title)
public final class InspectorToggleRow: NSButton {
    public let checkbox: InspectorCheckbox
    public let titleLabel = NSTextField(labelWithString: "")
    public var onToggle: ((Bool) -> Void)?

    public init(title: String, isChecked: Bool = false, onToggle: ((Bool) -> Void)? = nil) {
        self.checkbox = InspectorCheckbox(checked: isChecked)
        self.onToggle = onToggle
        super.init(frame: .zero)

        self.title = title
        self.setButtonType(.switch)
        self.state = isChecked ? .on : .off
        self.isBordered = false
        self.wantsLayer = true

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.88, alpha: 1.0)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false

        addSubview(checkbox)
        addSubview(titleLabel)

        checkbox.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            checkbox.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 24)
        ])

        checkbox.onToggle = { [weak self] checked in
            guard let self = self else { return }
            self.state = checked ? .on : .off
            if self.target != nil && self.action != nil {
                self.sendAction(self.action, to: self.target)
            } else {
                self.onToggle?(checked)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public var isChecked: Bool {
        get { state == .on }
        set {
            state = newValue ? .on : .off
            checkbox.isChecked = newValue
        }
    }

    public override var isEnabled: Bool {
        didSet {
            checkbox.isEnabled = isEnabled
            titleLabel.textColor = isEnabled ? NSColor(white: 0.88, alpha: 1.0) : NSColor(white: 0.45, alpha: 1.0)
            alphaValue = isEnabled ? 1.0 : 0.4
        }
    }

    public override func performClick(_ sender: Any?) {
        guard isEnabled else { return }
        isChecked.toggle()
        if target != nil && action != nil {
            sendAction(action, to: target)
        } else {
            onToggle?(isChecked)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isChecked.toggle()
        if target != nil && action != nil {
            sendAction(action, to: target)
        } else {
            onToggle?(isChecked)
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        // Subviews handle custom rendering
    }
}

// MARK: - Inspector Segmented Row (Standardized Segment Picker with Label)
public final class InspectorSegmentedRow: NSView {
    public let titleLabel = NSTextField(labelWithString: "")
    public let segmentedControl: NSSegmentedControl
    public var onSelect: ((Int) -> Void)?

    public init(
        title: String? = nil,
        options: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        self.onSelect = onSelect
        self.segmentedControl = NSSegmentedControl(labels: options, trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)

        segmentedControl.segmentStyle = .roundRect
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.selectedSegment = max(0, min(options.count - 1, selectedIndex))
        segmentedControl.target = self
        segmentedControl.action = #selector(segmentClicked)

        if let title = title, !title.isEmpty {
            titleLabel.stringValue = title
            titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
            titleLabel.textColor = NSColor(white: 0.78, alpha: 1.0)
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)

            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 10
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(segmentedControl)

            addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else {
            addSubview(segmentedControl)
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                segmentedControl.topAnchor.constraint(equalTo: topAnchor),
                segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
                segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func segmentClicked() {
        onSelect?(segmentedControl.selectedSegment)
    }

    public var selectedSegment: Int {
        get { segmentedControl.selectedSegment }
        set { segmentedControl.selectedSegment = newValue }
    }
}

// MARK: - Inspector Aspect Ratio Row (Label + Dropdown + Realtime Resolution)
public final class InspectorAspectRatioRow: NSView {
    public let titleLabel = NSTextField(labelWithString: "")
    public let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    public let resolutionLabel = NSTextField(labelWithString: "")
    public let segmentedControl: NSSegmentedControl
    public var onSelect: ((Int) -> Void)?

    public init(
        title: String = "Tỷ lệ",
        options: [String] = ["Original", "9:16", "16:9", "1:1", "4:5"],
        selectedIndex: Int = 0,
        resolutionText: String = "",
        onSelect: @escaping (Int) -> Void
    ) {
        self.onSelect = onSelect
        self.segmentedControl = NSSegmentedControl(labels: options, trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)

        // 1. Label
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        // 2. Dropdown Popup Button
        popup.removeAllItems()
        popup.addItems(withTitles: options)
        popup.selectItem(at: max(0, min(options.count - 1, selectedIndex)))
        popup.target = self
        popup.action = #selector(popupChanged(_:))
        popup.font = .systemFont(ofSize: 12, weight: .regular)
        popup.bezelStyle = .rounded
        popup.controlSize = .small

        // 3. Realtime Resolution Label (#### × ####)
        resolutionLabel.stringValue = resolutionText
        resolutionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        resolutionLabel.textColor = NSColor(white: 0.58, alpha: 1.0)
        resolutionLabel.alignment = .right
        resolutionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // 4. Proxy Segmented Control for automated test compatibility
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.selectedSegment = max(0, min(options.count - 1, selectedIndex))
        segmentedControl.target = self
        segmentedControl.action = #selector(segmentedChanged(_:))
        segmentedControl.isHidden = true

        addSubview(titleLabel)
        addSubview(popup)
        addSubview(resolutionLabel)
        addSubview(segmentedControl)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        popup.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            popup.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            popup.centerYAnchor.constraint(equalTo: centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: 102),

            resolutionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: popup.trailingAnchor, constant: 6),
            resolutionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            resolutionLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateResolution(_ text: String) {
        resolutionLabel.stringValue = text
    }

    public func updateSelection(_ index: Int) {
        let clamped = max(0, min(popup.numberOfItems - 1, index))
        popup.selectItem(at: clamped)
        if clamped < segmentedControl.segmentCount {
            segmentedControl.selectedSegment = clamped
        }
    }

    @objc private func popupChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        if index >= 0 && index < segmentedControl.segmentCount {
            segmentedControl.selectedSegment = index
        }
        onSelect?(index)
    }

    @objc private func segmentedChanged(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        if index >= 0 && index < popup.numberOfItems {
            popup.selectItem(at: index)
        }
        onSelect?(index)
    }
}

// MARK: - Inspector Subheading
public final class InspectorSubheading: NSTextField {
    public init(title: String) {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        stringValue = title.uppercased()
        font = .systemFont(ofSize: 11, weight: .bold)
        textColor = NSColor(white: 0.48, alpha: 1.0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Backward Compatibility Typealiases
public typealias CapCutCheckbox = InspectorCheckbox
public typealias CapCutSectionHeader = InspectorSectionHeader
public typealias CapCutTrackSliderView = InspectorTrackSliderView
public typealias CapCutStepperBox = InspectorStepperBox
public typealias CapCutSliderRow = InspectorSliderRow
