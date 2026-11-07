import SwiftUI
import Domain
import DesignSystem

/// Dedicated Inspector panel for Adjustment Layer clips.
/// Directly renders the 5 main top-level tabs: Basic, HSL, Wheels, Curves, Effects.
/// Complies with R3.1 (File <= 300 lines, View body <= 80 lines) of AGENTS.md.
public struct AdjustmentInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            if viewModel.selectedClip?.originPresetID != nil && viewModel.effectiveTab == "Basic" {
                presetMixSection
            }
            switch viewModel.effectiveTab {
            case "Basic":
                ColorBasicSectionView(viewModel: viewModel)
            case "HSL":
                AdjustmentHSLTabContent(viewModel: viewModel)
            case "Wheels":
                ColorWheelsSectionView(viewModel: viewModel)
            case "Curves":
                curvesSection
            case "Effects":
                ColorEffectsSectionView(viewModel: viewModel)
            default:
                ColorBasicSectionView(viewModel: viewModel)
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var presetMixSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(String(localized: "THUỘC TÍNH MÀU SẮC LÕI"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)

                let intensityBinding = Binding<Double>(
                    get: { viewModel.liveNumber(for: "intensity", default: 1.0) },
                    set: { viewModel.updateLiveValue(key: "intensity", value: $0) }
                )
                DSSliderWithInput(
                    title: "Cường độ mẫu (Mix)",
                    value: intensityBinding,
                    range: 0.0...1.0,
                    step: 0.01,
                    defaultValue: 1.0,
                    unit: "%",
                    onEditingChanged: { editing in
                        viewModel.onSliderEditingChanged(key: "intensity", isEditing: editing)
                    }
                )

                let opacityBinding = Binding<Double>(
                    get: { viewModel.liveNumber(for: "opacity", default: 1.0) },
                    set: { viewModel.updateLiveValue(key: "opacity", value: $0) }
                )
                DSSliderWithInput(
                    title: "Độ mờ (Opacity)",
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
            .padding(DSSpacing.md)
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
        }
    }

    private var curvesSection: some View {
        let curvesBinding = Binding<ColorCurvesAdjustments>(
            get: { currentConfig.curves },
            set: { newValue in
                var cfg = currentConfig
                cfg.curves = newValue
                if let json = cfg.encodeToJSON() {
                    viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                }
            }
        )
        return ColorCurvesControlView(
            curves: curvesBinding,
            onEditingChanged: { editing in
                if !editing, let json = currentConfig.encodeToJSON() {
                    viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
                }
            }
        )
    }

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }
}
