import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Bánh xe màu 3 vùng: Lift (Shadows), Gamma (Midtones), Gain (Highlights).
/// Đặt tên 100% bằng tiếng Anh ngắn gọn, không lồng subtab.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct ColorWheelsSectionView: View {
    @Bindable var viewModel: InspectorViewModel
    @State private var selectedWheelMode: WheelMode = .shadows

    private enum WheelMode: String, CaseIterable {
        case shadows = "Shadows"
        case midtones = "Midtones"
        case highlights = "Highlights"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            wheelModePicker

            switch selectedWheelMode {
            case .shadows:
                ColorWheelControlView(
                    title: "Lift (Shadows)",
                    offset: wheelBinding(\.lift),
                    onEditingChanged: onWheelEditingEnded
                )
            case .midtones:
                ColorWheelControlView(
                    title: "Gamma (Midtones)",
                    offset: wheelBinding(\.gamma),
                    onEditingChanged: onWheelEditingEnded
                )
            case .highlights:
                ColorWheelControlView(
                    title: "Gain (Highlights)",
                    offset: wheelBinding(\.gain),
                    onEditingChanged: onWheelEditingEnded
                )
            }
        }
    }

    private var wheelModePicker: some View {
        HStack(spacing: 2) {
            ForEach(WheelMode.allCases, id: \.self) { mode in
                Button(action: { selectedWheelMode = mode }) {
                    Text(mode.rawValue)
                        .font(.system(size: 11, weight: selectedWheelMode == mode ? .semibold : .regular))
                        .foregroundStyle(selectedWheelMode == mode ? DSColors.textPrimary : DSColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(selectedWheelMode == mode ? DSColors.windowBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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

    private func onWheelEditingEnded(isEditing: Bool) {
        if !isEditing, let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }
}
