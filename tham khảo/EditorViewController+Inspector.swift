import AppKit
import AVFoundation

extension EditorViewController {
    func add(_ view: NSView) {
        properties.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: properties.widthAnchor, constant: -32).isActive = true
    }

    func note(_ text: String) {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        add(label)
    }

    @discardableResult
    func section(_ title: String, reset: @escaping () -> Void) -> InspectorSectionHeader {
        let header = InspectorSectionHeader(
            title: title,
            showsCheckbox: false,
            showsReset: true,
            onReset: reset
        )
        add(header)
        return header
    }

    @discardableResult
    func toggle(_ title: String, value: Bool, action: @escaping (inout EditorSession, Bool) -> Void) -> InspectorToggleRow {
        let row = InspectorToggleRow(title: title, isChecked: value)
        let id = UUID().uuidString
        row.identifier = NSUserInterfaceItemIdentifier(id)
        row.target = self
        row.action = #selector(invoke(_:))
        actions[id] = { [weak self] control in
            let checked = (control as? InspectorToggleRow)?.isChecked ?? ((control as? NSButton)?.state == .on)
            self?.change(title) { action(&$0, checked) }
        }
        row.onToggle = { [weak self] checked in
            self?.change(title) { action(&$0, checked) }
        }
        add(row)
        return row
    }

    func field(_ title: String, value: String, action: @escaping (String) -> Void) {
        note(title); let text = NSTextField(string: value); text.target = self; text.action = #selector(invoke(_:)); text.delegate = self
        let id = UUID().uuidString; text.identifier = NSUserInterfaceItemIdentifier(id)
        actions[id] = { control in
            guard let tf = control as? NSTextField else { return }
            action(tf.stringValue)
        }
        add(text)
    }

    func subheading(_ text: String) {
        let label = InspectorSubheading(title: text)
        add(label)
    }

    @discardableResult
    func inspectorSlider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        defaultValue: Double,
        step: Double = 1.0,
        displayMultiplier: Double = 1.0,
        decimalPlaces: Int = 0,
        unit: String = "",
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)],
        action: @escaping (inout EditorSession, Double) -> Void
    ) -> InspectorSliderRow {
        let row = InspectorSliderRow(
            title: title,
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: step,
            displayMultiplier: displayMultiplier,
            decimalPlaces: decimalPlaces,
            unit: unit,
            trackColors: trackColors
        ) { [weak self] val in
            self?.change("Chỉnh \(title)", live: true) { action(&$0, val) }
        }
        let id = UUID().uuidString
        row.sliderView.identifier = NSUserInterfaceItemIdentifier(id)
        row.sliderView.target = self
        row.sliderView.action = #selector(invoke(_:))
        actions[id] = { [weak self, weak row] control in
            guard let slider = control as? NSSlider else { return }
            let val = slider.doubleValue
            row?.stepperBox.value = val * displayMultiplier
            self?.change("Chỉnh \(title)", live: true) { action(&$0, val) }
        }
        add(row)
        return row
    }

    @discardableResult
    func slider(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        defaultValue: Double,
        format: String = "%.2f",
        multiplier: Double = 1.0,
        unit: String = "",
        action: @escaping (inout EditorSession, Double) -> Void
    ) -> InspectorSliderRow {
        let dec = format.contains("%.1f") ? 1 : (format.contains("%.0f") ? 0 : 2)
        let step = (dec == 0) ? 1.0 : (dec == 1 ? 0.1 : 0.05)
        return inspectorSlider(
            title,
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: step,
            displayMultiplier: multiplier,
            decimalPlaces: dec,
            unit: unit.isEmpty ? "" : (unit.hasPrefix(" ") || unit == "%" || unit == "°" || unit == "×" || unit == "s" ? unit : " " + unit),
            action: action
        )
    }

    @discardableResult
    func capCutSlider(
        title: String,
        value: Double,
        range: ClosedRange<Double> = -100...100,
        defaultValue: Double = 0.0,
        trackColors: [NSColor] = [NSColor(white: 0.28, alpha: 1.0)],
        action: @escaping (inout EditorSession, Double) -> Void
    ) -> InspectorSliderRow {
        return inspectorSlider(
            title,
            value: value,
            range: range,
            defaultValue: defaultValue,
            step: 1.0,
            displayMultiplier: 1.0,
            decimalPlaces: 0,
            unit: "",
            trackColors: trackColors,
            action: action
        )
    }

    func stepperField(_ title: String, value: Double, range: ClosedRange<Double>, defaultValue: Double, action: @escaping (inout EditorSession, Double) -> Void) {
        inspectorSlider(title, value: value, range: range, defaultValue: defaultValue, step: 1.0, decimalPlaces: 0, unit: "°", action: action)
    }

    func popup(_ title: String, choices: [String], selected: Int, action: @escaping (inout EditorSession, Int) -> Void) {
        note(title); let p = NSPopUpButton(frame: .zero, pullsDown: false); p.addItems(withTitles: choices); p.selectItem(at: selected)
        p.target = self; p.action = #selector(invoke(_:)); let id = UUID().uuidString; p.identifier = NSUserInterfaceItemIdentifier(id)
        actions[id] = { [weak self] control in
            guard let popup = control as? NSPopUpButton else { return }
            self?.change(title) { action(&$0, popup.indexOfSelectedItem) }
        }
        add(p)
    }

    func ratioSelector(selected: Int, action: @escaping (inout EditorSession, Int) -> Void) {
        let resString = currentEffectiveResolutionString()
        let row = InspectorAspectRatioRow(
            title: "Tỷ lệ",
            options: ["Original", "9:16", "16:9", "1:1", "4:5"],
            selectedIndex: selected,
            resolutionText: resString
        ) { [weak self] index in
            self?.change("Tỷ lệ") { action(&$0, index) }
            if let self = self {
                self.aspectRatioRow?.updateResolution(self.currentEffectiveResolutionString())
            }
        }
        aspectRatioRow = row
        add(row)
    }

    func clearProperties() {
        func release(_ v: NSView) { if let id = v.identifier?.rawValue { actions.removeValue(forKey: id) }; v.subviews.forEach(release) }
        for v in properties.arrangedSubviews { release(v); properties.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    func showProperties() {
        clearProperties()
        let activeSubTab = navigationState.currentSubTab(for: navigationState.mainTab)
        switch navigationState.mainTab {
        case .video:
            showVideoProperties(subTab: activeSubTab)
        case .adjustment:
            showAdjustmentProperties(subTab: activeSubTab)
        case .text:
            showTextProperties(subTab: activeSubTab)
        case .audio:
            showAudioProperties(subTab: activeSubTab)
        }
        func disable(_ v: NSView) {
            if let c = v as? NSControl {
                if let tf = c as? NSTextField, !tf.isEditable {
                    // Không can thiệp nhãn văn bản chỉ đọc
                } else {
                    c.isEnabled = false
                }
            }
            v.subviews.forEach(disable)
        }
        if busy || session.video == nil { properties.arrangedSubviews.forEach(disable) }
    }

    func showVideoProperties(subTab: Int) {
        if subTab == 0 {
            section("Khung hình") { [weak self] in
                self?.change("Đặt lại khung hình") { s in
                    s.cropMode = 0; s.cropZoom = 1.0; s.cropRotation = 0.0; s.cropOffsetY = 0.5; s.cropAutoPan = false; s.cropPanX = 0.5
                }
            }
            ratioSelector(selected: session.cropMode) { $0.cropMode = $1 }
            inspectorSlider("Thu phóng", value: session.cropZoom, range: 1...2.5, defaultValue: 1.0, step: 0.05, decimalPlaces: 2, unit: "×") { $0.cropZoom = $1 }
            toggle("Tự động lia theo người (AI)", value: session.cropAutoPan) { $0.cropAutoPan = $1 }
            let positionX = inspectorSlider("Vị trí ngang (X)", value: session.cropPanX, range: 0...1, defaultValue: 0.5, step: 0.01, displayMultiplier: 100.0, decimalPlaces: 0, unit: "%") { $0.cropPanX = $1 }
            positionX.isEnabled = !session.cropAutoPan
            cropPanXSlider = positionX
            let positionY = inspectorSlider("Vị trí dọc (Y)", value: session.cropOffsetY, range: 0...1, defaultValue: 0.5, step: 0.01, displayMultiplier: 100.0, decimalPlaces: 0, unit: "%") { $0.cropOffsetY = $1 }
            cropPanYSlider = positionY
            inspectorSlider("Góc xoay", value: session.cropRotation, range: -180...180, defaultValue: 0.0, step: 1, unit: "°") { $0.cropRotation = $1 }
            if session.pose == nil { note("Chưa có dữ liệu AI; vị trí crop đang cố định.") }
            else if session.cropAutoPan { note("Vị trí X đang bám người bằng AI; vị trí Y vẫn do bạn điều chỉnh.") }
        } else if subTab == 1 {
            let legControlsEnabled = session.pose != nil && (!poseAnalysisPending || !poseAnalysisUserInitiated) && session.video != nil && !busy
            let legRestore = section("Kéo chân AI") { [weak self] in
                self?.change("Đặt lại kéo chân") {
                    $0.legScale = 1.0
                    $0.showLegGuides = false
                }
            }
            legRestore.isEnabled = legControlsEnabled
            let viewLine = toggle("View line", value: session.showLegGuides ?? false) { $0.showLegGuides = $1 }
            viewLine.isEnabled = legControlsEnabled
            let stretch = inspectorSlider("Chiều cao khối giữa", value: session.legScale, range: 1.0...1.5, defaultValue: 1.0, step: 0.05, decimalPlaces: 2, unit: "×") { $0.legScale = $1 }
            stretch.isEnabled = legControlsEnabled
            let analyzeButton: ProToolButton
            if session.pose != nil {
                analyzeButton = button("Phân tích lại hai đường bằng AI") { [weak self] _ in self?.analyzePose(background: false) }
            } else {
                analyzeButton = button("Phân tích hai đường bằng AI") { [weak self] _ in self?.analyzePose(background: false) }
            }
            analyzeButton.isEnabled = session.video != nil && (!poseAnalysisPending || !poseAnalysisUserInitiated) && !busy
            add(analyzeButton)
            if let error = poseAnalysisError, !poseAnalysisPending && poseAnalysisUserInitiated { note(error) }
        } else {
            section("Hiệu ứng video") { [weak self] in
                self?.change("Xóa hiệu ứng video") { $0.videoEffects.removeAll() }
                self?.timeline.selectedVideoEffect = nil
            }
            note("Kéo hiệu ứng xuống track VIDEO EFFECT. Kéo thân khối để đổi vị trí hoặc kéo hai cạnh để chỉnh thời gian theo bước 0,1 giây.")
            for kind in VideoEffectKind.allCases {
                let effect = VideoEffectDragButton(title: kind.title, target: nil, action: nil)
                effect.applyProfessionalStyle()
                effect.toolTip = "Kéo \(kind.title) xuống track VIDEO EFFECT."
                effect.onDrag = { [weak self] event in self?.timeline.beginVideoEffectTemplateDrag(kind: kind, duration: 1.0, event: event) }
                add(effect)
            }
            if let id = timeline.selectedVideoEffect, let effect = session.videoEffects.first(where: { $0.id == id }) {
                subheading("HIỆU ỨNG ĐANG CHỌN")
                note("\(effect.kind.title) · bắt đầu \(String(format: "%.1f", effect.startTime))s · thời gian \(String(format: "%.1f", effect.duration))s")
            }
        }
    }

    func showAdjustmentProperties(subTab: Int) {
        if subTab == 0 {
            // Sub-tab 0: Cơ bản (Adjust: Color & Lightness)
            let header = CapCutSectionHeader(
                title: "Adjust ▴",
                isChecked: session.adjustments.enabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật chỉnh màu" : "Tắt chỉnh màu (So sánh gốc)") {
                        $0.adjustments.enabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại chỉnh màu") {
                        $0.adjustments.temperature = 0
                        $0.adjustments.tint = 0
                        $0.adjustments.saturation = 1
                        $0.adjustments.brightness = 0
                        $0.adjustments.contrast = 1
                        $0.adjustments.highlights = 0
                        $0.adjustments.shadows = 0
                        $0.adjustments.whites = 0
                        $0.adjustments.blacks = 0
                        $0.adjustments.vibrance = 0
                    }
                }
            )
            header.resetButton.toolTip = "Đặt lại Màu sắc"
            add(header)

            let autoColor = button(
                colorAnalysisPending ? "Đang phân tích màu…" : "Auto Color",
                iconName: colorAnalysisPending ? "hourglass" : "wand.and.stars",
                style: .secondary
            ) { [weak self] _ in self?.analyzeColor() }
            autoColor.isEnabled = session.video != nil && !busy && !colorAnalysisPending
            add(autoColor)

            subheading("Color")
            capCutSlider(
                title: "Temp",
                value: round(Double(session.adjustments.temperature / 20.0)),
                trackColors: [NSColor(red: 0.15, green: 0.35, blue: 0.95, alpha: 1.0), NSColor(red: 0.98, green: 0.85, blue: 0.20, alpha: 1.0)]
            ) { $0.adjustments.temperature = Float($1 * 20.0) }

            capCutSlider(
                title: "Tint",
                value: round(Double(session.adjustments.tint)),
                trackColors: [NSColor(red: 0.15, green: 0.75, blue: 0.30, alpha: 1.0), NSColor(red: 0.88, green: 0.15, blue: 0.75, alpha: 1.0)]
            ) { $0.adjustments.tint = Float($1) }

            capCutSlider(
                title: "Saturation",
                value: round(Double((session.adjustments.saturation - 1.0) * 100.0)),
                trackColors: [NSColor(red: 0.45, green: 0.25, blue: 0.28, alpha: 1.0), NSColor(red: 1.00, green: 0.05, blue: 0.15, alpha: 1.0)]
            ) { $0.adjustments.saturation = Float(1.0 + $1 / 100.0) }

            subheading("Lightness")
            let neutralTrack = [NSColor(white: 0.24, alpha: 1.0)]
            capCutSlider(title: "Exposure", value: round(Double(session.adjustments.brightness * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.brightness = Float($1 / 100.0)
            }
            capCutSlider(title: "Contrast", value: round(Double((session.adjustments.contrast - 1.0) * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.contrast = Float(1.0 + $1 / 100.0)
            }
            capCutSlider(title: "Highlight", value: round(Double(session.adjustments.highlights * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.highlights = Float($1 / 100.0)
            }
            capCutSlider(title: "Shadow", value: round(Double(session.adjustments.shadows * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.shadows = Float($1 / 100.0)
            }
            capCutSlider(title: "Whites", value: round(Double(session.adjustments.whites * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.whites = Float($1 / 100.0)
            }
            capCutSlider(title: "Blacks", value: round(Double(session.adjustments.blacks * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.blacks = Float($1 / 100.0)
            }
            capCutSlider(title: "Brilliance", value: round(Double(session.adjustments.vibrance * 100.0)), trackColors: neutralTrack) {
                $0.adjustments.vibrance = Float($1 / 100.0)
            }
        } else if subTab == 1 {
            // Sub-tab 1: Phong cách (Presets)
            let header = CapCutSectionHeader(
                title: "Phong cách",
                isChecked: session.adjustments.enabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật chỉnh màu" : "Tắt chỉnh màu (So sánh gốc)") {
                        $0.adjustments.enabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại phong cách") {
                        $0.adjustments.presetIndex = 0
                        $0.adjustments.presetIntensity = 1.0
                    }
                }
            )
            add(header)

            subheading("BỘ LỌC PHONG CÁCH")
            let presets = ColorGradingService.presets
            let activePreset = session.adjustments.presetIndex

            let row1 = NSStackView()
            row1.orientation = .horizontal
            row1.spacing = 4
            row1.distribution = .fillEqually
            for p in presets.prefix(4) {
                let isSel = activePreset == p.id
                let pb = button(p.name, iconName: nil, style: isSel ? .primary : .secondary) { [weak self] _ in
                    self?.change("Chọn phong cách \(p.name)") { $0.adjustments.presetIndex = p.id }
                }
                pb.toolTip = "\(p.icon) \(p.name): \(p.description)"
                row1.addArrangedSubview(pb)
            }
            add(row1)

            let row2 = NSStackView()
            row2.orientation = .horizontal
            row2.spacing = 4
            row2.distribution = .fillEqually
            for p in presets.dropFirst(4) {
                let isSel = activePreset == p.id
                let pb = button(p.name, iconName: nil, style: isSel ? .primary : .secondary) { [weak self] _ in
                    self?.change("Chọn phong cách \(p.name)") { $0.adjustments.presetIndex = p.id }
                }
                pb.toolTip = "\(p.icon) \(p.name): \(p.description)"
                row2.addArrangedSubview(pb)
            }
            add(row2)

            if activePreset > 0 && activePreset < presets.count {
                let currentPreset = presets[activePreset]
                note("\(currentPreset.icon) \(currentPreset.description)")
                slider("Cường độ phong cách", value: Double(session.adjustments.presetIntensity), range: 0...1, defaultValue: 1.0, format: "%.0f", multiplier: 100, unit: "%") {
                    $0.adjustments.presetIntensity = Float($1)
                }
            }
        } else {
            // Sub-tab 2: Chỉnh màu chọn lọc (HSL)
            let header = CapCutSectionHeader(
                title: "Basic",
                isChecked: session.adjustments.enabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật chỉnh màu" : "Tắt chỉnh màu (So sánh gốc)") {
                        $0.adjustments.enabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại HSL") {
                        $0.adjustments.hsl = HSLAdjustments()
                    }
                }
            )
            add(header)

            subheading("CÁC DẢI MÀU")

            let ringsRow = HSLColorRingsRow(selectedIndex: selectedHSLChannel) { [weak self] idx in
                self?.selectedHSLChannel = idx
                self?.showProperties()
            }
            ringsRow.onEyedropper = { [weak self] in
                NSColorSampler().show { selectedColor in
                    guard let self = self, let color = selectedColor?.usingColorSpace(.deviceRGB) else { return }
                    let hue = color.hueComponent * 360.0
                    let channelIdx: Int
                    switch hue {
                    case 0..<20, 345...360: channelIdx = 0
                    case 20..<45: channelIdx = 1
                    case 45..<75: channelIdx = 2
                    case 75..<160: channelIdx = 3
                    case 160..<210: channelIdx = 4
                    case 210..<260: channelIdx = 5
                    case 260..<310: channelIdx = 6
                    case 310..<345: channelIdx = 7
                    default: channelIdx = 0
                    }
                    DispatchQueue.main.async {
                        self.selectedHSLChannel = channelIdx
                        self.showProperties()
                        let name = HSLColorRingsRow.standardColors[channelIdx].name
                        self.report("Đã chọn dải màu: \(name)")
                    }
                }
            }
            add(ringsRow)

            let curIdx = max(0, min(7, selectedHSLChannel))
            let colorInfo = HSLColorRingsRow.standardColors[curIdx]
            let curChannel = session.adjustments.hsl[curIdx]

            capCutSlider(
                title: "Hue",
                value: round(Double(curChannel.hue * 100.0)),
                trackColors: colorInfo.hueGradient
            ) { $0.adjustments.hsl[curIdx].hue = Float($1 / 100.0) }

            capCutSlider(
                title: "Saturation",
                value: round(Double(curChannel.saturation * 100.0)),
                trackColors: colorInfo.satGradient
            ) { $0.adjustments.hsl[curIdx].saturation = Float($1 / 100.0) }

            capCutSlider(
                title: "Brightness",
                value: round(Double(curChannel.luminance * 100.0)),
                trackColors: colorInfo.brightGradient
            ) { $0.adjustments.hsl[curIdx].luminance = Float($1 / 100.0) }

            if !curChannel.isNeutral {
                let resetHSLBtn = button("Đặt lại kênh \(colorInfo.name)", iconName: "arrow.counterclockwise", style: .ghost) { [weak self] _ in
                    guard let self = self else { return }
                    self.change("Đặt lại HSL \(colorInfo.name)") {
                        $0.adjustments.hsl[curIdx] = HSLChannel()
                    }
                }
                add(resetHSLBtn)
            }
        }
    }

    func showTextProperties(subTab: Int) {
        if subTab == 0 {
            // Sub-tab 0: Nội dung & Vị trí
            let header = CapCutSectionHeader(
                title: "Tiêu đề",
                isChecked: session.textEnabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật tiêu đề" : "Tắt tiêu đề") {
                        $0.textEnabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại tiêu đề") {
                        $0.textSettings = EditorTextSettings()
                        $0.textEnabled = false
                    }
                }
            )
            header.resetButton.toolTip = "Đặt lại Tiêu đề"
            add(header)

            subheading("Nội dung")
            field("Văn bản", value: session.title) { [weak self] text in
                self?.change("Nội dung tiêu đề") {
                    $0.title = text
                }
            }

            subheading("Vị trí nhanh")
            let posRow = NSStackView()
            posRow.orientation = .horizontal
            posRow.spacing = 6
            posRow.distribution = .fillEqually

            let topBtn = button("Đỉnh (15%)", iconName: "arrow.up.to.line", style: session.textSettings.positionPreset == 0 ? .primary : .secondary) { [weak self] _ in
                self?.change("Vị trí đỉnh") {
                    $0.textSettings.positionPreset = 0
                    $0.textSettings.positionY = 0.15
                    $0.textSettings.positionX = 0.50
                }
            }
            let centerBtn = button("Giữa (50%)", iconName: "viewfinder", style: session.textSettings.positionPreset == 1 ? .primary : .secondary) { [weak self] _ in
                self?.change("Vị trí giữa") {
                    $0.textSettings.positionPreset = 1
                    $0.textSettings.positionY = 0.50
                    $0.textSettings.positionX = 0.50
                }
            }
            let bottomBtn = button("Đáy (80%)", iconName: "arrow.down.to.line", style: session.textSettings.positionPreset == 2 ? .primary : .secondary) { [weak self] _ in
                self?.change("Vị trí đáy (Phụ đề)") {
                    $0.textSettings.positionPreset = 2
                    $0.textSettings.positionY = 0.80
                    $0.textSettings.positionX = 0.50
                }
            }
            posRow.addArrangedSubview(topBtn)
            posRow.addArrangedSubview(centerBtn)
            posRow.addArrangedSubview(bottomBtn)
            add(posRow)

            subheading("Tọa độ & Căn lề")
            capCutSlider(
                title: "Vị trí dọc (Y)",
                value: round(session.textSettings.positionY * 100.0),
                range: 5...95,
                defaultValue: 20.0
            ) {
                $0.textSettings.positionPreset = 3
                $0.textSettings.positionY = $1 / 100.0
            }

            capCutSlider(
                title: "Vị trí ngang (X)",
                value: round(session.textSettings.positionX * 100.0),
                range: 5...95,
                defaultValue: 50.0
            ) {
                $0.textSettings.positionPreset = 3
                $0.textSettings.positionX = $1 / 100.0
            }

            let alignControl = NSSegmentedControl(labels: ["Trái", "Giữa", "Phải"], trackingMode: .selectOne, target: nil, action: nil)
            alignControl.selectedSegment = session.textSettings.alignment
            alignControl.segmentStyle = .roundRect
            alignControl.target = self
            alignControl.action = #selector(textAlignmentChanged(_:))
            add(alignControl)

            subheading("Thời gian hiển thị")
            let timingControl = NSSegmentedControl(labels: ["Đoạn mở đầu", "Toàn bộ video"], trackingMode: .selectOne, target: nil, action: nil)
            timingControl.selectedSegment = session.textSettings.timingMode
            timingControl.segmentStyle = .roundRect
            timingControl.target = self
            timingControl.action = #selector(textTimingModeChanged(_:))
            add(timingControl)

            if session.textSettings.timingMode == 0 {
                slider("Thời điểm bắt đầu", value: session.textSettings.startTime, range: 0...10, defaultValue: 0.5, format: "%.1f", unit: "s") {
                    $0.textSettings.startTime = $1
                }
                slider("Thời lượng hiển thị", value: session.textSettings.duration, range: 0.5...15, defaultValue: 3.0, format: "%.1f", unit: "s") {
                    $0.textSettings.duration = $1
                }
            } else {
                note("Chữ sẽ hiển thị liên tục trong toàn bộ video.")
            }

        } else if subTab == 1 {
            // Sub-tab 1: Kiểu dáng
            let header = CapCutSectionHeader(
                title: "Kiểu chữ",
                isChecked: session.textEnabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật tiêu đề" : "Tắt tiêu đề") {
                        $0.textEnabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại kiểu dáng") {
                        $0.textSettings.applyStylePreset(.popDance)
                    }
                }
            )
            header.resetButton.toolTip = "Đặt lại Kiểu dáng"
            add(header)

            subheading("MẪU CHỮ NGHỆ THUẬT")
            let presets = TextStylePreset.allCases.filter { $0 != .custom }
            let activePreset = session.textSettings.stylePreset

            let row1 = NSStackView()
            row1.orientation = .horizontal
            row1.spacing = 4
            row1.distribution = .fillEqually
            for p in presets.prefix(4) {
                let card = PresetSelectionCard(id: p.rawValue, icon: p.icon, title: p.title, isSelected: p == activePreset)
                card.onSelect = { [weak self] _ in
                    self?.change("Chọn mẫu chữ \(p.title)") {
                        $0.textSettings.applyStylePreset(p)
                    }
                }
                row1.addArrangedSubview(card)
            }
            add(row1)

            let row2 = NSStackView()
            row2.orientation = .horizontal
            row2.spacing = 4
            row2.distribution = .fillEqually
            for p in presets.dropFirst(4) {
                let card = PresetSelectionCard(id: p.rawValue, icon: p.icon, title: p.title, isSelected: p == activePreset)
                card.onSelect = { [weak self] _ in
                    self?.change("Chọn mẫu chữ \(p.title)") {
                        $0.textSettings.applyStylePreset(p)
                    }
                }
                row2.addArrangedSubview(card)
            }
            add(row2)

            subheading("FONT CHỮ TIẾNG VIỆT UNICODE")
            let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
            for opt in VietnameseFontOption.allOptions {
                fontPopup.addItem(withTitle: "\(opt.displayName)")
            }
            fontPopup.selectItem(at: min(VietnameseFontOption.allOptions.count - 1, max(0, session.textSettings.fontIndex)))
            fontPopup.target = self
            fontPopup.action = #selector(textFontChanged(_:))
            add(fontPopup)

            subheading("Kích thước & Định dạng")
            capCutSlider(
                title: "Kích thước (Scale)",
                value: round(session.textSettings.fontSizeScale * 100.0),
                range: 50...250,
                defaultValue: 100.0
            ) {
                $0.textSettings.fontSizeScale = $1 / 100.0
            }

            let formatRow = NSStackView()
            formatRow.orientation = .horizontal
            formatRow.spacing = 6
            formatRow.distribution = .fillEqually

            let boldBtn = button("B  Đậm", iconName: nil, style: session.textSettings.isBold ? .primary : .secondary) { [weak self] _ in
                self?.change("In đậm") { $0.textSettings.isBold.toggle() }
            }
            let italicBtn = button("I  Nghiêng", iconName: nil, style: session.textSettings.isItalic ? .primary : .secondary) { [weak self] _ in
                self?.change("In nghiêng") { $0.textSettings.isItalic.toggle() }
            }
            let upperBtn = button("AA In hoa", iconName: nil, style: session.textSettings.isAllUpper ? .primary : .secondary) { [weak self] _ in
                self?.change("In hoa") { $0.textSettings.isAllUpper.toggle() }
            }
            formatRow.addArrangedSubview(boldBtn)
            formatRow.addArrangedSubview(italicBtn)
            formatRow.addArrangedSubview(upperBtn)
            add(formatRow)

            subheading("MÀU RUỘT CHỮ (FILL COLOR)")
            let fillPalette = ColorPaletteRow(selectedHex: session.textSettings.fillColor) { [weak self] chosenHex in
                self?.change("Đổi màu chữ") {
                    $0.textSettings.fillColor = chosenHex
                    $0.textSettings.stylePreset = .custom
                }
            }
            add(fillPalette)

            subheading("VIỀN CHỮ (STROKE)")
            toggle("Bật viền chữ", value: session.textSettings.strokeEnabled) {
                $0.textSettings.strokeEnabled = $1
                $0.textSettings.stylePreset = .custom
            }
            if session.textSettings.strokeEnabled {
                capCutSlider(
                    title: "Độ dày viền",
                    value: session.textSettings.strokeWidth,
                    range: 1...30,
                    defaultValue: 12.0
                ) {
                    $0.textSettings.strokeWidth = $1
                    $0.textSettings.stylePreset = .custom
                }
                let strokePalette = ColorPaletteRow(
                    selectedHex: session.textSettings.strokeColor,
                    colors: ["#FFFFFF", "#000000", "#5C4010", "#FF007F", "#111111", "#F21429"]
                ) { [weak self] chosenHex in
                    self?.change("Đổi màu viền") {
                        $0.textSettings.strokeColor = chosenHex
                        $0.textSettings.stylePreset = .custom
                    }
                }
                add(strokePalette)
            }

            subheading("HÀO QUANG & ĐỔ BÓNG (GLOW)")
            toggle("Bật hào quang phát sáng", value: session.textSettings.glowEnabled) {
                $0.textSettings.glowEnabled = $1
                $0.textSettings.stylePreset = .custom
            }
            if session.textSettings.glowEnabled {
                capCutSlider(
                    title: "Bán kính sáng",
                    value: session.textSettings.glowRadius,
                    range: 5...50,
                    defaultValue: 20.0
                ) {
                    $0.textSettings.glowRadius = $1
                    $0.textSettings.stylePreset = .custom
                }
                let glowPalette = ColorPaletteRow(
                    selectedHex: session.textSettings.glowColor,
                    colors: ["#EBFF4D", "#00F0FF", "#FF007F", "#E6A100", "#FFFFFF", "#000000"]
                ) { [weak self] chosenHex in
                    self?.change("Đổi màu hào quang") {
                        $0.textSettings.glowColor = chosenHex
                        $0.textSettings.stylePreset = .custom
                    }
                }
                add(glowPalette)
            }

            subheading("HỘP NỀN THÔNG MINH (BACKGROUND BANNER)")
            toggle("Bật hộp nền sau chữ", value: session.textSettings.backgroundEnabled) {
                $0.textSettings.backgroundEnabled = $1
                $0.textSettings.stylePreset = .custom
            }
            if session.textSettings.backgroundEnabled {
                capCutSlider(
                    title: "Độ mờ đục nền",
                    value: round(session.textSettings.backgroundAlpha * 100.0),
                    range: 10...100,
                    defaultValue: 65.0
                ) {
                    $0.textSettings.backgroundAlpha = $1 / 100.0
                    $0.textSettings.stylePreset = .custom
                }
            }

        } else {
            // Sub-tab 2: Chuyển động
            let header = CapCutSectionHeader(
                title: "Hiệu ứng động",
                isChecked: session.textEnabled,
                onToggle: { [weak self] enabled in
                    self?.change(enabled ? "Bật tiêu đề" : "Tắt tiêu đề") {
                        $0.textEnabled = enabled
                    }
                },
                onReset: { [weak self] in
                    self?.change("Đặt lại chuyển động") {
                        $0.textSettings.animationPreset = .fadeZoom
                    }
                }
            )
            header.resetButton.toolTip = "Đặt lại Chuyển động"
            add(header)

            subheading("MẪU HOẠT CẢNH (ANIMATION TEMPLATES)")
            let activeAnim = session.textSettings.animationPreset

            for anim in TextAnimationPreset.allCases {
                let isSel = (anim == activeAnim)
                let card = button("\(anim.icon)  \(anim.title)", iconName: nil, style: isSel ? .primary : .secondary) { [weak self] _ in
                    self?.change("Chọn hiệu ứng \(anim.title)") {
                        $0.textSettings.animationPreset = anim
                    }
                }
                add(card)
            }

            subheading("MÔ TẢ HOẠT CẢNH")
            switch activeAnim {
            case .none:
                note("Chữ đứng yên cố định tại vị trí đã chọn.")
            case .fadeZoom:
                note("🌊 Mờ dần xuất hiện, phóng to nhẹ nhàng từ từ, sau đó trôi nhẹ và mờ dần biến mất.")
            case .popBounce:
                note("💥 Bật nảy đàn hồi từ tâm ra màn hình đầy năng động, phù hợp video sôi động.")
            case .slideIn:
                note("🚀 Lướt nhanh từ dưới lên theo đường cong quán tính mượt mà Ease-out.")
            case .beatPulse:
                note("🎵 ĐẶC BIỆT: Chữ sẽ tự động nhún nảy theo đúng từng phách Dance Beat của bài nhạc!")
            }
        }
    }

    @objc func textAlignmentChanged(_ sender: NSSegmentedControl) {
        change("Căn lề chữ") {
            $0.textSettings.alignment = sender.selectedSegment
        }
    }

    @objc func textTimingModeChanged(_ sender: NSSegmentedControl) {
        change("Chế độ thời gian hiển thị") {
            $0.textSettings.timingMode = sender.selectedSegment
        }
    }

    @objc func textFontChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0 else { return }
        change("Đổi font chữ") {
            $0.textSettings.fontIndex = idx
            $0.textSettings.stylePreset = .custom
        }
    }

    func showAudioProperties(subTab: Int) {
        if subTab == 0 {
            // Sub-tab 0: Nhạc & Nhịp
            section("Audio") { [weak self] in self?.resetGroup() }
            note(String(format: "BPM gốc: %.2f • Tốc độ đầu ra: %.2f×", session.baseBPM, session.speed))
            slider("BPM đầu ra", value: session.targetBPM, range: 31...300, defaultValue: session.baseBPM, format: "%.1f") { $0.targetBPM = $1 }
            slider("Âm lượng", value: session.musicVolume * 100, range: 0...200, defaultValue: 100, unit: "%") { $0.musicVolume = $1 / 100 }
            note(session.match == nil ? "Đang điều chỉnh audio gốc của video." : "Đang điều chỉnh audio đã đồng bộ với video.")
        } else {
            // Sub-tab 1: Fade & Trim
            section("Fade & Trim") { [weak self] in
                self?.change("Đặt lại Fade & Trim") {
                    $0.audioFadeOutDuration = 2.0
                    $0.audioTrimEnd = nil
                    $0.videoTrimEnd = nil
                }
            }
            slider("Thời lượng Fade Out", value: session.audioFadeOutDuration, range: 0...5, defaultValue: 2.0, format: "%.1f", unit: "s") {
                $0.audioFadeOutDuration = $1
            }
            note("Âm thanh nhỏ dần về 0 trước khi kết thúc audio.")

            subheading("Điểm cắt cuối (Trim Points)")
            let audioTrimText = session.audioTrimEnd != nil ? "\(format(session.audioTrimEnd!))" : "Không cắt (hết bài)"
            let videoTrimText = session.videoTrimEnd != nil ? "\(format(session.videoTrimEnd!))" : "Không cắt (hết video)"
            note("• Cắt Audio tại: \(audioTrimText)")
            note("• Cắt Video tại: \(videoTrimText)")

            if session.audioTrimEnd != nil || session.videoTrimEnd != nil {
                let clearRow = NSStackView()
                clearRow.orientation = .horizontal
                clearRow.spacing = 6
                clearRow.distribution = .fillEqually
                if session.audioTrimEnd != nil {
                    let clearAudioBtn = button("Bỏ cắt Audio", iconName: "arrow.counterclockwise", style: .ghost) { [weak self] _ in
                        self?.change("Bỏ cắt Audio") { $0.audioTrimEnd = nil }
                    }
                    clearRow.addArrangedSubview(clearAudioBtn)
                }
                if session.videoTrimEnd != nil {
                    let clearVideoBtn = button("Bỏ cắt Video", iconName: "arrow.counterclockwise", style: .ghost) { [weak self] _ in
                        self?.change("Bỏ cắt Video") { $0.videoTrimEnd = nil }
                    }
                    clearRow.addArrangedSubview(clearVideoBtn)
                }
                add(clearRow)
            }
            note("Mẹo: Di chuyển kim đỏ đến vị trí mong muốn trên timeline rồi nhấn 'Cắt Audio' [⌥A] hoặc 'Cắt Video' [⌥V] trên thanh công cụ.")
        }
    }
}
