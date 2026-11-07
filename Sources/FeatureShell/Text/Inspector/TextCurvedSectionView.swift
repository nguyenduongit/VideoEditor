import SwiftUI
import Domain
import DesignSystem

/// Subtab `"Curved"`: tinh chỉnh đường cong chuyên nghiệp trên vector CoreText (`Thẳng` / `Cung tròn Arc` / `Lượn sóng Wave`).
/// Bảo toàn trọn vẹn dấu tiếng Việt và Emoji trên mọi góc uốn `-360°...+360°`.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextCurvedSectionView: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedShape: TextCurveShape = .none

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "Đường cong văn bản (Curved Path)"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            shapePicker

            switch selectedShape {
            case .none:
                Text(String(localized: "Văn bản nằm trên đường cơ sở thẳng tiêu chuẩn."))
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                    .padding(.vertical, 2)
            case .arc:
                arcControls
                followTangentRow
            case .wave:
                waveControls
                followTangentRow
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
        .onAppear {
            selectedShape = currentConfig.curve.shape
        }
        .onChange(of: currentConfig.curve.shape) { _, newShape in
            if selectedShape != newShape { selectedShape = newShape }
        }
    }

    private var shapePicker: some View {
        HStack(spacing: 2) {
            curveShapeButton(shape: .none)
            curveShapeButton(shape: .arc)
            curveShapeButton(shape: .wave)
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func curveShapeButton(shape: TextCurveShape) -> some View {
        let isSelected = selectedShape == shape
        return Button(action: {
            selectedShape = shape
            var cfg = currentConfig
            cfg.curve.shape = shape
            if shape == .arc && abs(cfg.curve.angleDegrees) < 0.5 {
                cfg.curve.angleDegrees = 45.0
            }
            if shape == .wave && abs(cfg.curve.waveAmplitude) < 0.5 {
                cfg.curve.waveAmplitude = 24.0
            }
            updateConfig(cfg, commit: true)
        }) {
            HStack(spacing: 4) {
                Text(shape.displayName)
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

    private var arcControls: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Góc uốn cung tròn",
                value: Binding(
                    get: { currentConfig.curve.angleDegrees },
                    set: { val in
                        var cfg = currentConfig
                        cfg.curve.angleDegrees = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: -360.0...360.0,
                step: 1.0,
                defaultValue: 45.0,
                unit: "°",
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Tinh chỉnh bán kính",
                value: Binding(
                    get: { currentConfig.curve.radiusOffset },
                    set: { val in
                        var cfg = currentConfig
                        cfg.curve.radiusOffset = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: -200.0...300.0,
                step: 2.0,
                defaultValue: 0.0,
                unit: "pt",
                onEditingChanged: onSliderEditingEnded
            )
        }
    }

    private var waveControls: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSliderWithInput(
                title: "Biên độ sóng (Amplitude)",
                value: Binding(
                    get: { currentConfig.curve.waveAmplitude },
                    set: { val in
                        var cfg = currentConfig
                        cfg.curve.waveAmplitude = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: -120.0...120.0,
                step: 1.0,
                defaultValue: 24.0,
                unit: "pt",
                onEditingChanged: onSliderEditingEnded
            )

            DSSliderWithInput(
                title: "Bước sóng (Wavelength)",
                value: Binding(
                    get: { currentConfig.curve.wavelength },
                    set: { val in
                        var cfg = currentConfig
                        cfg.curve.wavelength = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: 60.0...800.0,
                step: 5.0,
                defaultValue: 240.0,
                unit: "pt",
                onEditingChanged: onSliderEditingEnded
            )
        }
    }

    private var followTangentRow: some View {
        DSToggleRow(
            title: "Xoay ký tự vuông góc theo tiếp tuyến",
            isOn: Binding(
                get: { currentConfig.curve.followTangent },
                set: { val in
                    var cfg = currentConfig
                    cfg.curve.followTangent = val
                    updateConfig(cfg, commit: true)
                }
            )
        )
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateConfig(_ config: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(config, commit: commit)
    }

    private func onSliderEditingEnded(isEditing: Bool) {
        if !isEditing {
            viewModel.updateTextConfiguration(currentConfig, commit: true)
        }
    }
}
