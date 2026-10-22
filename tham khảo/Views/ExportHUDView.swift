import AppKit
import AVFoundation

/// Bảng HUD Xuất Video kết hợp chọn chất lượng đầu ra và hiển thị tiến trình thời gian thực
public final class ExportHUDView: NSView {

    public enum Mode {
        case settings(selectedPreset: Int)
        case exporting(filename: String, presetName: String)
        case completed(filename: String)
        case failed(message: String)
    }

    // MARK: - Callbacks
    public var onStartExport: ((Int) -> Void)?
    public var onCancelExport: (() -> Void)?
    public var onDismiss: (() -> Void)?

    // MARK: - UI Components
    private let cardView = NSView()
    private let headerIconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Xuất Video")
    private let subtitleLabel = NSTextField(labelWithString: "Chọn độ phân giải và chất lượng đầu ra")

    // Settings Mode Views
    private let settingsContainer = NSView()
    private let qualityControl = NSSegmentedControl()
    private let qualityNoteLabel = NSTextField(labelWithString: "")
    private let settingsButtonsStack = NSStackView()
    private let cancelButton = ProToolButton()
    private let confirmExportButton = ProToolButton()

    // Exporting Mode Views
    private let progressContainer = NSView()
    private let progressIndicator = NSProgressIndicator()
    private let percentLabel = NSTextField(labelWithString: "0%")
    private let progressButtonsStack = NSStackView()
    private let cancelExportButton = ProToolButton()

    // Completed / Failed Mode Views
    private let resultContainer = NSView()
    private let resultStatusLabel = NSTextField(labelWithString: "")
    private let resultDoneButton = ProToolButton()

    // MARK: - State
    public private(set) var currentMode: Mode = .settings(selectedPreset: 0)
    public var selectedPreset: Int {
        get { qualityControl.selectedSegment }
        set {
            let clamped = max(0, min(2, newValue))
            qualityControl.selectedSegment = clamped
            updateQualityNote(clamped)
        }
    }

    private let presetTitles = ["Cao nhất (Gốc)", "1080p Full HD", "720p HD"]
    private let presetNotes = [
        "Chất lượng tốt nhất, bảo toàn nguyên vẹn độ phân giải và chi tiết của video nguồn.",
        "Độ phân giải 1920 × 1080 Full HD chuẩn, cân bằng tuyệt vời giữa dung lượng và độ nét.",
        "Độ phân giải 1280 × 720 HD, kích thước tệp nhẹ, thời gian xuất nhanh."
    ]

