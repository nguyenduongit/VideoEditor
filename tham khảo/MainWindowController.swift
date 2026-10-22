import AppKit
import AVFoundation

final class MainWindowController: NSWindowController, NSWindowDelegate {
    let editor = EditorViewController()
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Video Auto Editor"; window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 1100, height: 650); window.contentViewController = editor; window.delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }
    func maximizeWindow() { if let frame = (window?.screen ?? NSScreen.main)?.visibleFrame { window?.setFrame(frame, display: true) } }
    @objc func openFileMenuAction(_ sender: Any?) { editor.openVideo() }
    @objc func saveSessionAction(_ sender: Any?) { editor.saveSession() }
    @objc func openSessionAction(_ sender: Any?) { editor.openSession() }
    @objc func newSessionAction(_ sender: Any?) { editor.newSession() }
    @objc func zoomToFitAction(_ sender: Any?) { editor.resetTimelineZoom() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { editor.confirmDiscard() }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { editor.history }
}

private final class EditorTopClipView: NSClipView {
    override var isFlipped: Bool { true }
}

private final class EditorRootView: NSView {
    var onLayout: (() -> Void)?
    override func layout() { super.layout(); onLayout?() }
}

final class EditorViewController: NSViewController, NSTextFieldDelegate, NSMenuItemValidation {
    private struct CropPanContext {
        let startX: Double
        let startY: Double
        let xPerPoint: Double
        let yPerPoint: Double
    }
    var session = EditorSession()
    let history = UndoManager()
    override var undoManager: UndoManager? { history }
    var savedSession = EditorSession()
    var lastExport: EditorSession?
    var sessionURL: URL?
    let navigationState = InspectorNavigationState()
    var group: Int {
        get { navigationState.mainTab.rawValue }
        set { navigationState.mainTab = InspectorMainTab(rawValue: newValue) ?? .video }
    }
    let groups = InspectorMainTab.allCases.map(\.title)
    let selector = HeaderTabBarControl()
    let subtabSelector = NSSegmentedControl()
    let poseProgress = NSProgressIndicator()
    var selectedHSLChannel: Int = 1
    var bypassVideoComposition: AVVideoComposition?

    let top = NSStackView()
    let sidebarTop = NSStackView()
    let importButtons = NSStackView()
    let syncButton = ProToolButton()
    let exportButton = ProToolButton()
    let playerView = EditorPlayerView()
    let placeholder = NSTextField(labelWithString: "Thêm video để bắt đầu")
    let sidebarScroll = NSScrollView()
    let properties = NSStackView()
    let timelineToolbar = NSStackView()
    let beatTools = NSStackView()
    let blockLengthControls = NSStackView()
    let blockLengthLabel = NSTextField(labelWithString: "Số phách")
    let blockLengthField = NSTextField(string: "8")
    let scroll = NSScrollView()
    let timeline = EditorTimelineView()
    let playButton = ProToolButton()
    let markAudioButton = ProToolButton()
    let markVideoButton = ProToolButton()
    let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    let statusLabel = NSTextField(wrappingLabelWithString: "Sẵn sàng")
    var actions: [String: (NSControl) -> Void] = [:]
    var busy = false
    var renderPending = false
    var renderGeneration = 0
    var waveformGeneration = 0
    var render: EditorRender?
    var cachedPoseResult: BodyProportionResult?
    var player = AVPlayer()
    var observer: Any?
    private var keyboard: Any?
    private var statusObserver: NSKeyValueObservation?
    private var zoom = 1.0
    let worker = DispatchQueue(label: "editor.media", qos: .userInitiated)
    let poseWorker = DispatchQueue(label: "editor.pose", qos: .utility)
    let colorWorker = DispatchQueue(label: "editor.color", qos: .userInitiated)
    private var exportHUD: ExportHUDView?
    private var dockProgressView: DockProgressView?
    var poseAnalysisPending = false
    var poseAnalysisUserInitiated = false
    var poseAnalysisGeneration = 0
    var poseAnalysisError: String?
    var colorAnalysisPending = false
    var colorAnalysisGeneration = 0
    var logMessages: [String] = []
    var lastText = ""
    // renderStale = true khi build thất bại mà session đã thay đổi — chặn export cho đến khi rebuild thành công.
    var renderStale = false
    // sessionRevision tăng khi mọi thay đổi xảy ra; debounce timer commit build khi revision khớp.
    var sessionRevision = 0
    private var debounceTimer: Timer?
    private var cropPanContext: CropPanContext?
    private var cropPanUndoGroupOpen = false
    weak var cropPanXSlider: InspectorSliderRow?
    weak var cropPanYSlider: InspectorSliderRow?
    weak var aspectRatioRow: InspectorAspectRatioRow?

    override func loadView() {
        let root = EditorRootView(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))
        root.wantsLayer = true; root.layer?.backgroundColor = DS.Color.appBg.cgColor
        root.onLayout = { [weak self] in self?.layoutEditor() }; view = root
        setup()
    }

    deinit {
        if let observer = observer { player.removeTimeObserver(observer) }
        if let keyboard = keyboard { NSEvent.removeMonitor(keyboard) }
        // Cửa sổ không thể đóng khi `busy`; export được hủy qua luồng UI trước khi controller bị giải phóng.
    }

