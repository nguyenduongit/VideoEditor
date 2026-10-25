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
