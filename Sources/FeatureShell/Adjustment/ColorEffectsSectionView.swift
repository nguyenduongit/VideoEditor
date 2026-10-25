import SwiftUI
import Domain
import DesignSystem
#if os(macOS)
import AppKit
#endif

/// Bảng điều khiển hiệu ứng chất liệu & 3D LUT: 3D LUT (.cube), Vignette, Film Grain, Sharpen.
/// Đặt tên 100% bằng tiếng Anh ngắn gọn, không lồng subtab.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct ColorEffectsSectionView: View {
    @Bindable var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            lutSection
            vignetteSection
            textureSection
        }
    }

    private var lutSection: some View {
        DSCollapsibleSection(title: "3D LUT (.cube)", defaultExpanded: true) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                lutFileRow

                if currentConfig.lut.isEnabled && !currentConfig.lut.lutName.isEmpty {
                    DSSliderWithInput(
                        title: "Intensity",
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
                .help("Remove LUT")
            } else {
                Text("No LUT Loaded")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)

                Spacer()

                Button(action: pickLUTFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Load .cube")
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

    private var vignetteSection: some View {
        DSCollapsibleSection(title: "Vignette", defaultExpanded: true, onReset: resetVignette) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(
                    title: "Amount",
                    value: effectsBinding(\.vignetteAmount),
                    range: -100.0...100.0,
                    defaultValue: 0.0,
                    onEditingChanged: onSliderEditingEnded
                )
                DSGradientSlider(
                    title: "Midpoint",
                    value: effectsBinding(\.vignetteMidpoint),
                    range: 0.0...100.0,
                    defaultValue: 50.0,
                    onEditingChanged: onSliderEditingEnded
                )
                DSGradientSlider(
                    title: "Feather",
                    value: effectsBinding(\.vignetteFeather),
                    range: 0.0...100.0,
                    defaultValue: 50.0,
                    onEditingChanged: onSliderEditingEnded
                )
            }
        }
    }

    private var textureSection: some View {
        DSCollapsibleSection(title: "Texture & Detail", defaultExpanded: true, onReset: resetTexture) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(
                    title: "Film Grain",
                    value: effectsBinding(\.grainAmount),
                    range: 0.0...100.0,
                    defaultValue: 0.0,
                    onEditingChanged: onSliderEditingEnded
                )
                DSGradientSlider(
                    title: "Sharpen",
                    value: effectsBinding(\.sharpenAmount),
                    range: 0.0...100.0,
                    defaultValue: 0.0,
                    onEditingChanged: onSliderEditingEnded
                )
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
        panel.allowedContentTypes = [.init(filenameExtension: "cube")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let content = try? String(contentsOf: url, encoding: .utf8),
               LUTParser.parse(fileURL: url) != nil {
                var cfg = currentConfig
                cfg.lut = LUTConfiguration(lutName: url.deletingPathExtension().lastPathComponent, lutDataString: content, intensity: 100.0, isEnabled: true)
                if let json = cfg.encodeToJSON() {
                    viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
                }
            }
        }
        #endif
    }

    private func removeLUT() {
        var cfg = currentConfig
        cfg.lut = LUTConfiguration()
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func applyPresetName(_ name: String) {
        var cfg = currentConfig
        switch name {
        case "Teal & Orange":
            cfg.basic.temp = 12
            cfg.basic.tint = -6
            cfg.wheels.lift = ColorWheelOffset(x: -0.15, y: -0.1, luma: -5)
            cfg.wheels.gain = ColorWheelOffset(x: 0.15, y: 0.1, luma: 10)
        case "Vintage Warm":
            cfg.basic.temp = 25
            cfg.effects.grainAmount = 20
            cfg.effects.vignetteAmount = 25
        case "B&W Film":
            cfg.basic.saturation = -100
            cfg.basic.contrast = 25
            cfg.effects.grainAmount = 30
        case "Cyberpunk":
            cfg.basic.tint = 28
            cfg.basic.contrast = 20
            cfg.wheels.lift = ColorWheelOffset(x: 0.0, y: -0.2, luma: 0)
            cfg.wheels.gain = ColorWheelOffset(x: 0.2, y: 0.15, luma: 10)
        case "Moody Forest":
            cfg.basic.temp = -15
            cfg.basic.tint = -15
            cfg.effects.vignetteAmount = 35
        default: break
        }
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func resetVignette() {
        var cfg = currentConfig
        cfg.effects.vignetteAmount = 0
        cfg.effects.vignetteMidpoint = 50
        cfg.effects.vignetteFeather = 50
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func resetTexture() {
        var cfg = currentConfig
        cfg.effects.grainAmount = 0
        cfg.effects.sharpenAmount = 0
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }
}