    private func setup() {
        selector.segmentCount = groups.count; selector.trackingMode = .selectOne
        for (i, name) in groups.enumerated() { selector.setLabel(name, forSegment: i) }
        selector.selectedSegment = 0; selector.target = self; selector.action = #selector(groupChanged)
        subtabSelector.segmentStyle = .roundRect
        subtabSelector.font = .systemFont(ofSize: 11, weight: .semibold)
        subtabSelector.segmentDistribution = .fillEqually
        subtabSelector.target = self
        subtabSelector.action = #selector(subtabChanged)
        top.orientation = .horizontal; top.spacing = 4; top.alignment = .centerY
        top.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        top.applyToolbarStyle()
        sidebarTop.orientation = .horizontal; sidebarTop.spacing = 0; sidebarTop.alignment = .top
        sidebarTop.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        sidebarTop.applyToolbarStyle()
        sidebarTop.layer?.masksToBounds = true
        selector.translatesAutoresizingMaskIntoConstraints = false
        sidebarTop.addArrangedSubview(selector)
        NSLayoutConstraint.activate([
            selector.leadingAnchor.constraint(equalTo: sidebarTop.leadingAnchor),
            selector.trailingAnchor.constraint(equalTo: sidebarTop.trailingAnchor),
            selector.topAnchor.constraint(equalTo: sidebarTop.topAnchor),
            selector.bottomAnchor.constraint(equalTo: sidebarTop.bottomAnchor)
        ])
        top.addArrangedSubview(button("Mới", iconName: "doc.badge.plus", style: .ghost) { [weak self] _ in self?.newSession() })
        top.addArrangedSubview(button("Mở", iconName: "folder", style: .ghost) { [weak self] _ in self?.openSession() })
        importButtons.orientation = .horizontal; importButtons.spacing = 6
        importButtons.addArrangedSubview(button("Import…", iconName: "square.and.arrow.down", style: .secondary) { [weak self] _ in self?.importMedia() })
        top.addArrangedSubview(importButtons)
        top.addArrangedSubview(button("Lưu", iconName: "square.and.arrow.down.on.square", style: .ghost) { [weak self] _ in self?.saveSession() })
        top.addArrangedSubview(button("Nhật ký", iconName: "list.bullet.rectangle", style: .ghost) { [weak self] _ in self?.showLog() })
        let toolbarSpacer = NSView()
        toolbarSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        toolbarSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        top.addArrangedSubview(toolbarSpacer)
        exportButton.configure(title: "Xuất ▾", symbolName: "square.and.arrow.up", fontSize: 12, style: .primary)
        exportButton.target = self; exportButton.action = #selector(showExportOptions(_:))
        top.addArrangedSubview(exportButton)
        poseProgress.style = .bar; poseProgress.controlSize = .small; poseProgress.isIndeterminate = true; poseProgress.isHidden = true
        view.addSubview(top); view.addSubview(playerView); view.addSubview(sidebarTop); view.addSubview(subtabSelector); view.addSubview(poseProgress); view.addSubview(sidebarScroll); view.addSubview(timelineToolbar); view.addSubview(scroll)
        playerView.addSubview(placeholder); placeholder.textColor = .secondaryLabelColor; placeholder.alignment = .center
        properties.orientation = .vertical; properties.alignment = .leading; properties.spacing = 14; properties.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        properties.translatesAutoresizingMaskIntoConstraints = false
        sidebarScroll.contentView = EditorTopClipView(); sidebarScroll.documentView = properties; sidebarScroll.hasVerticalScroller = true
        sidebarScroll.drawsBackground = true; sidebarScroll.backgroundColor = DS.Color.panelBg
        NSLayoutConstraint.activate([properties.widthAnchor.constraint(equalTo: sidebarScroll.contentView.widthAnchor)])
        timelineToolbar.orientation = .horizontal; timelineToolbar.spacing = 6; timelineToolbar.alignment = .centerY
        timelineToolbar.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        timelineToolbar.applyToolbarStyle()
        syncButton.configure(title: "Đồng bộ", symbolName: "arrow.triangle.2.circlepath", fontSize: 12, style: .secondary)
        syncButton.target = self; syncButton.action = #selector(syncFromToolbar)
        timelineToolbar.addArrangedSubview(syncButton)
        playButton.configure(title: "", symbolName: "play.fill", iconSize: 12, fontSize: 12, style: .primary)
        playButton.target = self; playButton.action = #selector(playPause)
        timelineToolbar.addArrangedSubview(playButton)
        timelineToolbar.addArrangedSubview(button("", iconName: "backward.end.fill", style: .icon) { [weak self] _ in self?.seek(0) })
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = DS.Color.textSecondary
        timeLabel.alignment = .center
        timelineToolbar.addArrangedSubview(timeLabel)
        timelineToolbar.addArrangedSubview(button("", iconName: "minus", style: .icon) { [weak self] _ in self?.zoomTimeline(by: 1.0 / 1.5) })
        timelineToolbar.addArrangedSubview(button("", iconName: "plus", style: .icon) { [weak self] _ in self?.zoomTimeline(by: 1.5) })
        beatTools.orientation = .horizontal; beatTools.spacing = 6; beatTools.alignment = .centerY
        let countBlock = CountBlockDragButton(title: "Voice Count", target: nil, action: nil)
        countBlock.applyProfessionalStyle()
        countBlock.onDrag = { [weak self] event in self?.timeline.beginTemplateDrag(kind: nil, beatCount: 32, event: event) }
        beatTools.addArrangedSubview(countBlock)
        for (title, kind, beats) in [
            ("Fade In", EditorFadeKind.fadeIn, 4),
            ("Fade Out/In · 8", EditorFadeKind.fadeOutIn, 8),
            ("Fade Out", EditorFadeKind.fadeOut, 4)
        ] {
            let fade = FadeDragButton(title: title, target: nil, action: nil)
            fade.applyProfessionalStyle()
            fade.onDrag = { [weak self] event in self?.timeline.beginTemplateDrag(kind: kind, beatCount: beats, event: event) }
            beatTools.addArrangedSubview(fade)
        }

        blockLengthControls.orientation = .horizontal; blockLengthControls.spacing = 4; blockLengthControls.alignment = .centerY
        blockLengthLabel.font = DS.Font.label(11)
        blockLengthLabel.textColor = DS.Color.textSecondary
        blockLengthControls.addArrangedSubview(blockLengthLabel)
        blockLengthControls.addArrangedSubview(button("−", iconName: "minus", style: .icon) { [weak self] _ in self?.adjustSelectedBlockLength(by: -1) })
        blockLengthField.alignment = .center
        blockLengthField.font = DS.Font.mono(11, weight: .semibold)
        blockLengthField.widthAnchor.constraint(equalToConstant: 42).isActive = true
        blockLengthField.heightAnchor.constraint(equalToConstant: DS.Size.buttonHeight).isActive = true
        blockLengthField.wantsLayer = true
        blockLengthField.layer?.cornerRadius = DS.Radius.sm
        blockLengthField.layer?.borderWidth = DS.Size.thinBorder
        blockLengthField.layer?.borderColor = DS.Color.borderSubtle.cgColor
        blockLengthField.backgroundColor = DS.Color.surfaceBg
        blockLengthField.textColor = DS.Color.textPrimary
        blockLengthField.target = self; blockLengthField.action = #selector(commitBlockLength(_:)); blockLengthField.delegate = self
        blockLengthControls.addArrangedSubview(blockLengthField)
        blockLengthControls.addArrangedSubview(button("+", iconName: "plus", style: .icon) { [weak self] _ in self?.adjustSelectedBlockLength(by: 1) })
        blockLengthControls.addArrangedSubview(button("", iconName: "trash", style: .danger) { [weak self] _ in self?.deleteSelection() })
        beatTools.addArrangedSubview(blockLengthControls)
        timelineToolbar.addArrangedSubview(beatTools)
        let timelineToolbarSpacer = NSView()
        timelineToolbarSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        timelineToolbarSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        timelineToolbar.addArrangedSubview(timelineToolbarSpacer)
        let trimTools = NSStackView()
        trimTools.orientation = .horizontal; trimTools.spacing = 6; trimTools.alignment = .centerY
        markAudioButton.configure(title: "Cắt Audio", symbolName: "speaker.slash.fill", fontSize: 11, style: .secondary)
        markAudioButton.toolTip = "Cắt Audio tại kim đỏ (Click lại hoặc ⌥-Click để bỏ cắt) [⌥A]"
        markAudioButton.target = self; markAudioButton.action = #selector(markAudioEnd)
        trimTools.addArrangedSubview(markAudioButton)
        markVideoButton.configure(title: "Cắt Video", symbolName: "scissors", fontSize: 11, style: .secondary)
        markVideoButton.toolTip = "Cắt Video tại kim đỏ (Click lại hoặc ⌥-Click để bỏ cắt) [⌥V]"
        markVideoButton.target = self; markVideoButton.action = #selector(markVideoEnd)
        trimTools.addArrangedSubview(markVideoButton)
        timelineToolbar.addArrangedSubview(trimTools)
        scroll.documentView = timeline; scroll.hasHorizontalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        timeline.onSeek = { [weak self] in self?.seek($0) }
        timeline.onSelection = { [weak self] _, _ in self?.refresh() }
        timeline.onVideoEffectSelection = { [weak self] id in
            guard let self else { return }
            self.timeline.selectedVideoEffect = id
            if id != nil {
                self.navigationState.mainTab = .video
                self.navigationState.setSubTab(2, for: .video)
                self.selector.selectedSegment = InspectorMainTab.video.rawValue
            }
            self.refresh()
        }
        timeline.onBlockChange = { [weak self] block in self?.change("Chỉnh block") { s in if let i = s.blocks.firstIndex(where: { $0.id == block.id }) { s.blocks[i] = block; s.normalizeFades() } } }
        timeline.onBlockDrop = { [weak self] beat in self?.addBlock(at: beat) }
        timeline.onFadeChange = { [weak self] fade in
            self?.change("Chỉnh \(fade.resolvedKind.title)") { session in
                if let index = session.fades.firstIndex(where: { $0.id == fade.id }) {
                    session.fades[index] = fade
                    session.normalizeFades()
                }
            }
        }
        timeline.onFadeDrop = { [weak self] beat, kind, count in self?.addFade(at: beat, kind: kind, beatCount: count) }
        timeline.onVideoEffectChange = { [weak self] effect in
            self?.change("Chỉnh \(effect.kind.title)", live: true) { session in
                if let index = session.videoEffects.firstIndex(where: { $0.id == effect.id }) {
                    session.videoEffects[index] = effect
                    session.normalizeVideoEffects()
                }
            }
        }
        timeline.onVideoEffectDrop = { [weak self] start, kind, duration in self?.addVideoEffect(start: start, kind: kind, duration: duration) }
        timeline.onDelete = { [weak self] in self?.deleteSelection() }
        timeline.onZoomWheel = { [weak self] delta, mousePoint, isPrecise in
            self?.handleTimelineZoom(delta: delta, mousePoint: mousePoint, isPrecise: isPrecise)
        }
        playerView.playerLayer.player = player
        playerView.onCropPanBegan = { [weak self] in self?.beginPreviewCropPan() }
        playerView.onCropPanChanged = { [weak self] delta in self?.movePreviewCrop(by: delta) }
        playerView.onCropPanEnded = { [weak self] in self?.endPreviewCropPan() }
        setupPlaybackObserver()
        timeline.onResetZoom = { [weak self] in self?.resetTimelineZoom() }
        keyboard = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, event.window == self.view.window,
                  !(self.view.window?.firstResponder is NSTextView) else { return event }
            
            // Spacebar: Play / Pause
            if event.keyCode == 49 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                self.playPause()
                return nil
            }
            
