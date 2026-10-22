import AppKit

/// Nút bấm công cụ chuyên nghiệp cho giao diện DAW (AppKit native).
/// Tự động căn giữa toàn bộ khối (Icon + Nhãn văn bản) với khoảng cách đối xứng,
/// khắc phục triệt để lỗi icon bị ép sát mép trái của NSButton mặc định.
public class ProToolButton: NSButton {
    public enum Style {
        case primary
        case secondary
        case ghost
        case icon
        case danger
    }

    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var stackLeadingConstraint: NSLayoutConstraint?
    private var stackTrailingConstraint: NSLayoutConstraint?
    
    private var customBgColor: NSColor?
    private var customBorderColor: NSColor?
    private var customTextColor: NSColor?
    private var customIconTintColor: NSColor?
    
    private var baseSymbolName: String?
    private var baseIconSize: CGFloat = 12
    private var baseIconWeight: NSFont.Weight = .semibold
    private var visualStyle: Style = .secondary
    private var hovered = false
    private var pressed = false
    private var tracking: NSTrackingArea?
    
    public override var title: String {
        get { titleLabel.stringValue }
        set {
            titleLabel.stringValue = newValue
            super.title = ""
            updateLayoutMode()
            updateVisualState()
        }
    }
    
    public override var image: NSImage? {
        get { iconView.image }
        set {
            iconView.image = newValue
            baseSymbolName = nil
            updateLayoutMode()
            updateVisualState()
            super.image = nil
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        super.title = ""
        super.image = nil
        isBordered = false
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = DS.Radius.md
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.distribution = .fill
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DS.Font.button(12, weight: .semibold)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        addSubview(stack)
        
        let hCon = heightAnchor.constraint(equalToConstant: DS.Size.buttonHeight)
        hCon.priority = .required
        hCon.isActive = true
        self.heightConstraint = hCon
        
        let wCon = widthAnchor.constraint(equalToConstant: DS.Size.iconButtonSize)
        wCon.priority = .required
        self.widthConstraint = wCon
        
        let sLead = stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10)
        let sTrail = stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        sLead.priority = .defaultHigh
        sTrail.priority = .defaultHigh
        self.stackLeadingConstraint = sLead
        self.stackTrailingConstraint = sTrail
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: DS.Size.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: DS.Size.iconSize)
        ])
        
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        updateLayoutMode()
        updateVisualState()
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        // Ngăn chặn hoàn toàn NSButtonCell vẽ chữ "Button" mặc định
    }
    
    public func configure(
        title: String,
        symbolName: String? = nil,
        iconSize: CGFloat = 12,
        iconWeight: NSFont.Weight = .semibold,
        fontSize: CGFloat = 11,
        style: Style = .secondary,
        isEnabled: Bool = true
    ) {
        super.title = ""
        super.image = nil
        self.baseSymbolName = symbolName
        self.baseIconSize = iconSize
        self.baseIconWeight = iconWeight
        self.titleLabel.stringValue = title
        self.titleLabel.font = DS.Font.button(fontSize, weight: .semibold)
        self.visualStyle = style
        self.isEnabled = isEnabled
        
        refreshSymbol()
        updateLayoutMode()
        updateVisualState()
    }
    
    public func setTitleText(_ text: String) {
        title = text
    }
    
    public func setSymbolName(_ name: String?) {
        baseSymbolName = name
        refreshSymbol()
        updateLayoutMode()
        updateVisualState()
    }

    public func setStyle(_ style: Style) {
        visualStyle = style
        updateLayoutMode()
        updateVisualState()
    }
    
    public func setCustomTheme(bg: NSColor, border: NSColor, text: NSColor, iconTint: NSColor? = nil) {
        customBgColor = bg
        customBorderColor = border
        customTextColor = text
        customIconTintColor = iconTint
        updateVisualState()
    }
    
    public func clearCustomTheme() {
        customBgColor = nil
        customBorderColor = nil
        customTextColor = nil
        customIconTintColor = nil
        updateVisualState()
    }
    
    private func updateLayoutMode() {
        let hasText = !titleLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIcon = (baseSymbolName != nil && !baseSymbolName!.isEmpty) || (iconView.image != nil)
        
        titleLabel.isHidden = !hasText
        iconView.isHidden = !hasIcon
        
        let isIconOnly = (visualStyle == .icon) || (hasIcon && !hasText)
        if isIconOnly {
            stackLeadingConstraint?.isActive = false
            stackTrailingConstraint?.isActive = false
            widthConstraint?.constant = DS.Size.iconButtonSize
            widthConstraint?.isActive = true
        } else {
            widthConstraint?.isActive = false
            stackLeadingConstraint?.isActive = true
            stackTrailingConstraint?.isActive = true
        }
        invalidateIntrinsicContentSize()
    }
    
    private func refreshSymbol() {
        if let sym = baseSymbolName, !sym.isEmpty, let img = DS.symbol(sym, size: baseIconSize, weight: baseIconWeight) {
            iconView.image = img
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
    }
    
    public func updateVisualState() {
        alphaValue = isEnabled ? 1.0 : 0.45
        layer?.transform = pressed && isEnabled
            ? CATransform3DMakeScale(0.985, 0.965, 1.0)
            : CATransform3DIdentity
        if let bg = customBgColor, let border = customBorderColor, let text = customTextColor {
            layer?.backgroundColor = (hovered && isEnabled ? bg.blended(withFraction: 0.15, of: .white) ?? bg : bg).cgColor
            layer?.borderColor = (hovered && isEnabled ? border.blended(withFraction: 0.25, of: .white) ?? border : border).cgColor
            layer?.borderWidth = DS.Size.borderWidth
            titleLabel.textColor = text
            iconView.contentTintColor = customIconTintColor ?? text
        } else {
            let background: NSColor
            let border: NSColor
            let foreground: NSColor
            switch visualStyle {
            case .primary:
                background = pressed && isEnabled ? DS.Color.accentPressed : (hovered && isEnabled ? DS.Color.accentHover : DS.Color.accent)
                border = DS.Color.accentHover
                foreground = .white
            case .secondary:
                background = pressed && isEnabled ? DS.Color.accentMuted : (hovered && isEnabled ? DS.Color.elevatedBg : DS.Color.surfaceBg)
                border = pressed && isEnabled ? DS.Color.accent : (hovered && isEnabled ? DS.Color.accent.withAlphaComponent(0.55) : DS.Color.border)
                foreground = DS.Color.textPrimary
            case .ghost:
                background = pressed && isEnabled ? DS.Color.elevatedBg : (hovered && isEnabled ? DS.Color.surfaceBg : .clear)
                border = .clear
                foreground = hovered && isEnabled ? DS.Color.textPrimary : DS.Color.textSecondary
            case .icon:
                background = pressed && isEnabled ? DS.Color.hoverBg : (hovered && isEnabled ? DS.Color.elevatedBg : DS.Color.surfaceBg)
                border = hovered && isEnabled ? DS.Color.accent.withAlphaComponent(0.55) : DS.Color.borderSubtle
                foreground = DS.Color.textPrimary
            case .danger:
                background = pressed && isEnabled ? DS.Color.error.withAlphaComponent(0.25) : (hovered && isEnabled ? DS.Color.errorMuted : DS.Color.surfaceBg)
                border = hovered && isEnabled ? DS.Color.error : DS.Color.border
                foreground = hovered && isEnabled ? DS.Color.error : DS.Color.textPrimary
            }
            layer?.backgroundColor = background.cgColor
            layer?.borderColor = border.cgColor
            layer?.borderWidth = visualStyle == .ghost ? 0 : DS.Size.borderWidth
            titleLabel.textColor = foreground
            iconView.contentTintColor = foreground
        }
    }
    
    public override var isEnabled: Bool {
        didSet { updateVisualState() }
    }
    
    public override func highlight(_ flag: Bool) {
        super.highlight(flag)
        pressed = flag
        updateVisualState()
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        pressed = true
        updateVisualState()
        displayIfNeeded()
        super.mouseDown(with: event)
        pressed = false
        updateVisualState()
    }

    public override var intrinsicContentSize: NSSize {
        let hasText = !titleLabel.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isIconOnly = (visualStyle == .icon) || !hasText
        if isIconOnly {
            return NSSize(width: DS.Size.iconButtonSize, height: DS.Size.buttonHeight)
        }
        let stackFit = stack.fittingSize
        let padding: CGFloat = 20
        return NSSize(width: max(DS.Size.iconButtonSize, ceil(stackFit.width + padding)), height: DS.Size.buttonHeight)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking = tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    public override func mouseEntered(with event: NSEvent) { hovered = true; updateVisualState() }
    public override func mouseExited(with event: NSEvent) { hovered = false; pressed = false; updateVisualState() }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden, super.hitTest(point) != nil else { return nil }
        return self
    }
}
