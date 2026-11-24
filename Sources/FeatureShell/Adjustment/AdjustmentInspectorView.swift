import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector chuyên dụng cho Adjustment Layer.
/// Hiển thị trực tiếp 5 tab con: Basic, HSL, Wheels, Curves, Effects.
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Ubiquitous Language, Hàm <= 50 dòng, Body <= 40 dòng).
public struct AdjustmentInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            presetActionsBlock

            switch viewModel.effectiveTab {
            case "Basic":
                AdjustmentBasicSectionView(viewModel: viewModel)
            case "HSL":
                AdjustmentHSLSectionView(viewModel: viewModel)
            case "Wheels":
                AdjustmentWheelsSectionView(viewModel: viewModel)
            case "Curves":
                curvesSection
            case "Effects":
                AdjustmentEffectsSectionView(viewModel: viewModel)
            default:
                AdjustmentBasicSectionView(viewModel: viewModel)
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    @ViewBuilder
    private var presetActionsBlock: some View {
        if viewModel.effectiveTab == "Basic", viewModel.selectedClip?.originPresetID != nil {
            presetMixSection
        }
    }

    private var presetMixSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "CORE COLOR PROPERTIES"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            let intensityBinding = Binding<Double>(
                get: { viewModel.liveNumber(for: "intensity", default: 1.0) },
                set: { viewModel.updateLiveValue(key: "intensity", value: $0) }
            )
            DSSliderWithInput(
                title: "Preset Intensity (Mix)",
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
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
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
