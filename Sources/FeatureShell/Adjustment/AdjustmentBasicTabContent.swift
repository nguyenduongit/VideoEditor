import SwiftUI
import Domain
import DesignSystem

/// Tab Basic cho đối tượng Adjustment Layer gồm Cân bằng trắng và Ánh sáng/Tương phản.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentBasicTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: SubTab = .basic

    private enum SubTab: String, CaseIterable {
        case basic = "Cơ bản"
        case hsl = "HSL"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            subTabBar

            if selectedSubTab == .basic {
                autoBalanceButton
                intensitySection
                whiteBalanceSection
                toneSection
                AdjustmentPresetActionSectionView(viewModel: viewModel, currentConfig: currentConfig)
            } else {
                AdjustmentHSLTabContent(viewModel: viewModel)
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

    private var intensitySection: some View {
        DSCollapsibleSection(title: "Cường độ áp dụng", defaultExpanded: true) {
            let opacityBinding = Binding<Double>(
                get: { viewModel.liveNumber(for: "opacity", default: 1.0) },
                set: { viewModel.updateLiveValue(key: "opacity", value: $0) }
            )
            DSSliderWithInput(
                title: "Cường độ",
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
            title: "Cân bằng trắng & Màu sắc",
            defaultExpanded: true,
            onReset: resetWhiteBalance
        ) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(
                    title: "Nhiệt độ (Temp)",
                    value: basicBinding(\.temp),
                    gradient: LinearGradient(
                        colors: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.95, green: 0.55, blue: 0.15)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    onEditingChanged: onSliderEditingEnded
                )

                DSGradientSlider(
                    title: "Sắc thái (Tint)",
                    value: basicBinding(\.tint),
                    gradient: LinearGradient(
                        colors: [Color(red: 0.25, green: 0.8, blue: 0.4), Color(red: 0.95, green: 0.25, blue: 0.65)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    onEditingChanged: onSliderEditingEnded
                )

                DSGradientSlider(
                    title: "Độ bão hòa (Saturation)",
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
            title: "Ánh sáng & Tương phản",
            defaultExpanded: true,
            onReset: resetTone
        ) {
            VStack(spacing: DSSpacing.md) {
                DSGradientSlider(title: "Phơi sáng (Exposure)", value: basicBinding(\.exposure), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Độ tương phản (Contrast)", value: basicBinding(\.contrast), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Vùng sáng (Highlight)", value: basicBinding(\.highlight), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Vùng tối (Shadow)", value: basicBinding(\.shadow), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Điểm trắng (White)", value: basicBinding(\.white), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Điểm đen (Black)", value: basicBinding(\.black), onEditingChanged: onSliderEditingEnded)
                DSGradientSlider(title: "Độ tươi (Brilliance)", value: basicBinding(\.brilliance), onEditingChanged: onSliderEditingEnded)
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

    private var autoBalanceButton: some View {
        Button(action: applyAutoBalance) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 1.0))
                Text(String(localized: "Cân chỉnh tự động (Auto Balance)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textPrimary)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applyAutoBalance() {
        var cfg = currentConfig
        cfg.basic.contrast = 15
        cfg.basic.brilliance = 10
        cfg.basic.highlight = -8
        cfg.basic.shadow = 12
        cfg.basic.white = 5
        cfg.basic.black = -5
        if let json = cfg.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }
}
