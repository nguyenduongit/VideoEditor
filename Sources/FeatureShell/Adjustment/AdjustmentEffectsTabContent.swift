import SwiftUI
import Domain
import DesignSystem
#if os(macOS)
import AppKit
#endif

/// Tab Hiệu ứng (Effects) gồm 3D LUT và các hiệu ứng chất liệu (Vignette, Grain, Sharpen).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentEffectsTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: SubTab = .lut

    private enum SubTab: String, CaseIterable {
        case lut = "3D LUT"
        case style = "Chất liệu"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            subTabBar

            if selectedSubTab == .lut {
                lutSection
            } else {
                styleSection
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var subTabBar: some View {
        HStack(spacing: 2) {
            ForEach(SubTab.allCases, id: \.self) { tab in
                Button(action: { selectedSubTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedSubTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedSubTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(selectedSubTab == tab ? DSColors.windowBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Subtab LUT

    private var lutSection: some View {
        VStack(spacing: DSSpacing.md) {
            DSCollapsibleSection(title: "Tệp 3D LUT (.cube)", defaultExpanded: true) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    lutFileRow

                    if currentConfig.lut.isEnabled && !currentConfig.lut.lutName.isEmpty {
                        DSSliderWithInput(
                            title: "Cường độ LUT",
                            value: Binding(
                                get: { Double(currentConfig.lut.intensity) },
                                set: { newValue in
                                    var cfg = currentConfig
                                    cfg.lut.intensity = Float(newValue)
                                    if let json = cfg.encodeToJSON() {
                                        viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                                    }
                                }
                            ),
                            range: 0.0...100.0,
                            step: 1.0,
                            defaultValue: 100.0,
                            unit: "%",
                            onEditingChanged: onSliderEditingEnded
                        )
                    }
                }
            }

            DSCollapsibleSection(title: "Preset Phim có sẵn", defaultExpanded: true) {
                builtInPresetsGrid
            }
        }
    }

    private var lutFileRow: some View {
        HStack {
            if currentConfig.lut.isEnabled && !currentConfig.lut.lutName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentConfig.lut.lutName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSColors.textPrimary)
                        .lineLimit(1)
                    Text("3D LUT Active")
                        .font(.system(size: 10))
                        .foregroundStyle(DSColors.accent)
                }

                Spacer()

                Button(action: removeLUT) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Gỡ LUT")
            } else {
                Text("Chưa chọn tệp .cube")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)

                Spacer()

                Button(action: pickLUTFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Nạp .cube")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DSColors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DSSpacing.sm)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
    }

    private var builtInPresetsGrid: some View {
        let presets = ["Teal & Orange", "Vintage Warm", "B&W Film", "Cyberpunk", "Moody Forest"]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.xs) {
            ForEach(presets, id: \.self) { name in
                Button(action: { applyPresetName(name) }) {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(DSColors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(DSColors.blockBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Subtab Chất liệu (Style)

    private var styleSection: some View {
        VStack(spacing: DSSpacing.md) {
            DSCollapsibleSection(title: "Tối 4 góc (Vignette)", defaultExpanded: true, onReset: resetVignette) {
                VStack(spacing: DSSpacing.md) {
                    DSGradientSlider(
                        title: "Cường độ (Amount)",
                        value: effectsBinding(\.vignetteAmount),
                        range: -100.0...100.0,
                        defaultValue: 0.0,
                        onEditingChanged: onSliderEditingEnded
                    )
                    DSGradientSlider(
                        title: "Bán kính (Midpoint)",
                        value: effectsBinding(\.vignetteMidpoint),
                        range: 0.0...100.0,
                        defaultValue: 50.0,
                        onEditingChanged: onSliderEditingEnded
                    )
                    DSGradientSlider(
                        title: "Độ mờ viền (Feather)",
                        value: effectsBinding(\.vignetteFeather),
                        range: 0.0...100.0,
                        defaultValue: 50.0,
                        onEditingChanged: onSliderEditingEnded
                    )
                }
            }

            DSCollapsibleSection(title: "Hạt phim & Sắc nét", defaultExpanded: true, onReset: resetGrain) {
                VStack(spacing: DSSpacing.md) {
                    DSGradientSlider(
                        title: "Hạt phim (Grain)",
                        value: effectsBinding(\.grainAmount),
                        range: 0.0...100.0,
                        defaultValue: 0.0,
                        onEditingChanged: onSliderEditingEnded
                    )
                    DSGradientSlider(
                        title: "Độ sắc nét (Sharpen)",
                        value: effectsBinding(\.sharpenAmount),
                        range: 0.0...100.0,
                        defaultValue: 0.0,
                        onEditingChanged: onSliderEditingEnded
                    )
                }
            }
        }
    }

    // MARK: - State & Actions

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }

    private func effectsBinding(_ keyPath: WritableKeyPath<EffectsGradingParameters, Float>) -> Binding<Double> {
        Binding(
            get: { Double(currentConfig.effects[keyPath: keyPath]) },
            set: { newValue in
                var cfg = currentConfig
                cfg.effects[keyPath: keyPath] = Float(newValue)
                if let json = cfg.encodeToJSON() {
                    viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                }
            }
        )
    }

    private func onSliderEditingEnded(isEditing: Bool) {
        if !isEditing, let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func pickLUTFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        if panel.runModal() == .OK, let url = panel.url {
            if LUTParser.parse(fileURL: url) != nil, let content = try? String(contentsOf: url, encoding: .utf8) {
                var cfg = currentConfig
                cfg.lut = LUTConfiguration(lutName: url.lastPathComponent, lutDataString: content, intensity: 100.0, isEnabled: true)
                if let json = cfg.encodeToJSON() { viewModel.commitTextProperty(key: "adjustmentConfig", text: json) }
            }
        }
        #endif
    }

    private func removeLUT() {
        var cfg = currentConfig
        cfg.lut = LUTConfiguration()
        if let json = cfg.encodeToJSON() { viewModel.commitTextProperty(key: "adjustmentConfig", text: json) }
    }

    private func applyPresetName(_ name: String) {
        var cfg = currentConfig
        switch name {
        case "Teal & Orange":
            cfg.basic.temp = 15; cfg.basic.contrast = 20
            cfg.wheels.lift.x = -0.2; cfg.wheels.lift.y = -0.2
            cfg.wheels.gain.x = 0.25; cfg.wheels.gain.y = 0.2
        case "Vintage Warm":
            cfg.basic.temp = 25; cfg.basic.tint = -10; cfg.effects.vignetteAmount = 35
        case "B&W Film":
            cfg.basic.saturation = -100; cfg.basic.contrast = 30; cfg.effects.grainAmount = 40
        case "Cyberpunk":
            cfg.basic.temp = -20; cfg.basic.tint = 35; cfg.basic.contrast = 25
        case "Moody Forest":
            cfg.basic.temp = -10; cfg.basic.highlight = -25; cfg.effects.vignetteAmount = 45
        default: break
        }
        if let json = cfg.encodeToJSON() { viewModel.commitTextProperty(key: "adjustmentConfig", text: json) }
    }

    private func resetVignette() {
        var cfg = currentConfig
        cfg.effects.vignetteAmount = 0; cfg.effects.vignetteMidpoint = 50; cfg.effects.vignetteFeather = 50
        if let json = cfg.encodeToJSON() { viewModel.commitTextProperty(key: "adjustmentConfig", text: json) }
    }

    private func resetGrain() {
        var cfg = currentConfig
        cfg.effects.grainAmount = 0; cfg.effects.sharpenAmount = 0
        if let json = cfg.encodeToJSON() { viewModel.commitTextProperty(key: "adjustmentConfig", text: json) }
    }
}
