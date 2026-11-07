import SwiftUI
import Domain
import DesignSystem

/// Khối điều chỉnh Chế độ tô màu văn bản (`Solid` đơn sắc & `Linear Gradient` dải chuyển màu).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextFillModeControlsView: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedMode: TextColorFillMode = .solid

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
        self._selectedMode = State(initialValue: viewModel.textConfiguration.colorFillMode)
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ updated: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(updated, commit: commit)
    }

    public var body: some View {
        let cfg = currentConfig
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            modePicker(cfg: cfg)
            switch selectedMode {
            case .solid:
                solidColorControls(cfg: cfg)
            case .linearGradient:
                gradientFillControls(cfg: cfg)
            }
        }
        .onAppear {
            selectedMode = currentConfig.colorFillMode
        }
        .onChange(of: currentConfig.colorFillMode) { _, newMode in
            if selectedMode != newMode {
                selectedMode = newMode
            }
        }
    }

    private func modePicker(cfg: TextConfiguration) -> some View {
        HStack(spacing: 2) {
            fillModeTabButton(mode: .solid)
            fillModeTabButton(mode: .linearGradient)
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func fillModeTabButton(mode: TextColorFillMode) -> some View {
        let isSelected = selectedMode == mode
        return Button(action: {
            selectedMode = mode
            var u = currentConfig
            u.colorFillMode = mode
            if mode == .linearGradient && u.gradientColors.count < 2 {
                u.gradientColors = ["#FF2A85", "#FDE047"]
            }
            updateConfig(u, commit: true)
        }) {
            HStack(spacing: 4) {
                Text(mode.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isSelected ? DSColors.windowBackground : Color.white.opacity(0.001))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func solidColorControls(cfg: TextConfiguration) -> some View {
        TextColorSwatchesRow(
            title: cfg.textColorHex.uppercased() == "NONE"
                ? "Chữ rỗng (chỉ hiện đường viền Stroke)"
                : "Màu chữ",
            selectedHex: cfg.textColorHex,
            allowNone: true,
            showCustomPicker: true
        ) { hex in
            var u = currentConfig
            u.colorFillMode = .solid
            u.textColorHex = hex
            updateConfig(u, commit: true)
        }
    }

    private func gradientFillControls(cfg: TextConfiguration) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            let startColor = cfg.gradientColors.first ?? "#FF2A85"
            let endColor = cfg.gradientColors.count > 1 ? cfg.gradientColors[1] : "#FDE047"

            TextColorSwatchesRow(title: "Màu đầu Gradient", selectedHex: startColor) { hex in
                var u = currentConfig
                let end = u.gradientColors.count > 1 ? u.gradientColors[1] : "#FDE047"
                u.colorFillMode = .linearGradient
                u.gradientColors = [hex, end]
                updateConfig(u, commit: true)
            }

            TextColorSwatchesRow(title: "Màu cuối Gradient", selectedHex: endColor) { hex in
                var u = currentConfig
                let start = u.gradientColors.first ?? "#FF2A85"
                u.colorFillMode = .linearGradient
                u.gradientColors = [start, hex]
                updateConfig(u, commit: true)
            }

            DSSliderWithInput(
                title: "Góc nghiêng Gradient",
                value: Binding(
                    get: { currentConfig.gradientAngle },
                    set: { val in
                        var u = currentConfig
                        u.gradientAngle = val
                        updateConfig(u, commit: false)
                    }
                ),
                range: 0.0...360.0,
                step: 1.0,
                defaultValue: 90.0,
                unit: "°",
                onEditingChanged: { if !$0 { updateConfig(currentConfig, commit: true) } }
            )
        }
    }
}