            // Shift + Z: Reset zoom to 1 viewport (no zoom, reset horizontal scroll)
            if (event.keyCode == 6 || event.charactersIgnoringModifiers?.lowercased() == "z") &&
               event.modifierFlags.intersection([.command, .option, .control, .shift]) == .shift {
                self.resetTimelineZoom()
                return nil
            }
            
            // Option + A: Cắt Audio tại kim đỏ
            if (event.keyCode == 0 || event.charactersIgnoringModifiers?.lowercased() == "a") &&
               event.modifierFlags.intersection([.command, .option, .control, .shift]) == .option {
                self.markAudioEnd()
                return nil
            }
            
            // Option + V: Cắt Video tại kim đỏ
            if (event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v") &&
               event.modifierFlags.intersection([.command, .option, .control, .shift]) == .option {
                self.markVideoEnd()
                return nil
            }
            
            return event
        }
        refresh()
    }

    private func sourceVideoSize() -> CGSize? {
        if let pose = session.pose, pose.width > 0, pose.height > 0 {
            return CGSize(width: pose.width, height: pose.height)
        }
        guard let source = session.video,
              let track = AVURLAsset(url: URL(fileURLWithPath: source.path)).tracks(withMediaType: .video).first else { return nil }
        let oriented = track.naturalSize.applying(track.preferredTransform)
        let size = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        return size.width > 0 && size.height > 0 ? size : nil
    }

    private func currentEffectiveResolution() -> (width: Int, height: Int)? {
        guard let videoSize = sourceVideoSize(), videoSize.width > 0, videoSize.height > 0 else {
            return nil
        }
        let originalRatio = videoSize.width / videoSize.height
        let targetRatio: CGFloat
        switch session.cropMode {
        case 1: targetRatio = 9.0 / 16.0
        case 2: targetRatio = 16.0 / 9.0
        case 3: targetRatio = 1.0
        case 4: targetRatio = 4.0 / 5.0
        default: targetRatio = originalRatio
        }

        var maxCropWidth: CGFloat
        var maxCropHeight: CGFloat
        if targetRatio > originalRatio {
            maxCropWidth = videoSize.width
            maxCropHeight = maxCropWidth / targetRatio
        } else {
            maxCropHeight = videoSize.height
            maxCropWidth = maxCropHeight * targetRatio
        }

        let clampedZoom = CGFloat(max(1.0, min(3.0, session.cropZoom)))
        let cropWidth = max(32.0, maxCropWidth / clampedZoom)
        let cropHeight = max(32.0, maxCropHeight / clampedZoom)

        return (Int(round(cropWidth)), Int(round(cropHeight)))
    }

    func currentEffectiveResolutionString() -> String {
        if let res = currentEffectiveResolution() {
            return "(\(res.width) × \(res.height))"
        }
        let w: Double
        let h: Double
        switch session.cropMode {
        case 1: (w, h) = (1080, 1920)
        case 2: (w, h) = (1920, 1080)
        case 3: (w, h) = (1080, 1080)
        case 4: (w, h) = (1080, 1350)
        default: (w, h) = (1080, 1920)
        }
        let clampedZoom = max(1.0, min(3.0, session.cropZoom))
        return "(\(Int(round(w / clampedZoom))) × \(Int(round(h / clampedZoom))))"
    }

    private func beginPreviewCropPan() {
        guard !busy, !renderPending, navigationState.mainTab == .video,
              navigationState.currentSubTab(for: .video) == 0,
              let size = sourceVideoSize(),
              playerView.displayedVideoRect.width > 0,
              playerView.displayedVideoRect.height > 0 else { return }
        let result = cachedPoseResult ?? BodyProportionResult(
            videoName: "", initialRatio: 1.0, targetRatio: 1.0, scaleFactor: 1.0,
            hipYNorm: 0.5, ankleYNorm: 0.1, videoSize: size, trackingData: []
        )
        let sourceTime = (render?.map.sourceTime(at: player.currentTime().seconds) ?? 0) + session.videoStart
        let cropRect = VideoCropService.shared.calculateDynamicCropRect(
            for: EditorCompositionService.time(sourceTime), proportion: result,
            cropMode: session.cropMode, zoom: session.cropZoom,
            offsetY: session.cropOffsetY, autoPan: session.cropAutoPan, panX: session.cropPanX
        )
        let maxX = max(0, size.width - cropRect.width)
        let maxY = max(0, size.height - cropRect.height)
        let startX = maxX > 0 ? Double(cropRect.minX / maxX) : 0.5
        let startY = maxY > 0 ? Double(cropRect.minY / maxY) : 0.5
        let visible = playerView.displayedVideoRect
        cropPanContext = CropPanContext(
            startX: startX,
            startY: startY,
            xPerPoint: maxX > 0 ? Double(cropRect.width / (maxX * visible.width)) : 0,
            yPerPoint: maxY > 0 ? Double(cropRect.height / (maxY * visible.height)) : 0
        )
        history.beginUndoGrouping()
        cropPanUndoGroupOpen = true
        change("Di chuyển khung hình", live: true) {
            $0.cropAutoPan = false
            $0.cropPanX = startX
            $0.cropOffsetY = startY
        }
        cropPanXSlider?.isEnabled = true
        cropPanXSlider?.display(startX)
        cropPanYSlider?.display(startY)
    }

    private func movePreviewCrop(by delta: CGPoint) {
        guard let context = cropPanContext else { return }
        let x = max(0, min(1, context.startX - Double(delta.x) * context.xPerPoint))
        let y = max(0, min(1, context.startY - Double(delta.y) * context.yPerPoint))
        cropPanXSlider?.display(x)
        cropPanYSlider?.display(y)
        change("Di chuyển khung hình", live: true) {
            $0.cropAutoPan = false
            $0.cropPanX = x
            $0.cropOffsetY = y
        }
    }

    private func endPreviewCropPan() {
        cropPanContext = nil
        if cropPanUndoGroupOpen {
            history.endUndoGrouping()
            cropPanUndoGroupOpen = false
        }
        refresh()
    }

    private func layoutEditor() {
        let w = view.bounds.width, h = view.bounds.height
        let header = h * 0.05, middle = h * 0.70, bottom = h * 0.25
        let previewWidth = middle * 16 / 9
        let sidebarWidth = max(1, w - previewWidth)
        let subtabAreaHeight: CGFloat = 34
        top.frame = NSRect(x: 0, y: h - header, width: previewWidth, height: header)
        sidebarTop.frame = NSRect(x: previewWidth, y: h - header, width: sidebarWidth, height: header)
        playerView.frame = NSRect(x: 0, y: bottom, width: previewWidth, height: middle)
        placeholder.frame = NSRect(x: 20, y: middle / 2, width: previewWidth - 40, height: 24)
        subtabSelector.frame = NSRect(x: previewWidth + 12, y: bottom + middle - 28, width: max(1, sidebarWidth - 24), height: 22)
        poseProgress.frame = NSRect(x: previewWidth + 12, y: bottom + middle - subtabAreaHeight, width: max(1, sidebarWidth - 24), height: 2)
        sidebarScroll.frame = NSRect(x: previewWidth, y: bottom, width: sidebarWidth, height: max(1, middle - subtabAreaHeight))
        timelineToolbar.frame = NSRect(x: 0, y: bottom - 40, width: w, height: 40)
        scroll.frame = NSRect(x: 0, y: 0, width: w, height: max(1, bottom - 40))
        timeline.frame = NSRect(x: 0, y: 0, width: max(1, scroll.contentSize.width) * zoom, height: max(1, scroll.contentSize.height))
    }

    private func zoomTimeline(by factor: Double) {
        let centerPoint = NSPoint(x: scroll.contentView.bounds.midX, y: scroll.contentView.bounds.midY)
        handleTimelineZoom(delta: factor > 1 ? 1 : -1, mousePoint: centerPoint, isPrecise: false)
    }

    func resetTimelineZoom() {
        self.zoom = 1.0
        let w = max(1, scroll.contentSize.width)
        timeline.frame = NSRect(x: 0, y: 0, width: w, height: max(1, scroll.contentSize.height))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
        timeline.needsDisplay = true
    }

    private func handleTimelineZoom(delta: CGFloat, mousePoint: NSPoint, isPrecise: Bool) {
        guard view.window != nil else { return }
        let factor: Double
        if isPrecise {
            factor = pow(1.006, Double(delta))
        } else {
            factor = delta > 0 ? 1.2 : (delta < 0 ? 1.0 / 1.2 : 1.0)
        }
        let oldZoom = self.zoom
        let newZoom = max(1.0, min(64.0, oldZoom * factor))
        guard abs(newZoom - oldZoom) > 0.0001 else { return }
        
        let contentWidth = max(1, scroll.contentSize.width)
        let visibleRect = scroll.contentView.bounds
        let mouseXInDocument = mousePoint.x
        let mouseOffsetInViewport = mouseXInDocument - visibleRect.minX
        
        let timeUnderMouse = timeline.output(mouseXInDocument)
        
        self.zoom = newZoom
        let newDocWidth = contentWidth * newZoom
        timeline.frame = NSRect(x: 0, y: 0, width: newDocWidth, height: max(1, scroll.contentSize.height))
        
        let newMouseX = timeline.x(timeUnderMouse)
        var targetScrollX = newMouseX - mouseOffsetInViewport
        let maxScrollX = max(0, newDocWidth - visibleRect.width)
        targetScrollX = max(0, min(maxScrollX, targetScrollX))
        
        scroll.contentView.scroll(to: NSPoint(x: targetScrollX, y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
        timeline.needsDisplay = true
    }

    func button(_ title: String, iconName: String? = nil, style: ProToolButton.Style = .secondary, action: @escaping (NSControl) -> Void) -> ProToolButton {
        let b = ProToolButton(frame: .zero)
        b.configure(title: title, symbolName: iconName, iconSize: title.isEmpty ? 12 : 13, fontSize: 12, style: style)
        b.target = self; b.action = #selector(invoke(_:))
        let id = UUID().uuidString; b.identifier = NSUserInterfaceItemIdentifier(id); actions[id] = action
        return b
    }

    @objc func invoke(_ sender: NSControl) { if let id = sender.identifier?.rawValue { actions[id]?(sender) } }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            if field === blockLengthField { commitBlockLength(field) }
            else { invoke(field) }
        }
    }

    @objc func undo(_ sender: Any?) { if !busy { history.undo() } }
    @objc func redo(_ sender: Any?) { if !busy { history.redo() } }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(undo(_:)) { return !busy && history.canUndo }
        if menuItem.action == #selector(redo(_:)) { return !busy && history.canRedo }
        return true
    }

    @objc private func groupChanged() {
        navigationState.mainTab = InspectorMainTab(rawValue: selector.selectedSegment) ?? .video
        refresh()
    }

    @objc private func subtabChanged() {
        navigationState.setSubTab(subtabSelector.selectedSegment, for: navigationState.mainTab)
        playerView.cropPanningEnabled = navigationState.mainTab == .video && navigationState.currentSubTab(for: .video) == 0 && session.video != nil && !busy && !renderPending
        showProperties()
    }

    @objc private func syncFromToolbar() { synchronize() }

    @objc private func showExportOptions(_ sender: NSButton) {
        guard sender.isEnabled else { return }
        guard !busy, !renderPending, render != nil else {
            report("Đợi preview sẵn sàng trước khi xuất.")
            return
        }
        showExportHUD()
    }

    private func showExportHUD() {
        if let existing = exportHUD {
            existing.removeFromSuperview()
            exportHUD = nil
        }
        let hud = ExportHUDView()
        hud.onDismiss = { [weak self] in
            self?.exportHUD = nil
        }
        hud.onStartExport = { [weak self] selectedPreset in
            guard let self = self else { return }
            self.change("Chất lượng xuất") { $0.outputPreset = selectedPreset }
            self.beginExport(preset: selectedPreset)
        }
        hud.onCancelExport = { [weak self] in
            self?.cancelExport()
        }
        exportHUD = hud
        hud.show(in: view, preset: session.outputPreset)
    }

    func refresh() {
        cachedPoseResult = session.pose?.result()
        timeline.session = session; timeline.editing = session.video != nil; timeline.enabled = !busy
        beatTools.isHidden = false
        if let id = timeline.selectedBlock, let block = session.blocks.first(where: { $0.id == id }) {
            blockLengthLabel.stringValue = "Số phách"
            blockLengthField.stringValue = "\(block.beatCount)"
            blockLengthControls.isHidden = false
        } else if let id = timeline.selectedFade, let fade = session.fades.first(where: { $0.id == id }) {
            blockLengthLabel.stringValue = "Số phách"
            blockLengthField.stringValue = "\(fade.resolvedBeatCount)"
            blockLengthControls.isHidden = false
        } else if let id = timeline.selectedVideoEffect, let effect = session.videoEffects.first(where: { $0.id == id }) {
            blockLengthLabel.stringValue = "Thời gian (s)"
            blockLengthField.stringValue = String(format: "%.1f", effect.duration)
            blockLengthControls.isHidden = false
        } else {
            blockLengthControls.isHidden = true
        }
        placeholder.isHidden = session.video != nil
        let activeSubTab = navigationState.currentSubTab(for: navigationState.mainTab)
        playerView.cropPanningEnabled = navigationState.mainTab == .video && activeSubTab == 0 && session.video != nil && !busy && !renderPending
        let showPoseProgress = poseAnalysisPending && poseAnalysisUserInitiated
        poseProgress.isHidden = !showPoseProgress
        if showPoseProgress { poseProgress.startAnimation(nil) } else { poseProgress.stopAnimation(nil) }
        for (i, name) in groups.enumerated() {
            let modified: Bool
            switch i {
            case 0: modified = session.legsEnabled || session.cropEnabled || !session.videoEffects.isEmpty;
            case 1: modified = !session.adjustments.isNeutral;
            case 2: modified = session.textEnabled;
            case 3: modified = abs(session.targetBPM - session.baseBPM) > 0.001 || abs(session.musicVolume - 1.0) > 0.001 || session.audioTrimEnd != nil || session.videoTrimEnd != nil || abs(session.audioFadeOutDuration - 2.0) > 0.001;
            default: modified = false
            }
            selector.setLabel(name + (modified ? " •" : ""), forSegment: i)
        }
        let currentTab = navigationState.mainTab
        let currentSubTabs = currentTab.subTabs
        if subtabSelector.segmentCount != currentSubTabs.count {
            subtabSelector.segmentCount = currentSubTabs.count
        }
        for (idx, subTitle) in currentSubTabs.enumerated() {
            subtabSelector.setLabel(subTitle, forSegment: idx)
        }
        if subtabSelector.selectedSegment != activeSubTab {
            subtabSelector.selectedSegment = activeSubTab
        }
        syncButton.title = session.match == nil ? "Đồng bộ" : "Đồng bộ lại"
        syncButton.isEnabled = session.video != nil && session.audio != nil && !busy && !colorAnalysisPending && !renderPending
        exportButton.isEnabled = session.video != nil && !busy && !colorAnalysisPending && !renderPending && render != nil && !renderStale
        view.window?.isDocumentEdited = session != savedSession
        updateLegGuideOverlay(at: player.currentTime().seconds)
        showProperties(); layoutEditor()
        func enable(_ view: NSView, _ value: Bool) {
            if let c = view as? NSControl {
                if let tf = c as? NSTextField, !tf.isEditable {
                    // Không can thiệp nhãn văn bản chỉ đọc
                } else {
                    c.isEnabled = value
                }
            }
            view.subviews.forEach { enable($0, value) }
        }
        enable(importButtons, !busy && !colorAnalysisPending); enable(beatTools, !busy && session.video != nil)
        playButton.isEnabled = !busy && !renderPending && render != nil
        markAudioButton.isEnabled = !busy && session.video != nil
        markVideoButton.isEnabled = !busy && session.video != nil
    }

    func report(_ text: String) { lastText = text; logMessages.append(text); statusLabel.stringValue = text }

    func change(_ name: String, live: Bool = false, _ mutation: (inout EditorSession) -> Void) {
        guard !busy else { return }; var next = session; mutation(&next); next.normalizeVideoEffects()
        guard next != session else { return }; apply(next, name: name, live: live)
    }

    func changeFromBackground(_ name: String, _ mutation: (inout EditorSession) -> Void) {
        var next = session
        mutation(&next)
        next.normalizeVideoEffects()
        guard next != session else { return }
        apply(next, name: name, live: false)
    }

    func apply(_ next: EditorSession, name: String, live: Bool = false) {
        let old = session
        history.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.apply(old, name: name, live: false)
            }
        }
        history.setActionName(name)
        if old.fades != next.fades || old.fadeIn != next.fadeIn || old.fadeOut != next.fadeOut {
            let oldDuration = EditorTimeMap(old).duration
            let newDuration = EditorTimeMap(next).duration
            if oldDuration > 0, newDuration > 0 {
                let oldDrawableWidth = max(1, Double(timeline.bounds.width - 24))
                let baseWidth = max(1, Double(scroll.contentSize.width))
                let requiredWidth = 24 + oldDrawableWidth * newDuration / oldDuration
                zoom = max(1, min(64, requiredWidth / baseWidth))
            }
        }
        session = next
        // Tăng revision ngay lập tức để vô hiệu hoá callback render/debounce cũ trước khi bất kỳ async work nào xảy ra.
        sessionRevision += 1
        let revision = sessionRevision
        renderStale = true
        exportButton.isEnabled = false
        aspectRatioRow?.updateResolution(currentEffectiveResolutionString())
        aspectRatioRow?.updateSelection(next.cropMode)
        let structural = old.video != next.video || old.audio != next.audio || old.match != next.match ||
                         old.baseBPM != next.baseBPM || old.targetBPM != next.targetBPM ||
                         old.blocks != next.blocks || old.fades != next.fades || old.fadeIn != next.fadeIn || old.fadeOut != next.fadeOut ||
                         old.videoTrimEnd != next.videoTrimEnd || old.audioTrimEnd != next.audioTrimEnd
        if structural {
            if old.video != next.video || old.audio != next.audio || old.match != next.match {
                waveformGeneration += 1; timeline.peaks = []; analyzeWaveform(updateBeat: false)
            }
            refresh(); rebuild()
        } else {
            // Cập nhật timeline ngay lập tức để UI phản ánh session mới đồng bộ.
            timeline.session = next
            updateLegGuideOverlay(at: player.currentTime().seconds)
            // Debounce 80ms cho composition build: chỉ debounce việc dispatch, build chạy trên worker queue.
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: live ? 0.080 : 0.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.sessionRevision == revision else { return }
                    let snapshot = self.session
                    self.worker.async { [weak self] in
                        let result = Result { try EditorCompositionService.build(snapshot) }
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, self.sessionRevision == revision else { return }
                            switch result {
                            case .success(let newRender):
                                self.render = newRender
                                self.renderStale = false
                                self.bypassVideoComposition = nil
                                if let item = self.player.currentItem {
                                    item.videoComposition = newRender.videoComposition
                                    item.audioMix = newRender.audioMix
                                } else {
                                    let item = newRender.playerItem()
                                    self.player.replaceCurrentItem(with: item)
                                }
                            case .failure(let error):
                                self.renderStale = true
                                self.report(error.localizedDescription)
                            }
                            if !live {
                                self.refresh()
                            } else {
                                self.exportButton.isEnabled = self.session.video != nil && !self.busy && !self.colorAnalysisPending && !self.renderPending && self.render != nil && !self.renderStale
                                self.playButton.isEnabled = !self.busy && !self.renderPending && self.render != nil
                            }
                        }
                    }
                }
            }
            if !live { refresh() }
        }
    }

    func resetGroup() {
        let selected = navigationState.mainTab
        change("Đặt lại \(selected.title)") { s in
            switch selected {
            case .video:
                s.cropMode = 0; s.cropZoom = 1.0; s.cropOffsetY = 0.5; s.cropAutoPan = false; s.cropPanX = 0.5
                s.legScale = 1.0; s.showLegGuides = false
                s.videoEffects = []
            case .adjustment: s.adjustments = EditorAdjustments()
            case .text: s.textEnabled = false; s.title = ""
            case .audio:
                s.targetBPM = s.baseBPM; s.musicVolume = 1.0
                s.audioTrimEnd = nil; s.videoTrimEnd = nil; s.audioFadeOutDuration = 2.0
            }
        }
    }

    var previewReady: Bool { !renderPending && !renderStale && render != nil && player.currentItem?.status == .readyToPlay }

    func rebuild() {
        renderGeneration += 1; let generation = renderGeneration
        let revision = sessionRevision
        let snapshot = session
        let previousSource = render?.map.sourceTime(at: player.currentTime().seconds) ?? 0
        let wasPlaying = player.rate > 0; player.pause(); renderPending = true; refresh()
        guard session.video != nil else { renderPending = false; render = nil; player.replaceCurrentItem(with: nil); refresh(); return }
        worker.async { [weak self] in
            let result = Result { try EditorCompositionService.build(snapshot) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, generation == self.renderGeneration else { return }
                self.renderPending = false
                switch result {
                case .success(let render):
                    self.render = render
                    if revision == self.sessionRevision {
                        self.renderStale = false
                    }
                    self.bypassVideoComposition = nil
                    let item = render.playerItem()
                    self.player.replaceCurrentItem(with: item)
                    let target = render.map.outputTime(for: min(snapshot.duration, previousSource))
                    self.player.seek(to: EditorCompositionService.time(target), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] done in
                        DispatchQueue.main.async { [weak self] in
                            if done && wasPlaying && self?.renderGeneration == generation { self?.player.play() }
                        }
                    }
                    self.statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                        if item.status == .failed {
                            let msg = item.error?.localizedDescription ?? "Preview không phát được."
                            DispatchQueue.main.async { [weak self] in
                                self?.report(msg)
                            }
                        }
                    }
                case .failure(let error):
                    self.render = nil
                    self.renderStale = true
                    self.player.replaceCurrentItem(with: nil)
                    self.report(error.localizedDescription)
                }
                self.refresh()
            }
        }
    }

    @objc private func markAudioEnd() {
        guard session.video != nil else { return }
        let curTime = timeline.playhead
        let sourceTime = render?.map.sourceTime(at: curTime) ?? curTime
        let formatted = format(curTime)
        let isOption = NSEvent.modifierFlags.contains(.option)
        if isOption || (session.audioTrimEnd != nil && abs((session.audioTrimEnd ?? 0) - sourceTime) < 0.25) {
            change("Bỏ cắt Audio") { s in s.audioTrimEnd = nil }
            report("Đã bỏ cắt Audio. Nhạc sẽ phát toàn bộ.")
            return
        }
        change("Cắt Audio tại \(formatted)") { s in
            s.audioTrimEnd = max(0.5, min(s.rawAudioDuration, sourceTime))
        }
        report("Đã đánh dấu cắt Audio tại \(formatted). Nhạc sẽ fade out và tắt tại đây.")
    }

    @objc private func markVideoEnd() {
        guard session.video != nil else { return }
        let curTime = timeline.playhead
        let sourceTime = render?.map.sourceTime(at: curTime) ?? curTime
        let formatted = format(curTime)
        let isOption = NSEvent.modifierFlags.contains(.option)
        if isOption || (session.videoTrimEnd != nil && abs((session.videoTrimEnd ?? 0) - sourceTime) < 0.25) {
            change("Bỏ cắt Video") { s in s.videoTrimEnd = nil }
            report("Đã bỏ cắt Video. Video sẽ phát toàn bộ.")
            return
        }
        change("Cắt Video tại \(formatted)") { s in
            s.videoTrimEnd = max(0.5, min(s.rawVideoDuration, sourceTime))
        }
        if timeline.playhead > (render?.map.duration ?? 0) {
            seek(render?.map.duration ?? 0)
        }
        report("Đã đánh dấu cắt Video tại \(formatted). Toàn bộ video kết thúc tại đây.")
    }

    private func addBlock(at start: Int) {
        guard !busy else { return }
        let block = EditorBlock(startBeat: start, beatCount: 32)
        guard session.accepts(block) else { report("Không đủ chỗ cho block 8 nhịp (32 phách) tại vị trí này."); return }
        timeline.selectedBlock = block.id
        timeline.selectedFade = nil
        change("Thêm block") { $0.blocks.append(block) }
    }

    private func addFade(at start: Int, kind: EditorFadeKind, beatCount: Int) {
        guard !busy else { return }
        let fade = EditorFade(startBeat: start, beatCount: beatCount, kind: kind)
        guard session.accepts(fade) else { report("Không thể đặt \(kind.title) tại vị trí này."); return }
        timeline.selectedFade = fade.id
        timeline.selectedBlock = nil
        change("Thêm \(kind.title)") { session in
            session.fades.append(fade)
            session.normalizeFades()
        }
    }

    private func addVideoEffect(start: Double, kind: VideoEffectKind, duration: Double) {
        guard !busy else { return }
        let effect = VideoEffect(startTime: start, duration: max(0.1, (duration * 10).rounded() / 10), kind: kind)
        guard session.accepts(effect) else { report("Không thể đặt \(kind.title) tại vị trí này."); return }
        timeline.selectedVideoEffect = effect.id; timeline.selectedBlock = nil; timeline.selectedFade = nil
        change("Thêm \(kind.title)") { session in session.videoEffects.append(effect); session.normalizeVideoEffects() }
    }

    private func adjustSelectedBlockLength(by delta: Int) {
        if let id = timeline.selectedVideoEffect, let effect = session.videoEffects.first(where: { $0.id == id }) {
            setSelectedVideoEffectDuration(effect.duration + Double(delta) * 0.1)
            return
        }
        if let id = timeline.selectedBlock, let block = session.blocks.first(where: { $0.id == id }) {
            setSelectedBlockLength(block.beatCount + delta)
        } else if let id = timeline.selectedFade, let fade = session.fades.first(where: { $0.id == id }) {
            setSelectedBlockLength(fade.resolvedBeatCount + delta)
        }
    }

    @objc private func commitBlockLength(_ sender: NSTextField) {
        if let id = timeline.selectedVideoEffect, let effect = session.videoEffects.first(where: { $0.id == id }) {
            guard let value = Double(sender.stringValue.replacingOccurrences(of: ",", with: ".")) else {
                sender.stringValue = String(format: "%.1f", effect.duration); return
            }
            setSelectedVideoEffectDuration(value); return
        }
        guard let value = Int(sender.stringValue) else {
            if let id = timeline.selectedBlock, let block = session.blocks.first(where: { $0.id == id }) {
                sender.stringValue = "\(block.beatCount)"
            } else if let id = timeline.selectedFade, let fade = session.fades.first(where: { $0.id == id }) {
                sender.stringValue = "\(fade.resolvedBeatCount)"
            }
            return
        }
        setSelectedBlockLength(value)
    }

    private func setSelectedVideoEffectDuration(_ duration: Double) {
        guard let id = timeline.selectedVideoEffect, let effect = session.videoEffects.first(where: { $0.id == id }) else { return }
        var changed = effect
        let timelineEnd = EditorTimeMap(session).duration
        let requested = min(timelineEnd, max(0.1, (duration * 10).rounded() / 10))
        if abs(effect.endTime - timelineEnd) < 0.051 {
            changed.duration = requested
            changed.startTime = timelineEnd - requested
        } else {
            changed.duration = min(timelineEnd - effect.startTime, requested)
        }
        guard session.accepts(changed) else {
            blockLengthField.stringValue = String(format: "%.1f", effect.duration)
            report("Thời gian hiệu ứng vượt khỏi video."); return
        }
        blockLengthField.stringValue = String(format: "%.1f", changed.duration)
        change("Thời gian \(effect.kind.title)") { session in
            if let index = session.videoEffects.firstIndex(where: { $0.id == id }) { session.videoEffects[index] = changed; session.normalizeVideoEffects() }
        }
    }

    private func setSelectedBlockLength(_ count: Int) {
        let clamped = max(1, min(999, count))
        if let id = timeline.selectedBlock, let block = session.blocks.first(where: { $0.id == id }) {
            var changed = block
            changed.beatCount = clamped
            guard session.accepts(changed) else {
                blockLengthField.stringValue = "\(block.beatCount)"
                report("Block vượt phạm vi hoặc chồng lên block khác.")
                return
            }
            blockLengthField.stringValue = "\(clamped)"
            change("Số phách block") { session in
                if let index = session.blocks.firstIndex(where: { $0.id == id }) {
                    session.blocks[index] = changed
                    session.normalizeFades()
                }
            }
        } else if let id = timeline.selectedFade, let fade = session.fades.first(where: { $0.id == id }) {
            var changed = fade
            changed.beatCount = clamped
            guard session.accepts(changed) else {
                blockLengthField.stringValue = "\(fade.resolvedBeatCount)"
                report("Fade không hợp lệ tại vị trí này.")
                return
            }
            blockLengthField.stringValue = "\(clamped)"
            change("Số phách \(fade.resolvedKind.title)") { session in
                if let index = session.fades.firstIndex(where: { $0.id == id }) {
                    session.fades[index] = changed
                    session.normalizeFades()
                }
            }
        }
    }

    func deleteSelection() {
        if let id = timeline.selectedVideoEffect { change("Xóa hiệu ứng video") { $0.videoEffects.removeAll { $0.id == id } }; timeline.selectedVideoEffect = nil }
        else if let id = timeline.selectedFade { change("Xóa fade") { $0.fades.removeAll { $0.id == id } }; timeline.selectedFade = nil }
        else if let id = timeline.selectedBlock {
            change("Xóa block") { $0.blocks.removeAll { $0.id == id }; $0.normalizeFades() }; timeline.selectedBlock = nil
        }
        showProperties()
    }

    private func exportVideo() {
        showExportHUD()
    }

    private func beginExport(preset: Int) {
        guard !busy, !renderPending, !renderStale, let render = render else {
            report("Đợi preview sẵn sàng trước khi xuất.")
            exportHUD?.dismiss()
            return
        }
        // Chặn xuất khi render không còn đồng bộ với session hiện tại.
        if renderStale {
            report("Preview chưa cập nhật. Hãy đợi một lượt khiểm tra lại preview trước khi xuất.")
            let alert = NSAlert()
            alert.messageText = "Render chưa sẵn sàng"
            alert.informativeText = "Có lỗi khi cập nhật preview. Hãy kiểm tra cài đặt và thử lại.\n\n" + lastText
            alert.addButton(withTitle: "OK")
            alert.runModal()
            exportHUD?.dismiss()
            return
        }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["mp4"]
        let base = session.video.map { URL(fileURLWithPath: $0.path).deletingPathExtension().lastPathComponent } ?? "Video"
        let suffix = session.blocks.isEmpty ? "co-ban" : "dem-nhip"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "\(base)-\(suffix)-\(formatter.string(from: Date())).mp4"

        guard panel.runModal() == .OK, let url = panel.url else {
            exportHUD?.setMode(.settings(selectedPreset: preset))
            return
        }

        guard !FileManager.default.fileExists(atPath: url.path) else {
            report("File đã tồn tại. Chọn tên khác để giữ bản cũ.")
            exportHUD?.setMode(.settings(selectedPreset: preset))
            return
        }

        let exportPreset = VideoExportPreset(rawValue: preset) ?? .highestQuality
        busy = true
        player.pause()
        let snapshot = session
        report("Đang xuất…")
        refresh()

        exportHUD?.setMode(.exporting(filename: url.lastPathComponent, presetName: exportPreset.displayName))

        let dockView = DockProgressView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
        dockView.progress = 0.0
        dockProgressView = dockView
        NSApp.dockTile.contentView = dockView
        NSApp.dockTile.display()

        VideoExportService.shared.export(
            render: render,
            outputURL: url,
            preset: exportPreset,
            progressHandler: { [weak self] progress in
                self?.exportHUD?.updateProgress(progress)
                self?.dockProgressView?.progress = progress
                NSApp.dockTile.display()
                self?.statusLabel.stringValue = String(format: "Đang xuất %.0f%%", progress * 100.0)
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.busy = false
                self.dockProgressView = nil
                NSApp.dockTile.contentView = nil
                NSApp.dockTile.display()

                switch result {
                case .success(let exportedURL):
                    self.lastExport = snapshot
                    self.report("Đã xuất: \(exportedURL.lastPathComponent)")
                    self.exportHUD?.setMode(.completed(filename: exportedURL.lastPathComponent))
                    NotificationService.shared.notifyCompletion(
                        totalFiles: 1,
                        newDownloaded: 1,
                        message: "Đã xuất thành công: \(exportedURL.lastPathComponent)"
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        self?.exportHUD?.dismiss()
                        NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                    }
                case .failure(let error):
                    if (error as? VideoExportError) == .cancelled {
                        self.report("Đã hủy xuất video.")
                        self.exportHUD?.dismiss()
                        try? FileManager.default.removeItem(at: url)
                    } else {
                        let errMsg = error.localizedDescription
                        self.report(errMsg)
                        self.exportHUD?.setMode(.failed(message: errMsg))
                    }
                }
                self.refresh()
            }
        )
    }

    private func cancelExport() {
        VideoExportService.shared.cancelExport()
        busy = false
        dockProgressView = nil
        NSApp.dockTile.contentView = nil
        NSApp.dockTile.display()
        report("Đã hủy xuất video.")
        exportHUD?.dismiss()
        refresh()
    }
}
