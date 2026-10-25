import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển màu cơ bản (Basic Grading): Auto Balance, White Balance, Tone & Light.
/// Đặt tên 100% bằng tiếng Anh ngắn gọn, không lồng subtab.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct ColorBasicSectionView: View {
    @Bindable var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            if viewModel.selectedClip?.kind == .adjustment {
                intensitySection
            }

            whiteBalanceSection
            toneSection
        }
    }

    private var intensitySection: some View {
        DSCollapsibleSection(title: "Intensity", defaultExpanded: true) {
            let opacityBinding = Binding<Double>(
                get: { viewModel.liveNumber(for: "opacity", default: 1.0) },
                set: { viewModel.updateLiveValue(key: "opacity", value: $0) }
            )
            DSSliderWithInput(
                title: "Opacity",
                value: opacityBinding,
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                onEditingChanged: { editing in
                    viewModel.onSliderEditingChanged(key: "opacity", isEditing: editing)
                }
            )
        }
    }

    private var whiteBalanceSection: some View {
        DSCollapsibleSection(
            title: "White Balance",
            defaultExpanded: true,
            onReset: resetWhiteBalance
        ) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(
                    title: "Temperature",
                    value: basicBinding(\.temp),
                    gradient: LinearGradient(
                        colors: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.95, green: 0.55, blue: 0.15)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    onEditingChanged: onSliderEditingEnded
                )

                DSGradientSlider(
                    title: "Tint",
                    value: basicBinding(\.tint),
                    gradient: LinearGradient(
                        colors: [Color(red: 0.25, green: 0.8, blue: 0.4), Color(red: 0.95, green: 0.25, blue: 0.65)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    onEditingChanged: onSliderEditingEnded
                )

                DSGradientSlider(
                    title: "Saturation",
                    value: basicBinding(\.saturation),
                    gradient: LinearGradient(
                        colors: [Color(white: 0.45), Color(red: 0.95, green: 0.25, blue: 0.25)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    onEditingChanged: onSliderEditingEnded
                )
            }
        }
    }

    private var toneSection: some View {
        DSCollapsibleSection(
            title: "Tone & Light",
            defaultExpanded: true,
            onReset: resetTone
        ) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(title: "Exposure", value: basicBinding(\.exposure), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Contrast", value: basicBinding(\.contrast), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Highlights", value: basicBinding(\.highlight), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Shadows", value: basicBinding(\.shadow), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Whites", value: basicBinding(\.white), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Blacks", value: basicBinding(\.black), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Brilliance", value: basicBinding(\.brilliance), onEditingChanged: onSliderEditingEnded)
            }
        }
    }

    // MARK: - State & Bindings

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }

    private func basicBinding(_ keyPath: WritableKeyPath<BasicGradingParameters, Float>) -> Binding<Double> {
        Binding(
            get: { Double(currentConfig.basic[keyPath: keyPath]) },
            set: { newValue in
                var cfg = currentConfig
                cfg.basic[keyPath: keyPath] = Float(newValue)
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


    private func resetWhiteBalance() {
        var cfg = currentConfig
        cfg.basic.temp = 0
        cfg.basic.tint = 0
        cfg.basic.saturation = 0
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func resetTone() {
        var cfg = currentConfig
        cfg.basic.exposure = 0
        cfg.basic.contrast = 0
        cfg.basic.highlight = 0
        cfg.basic.shadow = 0
        cfg.basic.white = 0
        cfg.basic.black = 0
        cfg.basic.brilliance = 0
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }
}
