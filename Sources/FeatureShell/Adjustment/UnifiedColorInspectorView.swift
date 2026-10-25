import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển màu hợp nhất (Unified Color Inspector) với 1 cấp subtab phẳng duy nhất.
/// Áp dụng chung cho cả Video Clip và Adjustment Layer.
/// Đặt tên 100% bằng tiếng Anh: [ Basic ] [ HSL ] [ Wheels ] [ Curves ] [ Effects ].
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct UnifiedColorInspectorView: View {
    @Bindable var viewModel: InspectorViewModel
    @State private var selectedSubTab: ColorSubTab = .basic

    public enum ColorSubTab: String, CaseIterable {
        case basic = "Basic"
        case hsl = "HSL"
        case wheels = "Wheels"
        case curves = "Curves"
        case effects = "Effects"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            enableAdjustmentCheckbox

            flatSubTabBar
                .opacity(currentConfig.isEnabled ? 1.0 : 0.45)
                .disabled(!currentConfig.isEnabled)

            Group {
                switch selectedSubTab {
                case .basic:
                    ColorBasicSectionView(viewModel: viewModel)
                case .hsl:
                    AdjustmentHSLTabContent(viewModel: viewModel)
                case .wheels:
                    ColorWheelsSectionView(viewModel: viewModel)
                case .curves:
                    curvesSection
                case .effects:
                    ColorEffectsSectionView(viewModel: viewModel)
                }
            }
            .opacity(currentConfig.isEnabled ? 1.0 : 0.45)
            .disabled(!currentConfig.isEnabled)
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var enableAdjustmentCheckbox: some View {
        let isEnabled = currentConfig.isEnabled
        return Button {
            var cfg = currentConfig
            cfg.isEnabled.toggle()
            if let json = cfg.encodeToJSON() {
                viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
            }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEnabled ? DSColors.toggleCyan : DSColors.textSecondary)

                Text("Enable Adjustment")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isEnabled ? DSColors.textPrimary : DSColors.textSecondary)

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var flatSubTabBar: some View {
        HStack(spacing: 2) {
            ForEach(ColorSubTab.allCases, id: \.self) { tab in
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