    // MARK: - Init
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup UI
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.60).cgColor
        autoresizingMask = [.width, .height]

        // 1. Center Card
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = DS.Radius.xl + 4 // 14-16px
        cardView.layer?.backgroundColor = DS.Color.panelBg.cgColor
        cardView.layer?.borderColor = DS.Color.border.cgColor
        cardView.layer?.borderWidth = 1.0
        cardView.translatesAutoresizingMaskIntoConstraints = false

        // Drop shadow for card
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.shadowBlurRadius = 24
        cardView.shadow = shadow

        addSubview(cardView)

        // 2. Header Section
        headerIconView.translatesAutoresizingMaskIntoConstraints = false
        headerIconView.imageScaling = .scaleProportionallyUpOrDown
        headerIconView.setContentHuggingPriority(.required, for: .horizontal)
        headerIconView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DS.Font.header(16, weight: .bold)
        titleLabel.textColor = DS.Color.textPrimary

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = DS.Font.body(12)
        subtitleLabel.textColor = DS.Color.textSecondary
        subtitleLabel.lineBreakMode = .byTruncatingMiddle

        cardView.addSubview(headerIconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)

        // 3. Settings Container
        settingsContainer.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(settingsContainer)

        qualityControl.segmentCount = 3
        for (i, title) in presetTitles.enumerated() {
            qualityControl.setLabel(title, forSegment: i)
        }
        qualityControl.trackingMode = .selectOne
        qualityControl.selectedSegment = 0
        qualityControl.target = self
        qualityControl.action = #selector(qualityChanged(_:))
        qualityControl.translatesAutoresizingMaskIntoConstraints = false
        qualityControl.font = DS.Font.button(12, weight: .medium)

        qualityNoteLabel.translatesAutoresizingMaskIntoConstraints = false
        qualityNoteLabel.font = DS.Font.caption(11, weight: .regular)
        qualityNoteLabel.textColor = DS.Color.textMuted
        qualityNoteLabel.maximumNumberOfLines = 2
        qualityNoteLabel.lineBreakMode = .byWordWrapping
        updateQualityNote(0)

        cancelButton.configure(title: "Hủy", fontSize: 12, style: .secondary)
        cancelButton.target = self
        cancelButton.action = #selector(handleCancelClick)

        confirmExportButton.configure(title: "Xuất video…", symbolName: "square.and.arrow.up", fontSize: 12, style: .primary)
        confirmExportButton.target = self
        confirmExportButton.action = #selector(handleConfirmExportClick)

        settingsButtonsStack.orientation = .horizontal
        settingsButtonsStack.distribution = .fillEqually
        settingsButtonsStack.spacing = DS.Spacing.md
        settingsButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsButtonsStack.addArrangedSubview(cancelButton)
        settingsButtonsStack.addArrangedSubview(confirmExportButton)

        settingsContainer.addSubview(qualityControl)
        settingsContainer.addSubview(qualityNoteLabel)
        settingsContainer.addSubview(settingsButtonsStack)

        // 4. Progress Container
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.isHidden = true
        cardView.addSubview(progressContainer)

        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0.0
        progressIndicator.maxValue = 100.0
        progressIndicator.doubleValue = 0.0
        progressIndicator.controlSize = .regular
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.font = DS.Font.mono(22, weight: .bold)
        percentLabel.textColor = DS.Color.accent
        percentLabel.alignment = .center

        cancelExportButton.configure(title: "Hủy xuất", symbolName: "xmark.circle", fontSize: 12, style: .danger)
        cancelExportButton.target = self
        cancelExportButton.action = #selector(handleCancelExportClick)

        progressButtonsStack.orientation = .horizontal
        progressButtonsStack.alignment = .centerY
        progressButtonsStack.distribution = .fill
        progressButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        progressButtonsStack.addArrangedSubview(cancelExportButton)

        progressContainer.addSubview(percentLabel)
        progressContainer.addSubview(progressIndicator)
        progressContainer.addSubview(progressButtonsStack)

        // 5. Result Container (Completed / Failed)
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.isHidden = true
        cardView.addSubview(resultContainer)

        resultStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        resultStatusLabel.font = DS.Font.title(13)
        resultStatusLabel.textColor = DS.Color.textPrimary
        resultStatusLabel.alignment = .center
        resultStatusLabel.lineBreakMode = .byTruncatingMiddle

        resultDoneButton.configure(title: "Đóng", fontSize: 12, style: .primary)
        resultDoneButton.target = self
        resultDoneButton.action = #selector(handleDoneClick)
        resultDoneButton.translatesAutoresizingMaskIntoConstraints = false

        resultContainer.addSubview(resultStatusLabel)
        resultContainer.addSubview(resultDoneButton)

        // Setup Layout Constraints
        setupConstraints()
        updateHeaderVisuals()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Card constraints
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 440),
            cardView.heightAnchor.constraint(equalToConstant: 240),

            // Header Icon
            headerIconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DS.Spacing.xl),
            headerIconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DS.Spacing.xl),
            headerIconView.widthAnchor.constraint(equalToConstant: 28),
            headerIconView.heightAnchor.constraint(equalToConstant: 28),

            // Title & Subtitle
            titleLabel.leadingAnchor.constraint(equalTo: headerIconView.trailingAnchor, constant: DS.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DS.Spacing.xl),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: DS.Spacing.xl - 2),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DS.Spacing.xxs),

            // Settings Container Layout
            settingsContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DS.Spacing.xl),
            settingsContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DS.Spacing.xl),
            settingsContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DS.Spacing.lg),
            settingsContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DS.Spacing.lg),

            qualityControl.topAnchor.constraint(equalTo: settingsContainer.topAnchor),
            qualityControl.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            qualityControl.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),
            qualityControl.heightAnchor.constraint(equalToConstant: 30),

            qualityNoteLabel.topAnchor.constraint(equalTo: qualityControl.bottomAnchor, constant: DS.Spacing.sm),
            qualityNoteLabel.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            qualityNoteLabel.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),

            settingsButtonsStack.bottomAnchor.constraint(equalTo: settingsContainer.bottomAnchor),
            settingsButtonsStack.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            settingsButtonsStack.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),
            settingsButtonsStack.heightAnchor.constraint(equalToConstant: 32),

            // Progress Container Layout
            progressContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DS.Spacing.xl),
            progressContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DS.Spacing.xl),
            progressContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DS.Spacing.lg),
            progressContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DS.Spacing.lg),

            percentLabel.topAnchor.constraint(equalTo: progressContainer.topAnchor, constant: 4),
            percentLabel.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),

            progressIndicator.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: DS.Spacing.md),
            progressIndicator.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),

            progressButtonsStack.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressButtonsStack.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            cancelExportButton.widthAnchor.constraint(equalToConstant: 130),
            cancelExportButton.heightAnchor.constraint(equalToConstant: 32),

            // Result Container Layout
            resultContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: DS.Spacing.xl),
            resultContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -DS.Spacing.xl),
            resultContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DS.Spacing.lg),
            resultContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -DS.Spacing.lg),

            resultStatusLabel.centerYAnchor.constraint(equalTo: resultContainer.centerYAnchor, constant: -16),
            resultStatusLabel.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor),
            resultStatusLabel.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor),

            resultDoneButton.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor),
            resultDoneButton.centerXAnchor.constraint(equalTo: resultContainer.centerXAnchor),
            resultDoneButton.widthAnchor.constraint(equalToConstant: 120),
            resultDoneButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    // MARK: - Actions & Mode Transition
    @objc private func qualityChanged(_ sender: NSSegmentedControl) {
        updateQualityNote(sender.selectedSegment)
    }

    private func updateQualityNote(_ segment: Int) {
        let index = max(0, min(presetNotes.count - 1, segment))
        qualityNoteLabel.stringValue = presetNotes[index]
    }

    @objc private func handleConfirmExportClick() {
        onStartExport?(selectedPreset)
    }

    @objc private func handleCancelClick() {
        dismiss()
    }

    @objc private func handleCancelExportClick() {
        onCancelExport?()
    }

    @objc private func handleDoneClick() {
        dismiss()
    }

    public func setMode(_ mode: Mode) {
        currentMode = mode
        switch mode {
        case .settings(let preset):
            selectedPreset = preset
            settingsContainer.isHidden = false
            progressContainer.isHidden = true
            resultContainer.isHidden = true
            titleLabel.stringValue = "Xuất Video"
            subtitleLabel.stringValue = "Chọn độ phân giải và chất lượng đầu ra"

        case .exporting(let filename, let presetName):
            settingsContainer.isHidden = true
            progressContainer.isHidden = false
            resultContainer.isHidden = true
            titleLabel.stringValue = "Đang xuất video…"
            subtitleLabel.stringValue = "\(filename) • \(presetName)"
            progressIndicator.doubleValue = 0.0
            percentLabel.stringValue = "0%"

        case .completed(let filename):
            settingsContainer.isHidden = true
            progressContainer.isHidden = true
            resultContainer.isHidden = false
            titleLabel.stringValue = "Xuất video hoàn tất!"
            subtitleLabel.stringValue = filename
            resultStatusLabel.stringValue = "Tệp đã được xuất thành công và lưu vào đĩa."

        case .failed(let message):
            settingsContainer.isHidden = true
            progressContainer.isHidden = true
            resultContainer.isHidden = false
            titleLabel.stringValue = "Xuất không thành công"
            subtitleLabel.stringValue = message
            resultStatusLabel.stringValue = "Đã xảy ra lỗi trong quá trình kết xuất video."
        }
        updateHeaderVisuals()
    }

    private func updateHeaderVisuals() {
        switch currentMode {
        case .settings:
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                headerIconView.image = NSImage(systemSymbolName: "square.and.arrow.up.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
                headerIconView.contentTintColor = DS.Color.accent
            }
            titleLabel.textColor = DS.Color.textPrimary

        case .exporting:
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                headerIconView.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
                headerIconView.contentTintColor = DS.Color.accent
            }
            titleLabel.textColor = DS.Color.textPrimary

        case .completed:
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                headerIconView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
                headerIconView.contentTintColor = DS.Color.success
            }
            titleLabel.textColor = DS.Color.success

        case .failed:
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                headerIconView.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
                headerIconView.contentTintColor = DS.Color.error
            }
            titleLabel.textColor = DS.Color.error
        }
    }

    public func updateProgress(_ progress: Double) {
        let percent = max(0.0, min(100.0, progress * 100.0))
        progressIndicator.doubleValue = percent
        percentLabel.stringValue = String(format: "%.0f%%", percent)
    }

    // MARK: - Show & Dismiss Animation
    public func show(in parentView: NSView, preset: Int = 0) {
        frame = parentView.bounds
        setMode(.settings(selectedPreset: preset))
        alphaValue = 0.0
        parentView.addSubview(self)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            self.animator().alphaValue = 1.0
        }
    }

    public func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 0.0
        }) {
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }

    // MARK: - Event Handling
    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        // Nếu ở chế độ settings và click ra ngoài card -> đóng HUD
        if case .settings = currentMode, !cardView.frame.contains(location) {
            dismiss()
            return
        }
        // Nuốt các event click khác để không xuyên qua các controls bên dưới
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            switch currentMode {
            case .settings:
                dismiss()
            case .exporting:
                handleCancelExportClick()
            case .completed, .failed:
                dismiss()
            }
            return
        }
        super.keyDown(with: event)
    }
}

/// Thanh tiến trình mini hiển thị trên biểu tượng ứng dụng ở Dock (macOS DockTile)
public final class DockProgressView: NSView {
    public var progress: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        NSApp.applicationIconImage?.draw(in: bounds)
        guard progress >= 0.0 && progress <= 1.0 else { return }

        let barHeight: CGFloat = 16
        let margin: CGFloat = 12
        let barRect = NSRect(x: margin, y: margin, width: bounds.width - (margin * 2), height: barHeight)

        // Nền thanh tiến trình
        let bgPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        // Viền thanh tiến trình
        NSColor.white.withAlphaComponent(0.25).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        // Phần tiến trình hoàn thành
        let fillWidth = max(barHeight, (barRect.width - 4) * CGFloat(progress))
        let fillRect = NSRect(x: barRect.minX + 2, y: barRect.minY + 2, width: min(barRect.width - 4, fillWidth), height: barHeight - 4)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: (barHeight - 4) / 2, yRadius: (barHeight - 4) / 2)
        NSColor(red: 0.20, green: 0.65, blue: 0.95, alpha: 1.0).setFill()
        fillPath.fill()
    }
}

