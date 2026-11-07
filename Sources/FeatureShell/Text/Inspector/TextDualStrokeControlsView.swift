import SwiftUI
import Domain
import DesignSystem

/// Subtab `"Stroke"`: tinh chỉnh độc lập 2 đường viền đối xứng (`Stroke 1 - Viền trong` & `Stroke 2 - Viền ngoài`),
/// hỗ trợ cả màu đơn sắc lẫn dải chuyển màu tuyến tính (`Linear Gradient`).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextDualStrokeControlsView: View {
    private var viewModel: InspectorViewModel?
    private let fallbackConfig: TextConfiguration
    private let fallbackOnUpdate: ((TextConfiguration, Bool) -> Void)?
    @State private var innerFillMode: TextColorFillMode
    @State private var outerFillMode: TextColorFillMode

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
        let cfg = viewModel.textConfiguration
        self.fallbackConfig = cfg
        self.fallbackOnUpdate = nil
        self._innerFillMode = State(initialValue: cfg.innerStroke.fillMode)
        self._outerFillMode = State(initialValue: cfg.outerStroke.fillMode)
    }

    public init(
        config: TextConfiguration,
        onUpdate: @escaping (TextConfiguration, Bool) -> Void
    ) {
        self.viewModel = nil
        self.fallbackConfig = config
        self.fallbackOnUpdate = onUpdate
        self._innerFillMode = State(initialValue: config.innerStroke.fillMode)
        self._outerFillMode = State(initialValue: config.outerStroke.fillMode)
    }

    private var currentConfig: TextConfiguration {
        viewModel?.textConfiguration ?? fallbackConfig
    }

    private func updateConfig(_ updated: TextConfiguration, commit: Bool) {
        if let viewModel {
            viewModel.updateTextConfiguration(updated, commit: commit)
        } else {
            fallbackOnUpdate?(updated, commit)
        }
    }

    public var body: some View {
        let cfg = currentConfig
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            strokeCard(
                title: "Stroke 1 (Inner Stroke)",
                isInner: true,
                stroke: cfg.innerStroke,
                selectedFillMode: $innerFillMode,
                defaultWidth: 0.0,
                maxWidth: 30.0
            )

            strokeCard(
                title: "Stroke 2 (Outer Stroke)",
                isInner: false,
                stroke: cfg.outerStroke,
                selectedFillMode: $outerFillMode,
                defaultWidth: 0.0,
                maxWidth: 45.0
            )
        }
        .onAppear {
            let live = currentConfig
            innerFillMode = live.innerStroke.fillMode
            outerFillMode = live.outerStroke.fillMode
        }
        .onChange(of: currentConfig.innerStroke.fillMode) { _, newMode in
            if innerFillMode != newMode { innerFillMode = newMode }
        }
        .onChange(of: currentConfig.outerStroke.fillMode) { _, newMode in
            if outerFillMode != newMode { outerFillMode = newMode }
        }
    }

    private func readStroke(isInner: Bool) -> TextStrokeStyle {
        isInner ? currentConfig.innerStroke : currentConfig.outerStroke
    }

    private func applyStroke(_ updated: TextStrokeStyle, isInner: Bool, commit: Bool) {
        var u = currentConfig
        var s = updated
        s.isEnabled = true
        if isInner {
            u.innerStroke = s
        } else {
            u.outerStroke = s
        }
        updateConfig(u, commit: commit)
    }

    private func strokeCard(
        title: String,
        isInner: Bool,
        stroke: TextStrokeStyle,
        selectedFillMode: Binding<TextColorFillMode>,
        defaultWidth: Double,
        maxWidth: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                DSSliderWithInput(
                    title: "Width",
                    value: Binding(
                        get: { readStroke(isInner: isInner).width },
                        set: { val in
                            var s = readStroke(isInner: isInner)
                            s.isEnabled = true
                            s.width = val
                            applyStroke(s, isInner: isInner, commit: false)
                        }
                    ),
                    range: 0.0...maxWidth,
                    step: 0.5,
                    defaultValue: defaultWidth,
                    unit: "pt",
                    onEditingChanged: { if !$0 { applyStroke(readStroke(isInner: isInner), isInner: isInner, commit: true) } }
                )

                strokeFillModeSegmentBar(
                    isInner: isInner,
                    selectedFillMode: selectedFillMode
                )

                if selectedFillMode.wrappedValue == .solid {
                    TextColorSwatchesRow(
                        title: "Color",
                        selectedHex: stroke.colorHex,
                        allowNone: true
                    ) { hex in
                        var s = readStroke(isInner: isInner)
                        s.isEnabled = true
                        s.colorHex = hex.uppercased() == "NONE" ? "NONE" : hex
                        s.fillMode = .solid
                        applyStroke(s, isInner: isInner, commit: true)
                    }
                } else {
                    gradientControls(isInner: isInner, stroke: stroke)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private func strokeFillModeSegmentBar(
        isInner: Bool,
        selectedFillMode: Binding<TextColorFillMode>
    ) -> some View {
        HStack(spacing: 2) {
            strokeFillTabButton(
                mode: .solid,
                isInner: isInner,
                selectedFillMode: selectedFillMode
            )
            strokeFillTabButton(
                mode: .linearGradient,
                isInner: isInner,
                selectedFillMode: selectedFillMode
            )
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func strokeFillTabButton(
        mode: TextColorFillMode,
        isInner: Bool,
        selectedFillMode: Binding<TextColorFillMode>
    ) -> some View {
        let isSelected = selectedFillMode.wrappedValue == mode
        return Button(action: {
            selectedFillMode.wrappedValue = mode
            var s = readStroke(isInner: isInner)
            s.fillMode = mode
            if mode == .linearGradient && s.gradientColors.count < 2 {
                s.gradientColors = ["#FFD700", "#FF2A85"]
            }
            applyStroke(s, isInner: isInner, commit: true)
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

    private func gradientControls(
        isInner: Bool,
        stroke: TextStrokeStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            let start = stroke.gradientColors.first ?? "#FFD700"
            let end = stroke.gradientColors.count > 1 ? stroke.gradientColors[1] : "#FF2A85"

            TextColorSwatchesRow(title: "Gradient Start", selectedHex: start, allowNone: true) { hex in
                var s = readStroke(isInner: isInner)
                let curEnd = s.gradientColors.count > 1 ? s.gradientColors[1] : "#FF2A85"
                s.fillMode = .linearGradient
                s.gradientColors = [hex, curEnd]
                applyStroke(s, isInner: isInner, commit: true)
            }
            TextColorSwatchesRow(title: "Gradient End", selectedHex: end, allowNone: true) { hex in
                var s = readStroke(isInner: isInner)
                let curStart = s.gradientColors.first ?? "#FFD700"
                s.fillMode = .linearGradient
                s.gradientColors = [curStart, hex]
                applyStroke(s, isInner: isInner, commit: true)
            }
            DSSliderWithInput(
                title: "Gradient Angle",
                value: Binding(
                    get: { readStroke(isInner: isInner).gradientAngle },
                    set: { val in
                        var s = readStroke(isInner: isInner)
                        s.gradientAngle = val
                        applyStroke(s, isInner: isInner, commit: false)
                    }
                ),
                range: 0.0...360.0,
                step: 1.0,
                defaultValue: 90.0,
                unit: "°",
                onEditingChanged: { if !$0 { applyStroke(readStroke(isInner: isInner), isInner: isInner, commit: true) } }
            )
        }
    }
}
