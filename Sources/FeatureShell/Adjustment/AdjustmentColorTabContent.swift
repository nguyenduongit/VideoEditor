import SwiftUI
import Domain
import DesignSystem

/// Tab Color chuyên sâu cho Adjustment Layer gồm Bánh xe màu (Color Wheels) và Đường cong (Curves).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentColorTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: SubTab = .wheels
    @State private var selectedWheelMode: WheelMode = .shadows

    private enum SubTab: String, CaseIterable {
        case wheels = "Bánh xe màu"
        case curves = "Đường cong"
    }

    private enum WheelMode: String, CaseIterable {
        case shadows = "Shadows"
        case midtones = "Midtones"
        case highlights = "Highlights"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            subTabBar

            if selectedSubTab == .wheels {
                wheelsSection
            } else {
                curvesSection
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

    private var wheelsSection: some View {
        VStack(spacing: DSSpacing.md) {
            // Thanh chuyển nhanh giữa 3 bánh xe Lift / Gamma / Gain
            HStack(spacing: 4) {
                ForEach(WheelMode.allCases, id: \.self) { mode in
                    Button(action: { selectedWheelMode = mode }) {
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: selectedWheelMode == mode ? .semibold : .regular))
                            .foregroundStyle(selectedWheelMode == mode ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedWheelMode == mode ? Color.white.opacity(0.12) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            switch selectedWheelMode {
            case .shadows:
                ColorWheelControlView(
                    title: "Lift (Vùng tối)",
                    offset: wheelBinding(\.lift),
                    onEditingChanged: onEditingEnded
                )
            case .midtones:
                ColorWheelControlView(
                    title: "Gamma (Vùng trung)",
                    offset: wheelBinding(\.gamma),
                    onEditingChanged: onEditingEnded
                )
            case .highlights:
                ColorWheelControlView(
                    title: "Gain (Vùng sáng)",
                    offset: wheelBinding(\.gain),
                    onEditingChanged: onEditingEnded
                )
            }
        }
    }

    private var curvesSection: some View {
        ColorCurvesControlView(
            curves: curvesBinding,
            onEditingChanged: onEditingEnded
        )
    }

    // MARK: - State & Bindings

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }

    private func wheelBinding(_ keyPath: WritableKeyPath<ColorWheelsAdjustments, ColorWheelOffset>) -> Binding<ColorWheelOffset> {
        Binding(
            get: { currentConfig.wheels[keyPath: keyPath] },
            set: { newValue in
                var cfg = currentConfig
                cfg.wheels[keyPath: keyPath] = newValue
                if let json = cfg.encodeToJSON() {
                    viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                }
            }
        )
    }

    private var curvesBinding: Binding<ColorCurvesAdjustments> {
        Binding(
            get: { currentConfig.curves },
            set: { newValue in
                var cfg = currentConfig
                cfg.curves = newValue
                if let json = cfg.encodeToJSON() {
                    viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                }
            }
        )
    }

    private func onEditingEnded(isEditing: Bool) {
        if !isEditing, let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }
}
