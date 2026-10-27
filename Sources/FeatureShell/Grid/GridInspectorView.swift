import SwiftUI
import Domain
import DesignSystem

/// Dedicated 3-Zone Body Proportion / Leg Stretch controls embedded inside the AI tab accordion.
/// Complies with R3.1, R8.1, and R8.2 of AGENTS.md.
public typealias LegStretchInspectorView = GridInspectorView

public struct GridInspectorView: View {
    @Bindable var viewModel: InspectorViewModel

    @State private var localConfig: GridConfiguration = GridConfiguration(
        rows: 3,
        columns: 1,
        isEnabled: false,
        legStretchRatio: 1.0,
        isDynamicLines: true
    )
    @State private var isDraggingSlider: Bool = false

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var autoPanKeyframes: [AutoPanKeyframe] {
        if let live = viewModel.liveProperties["autoPanConfig"]?.asString,
           let config = AutoPanConfiguration.decode(from: live) {
            return config.keyframes
        }
        if let prop = viewModel.selectedClip?.properties["autoPanConfig"]?.asString,
           let config = AutoPanConfiguration.decode(from: prop) {
            return config.keyframes
        }
        return []
    }

    private var hasVisionBodyLines: Bool {
        autoPanKeyframes.contains { $0.waistY != nil && $0.ankleY != nil }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            legStretchToggleRow

            Group {
                dynamicLinesToggleRow
                legStretchRatioSlider
                waistLineSlider
                ankleLineSlider
                descriptionNote
            }
            .opacity(localConfig.isEnabled ? 1.0 : 0.45)
            .disabled(!localConfig.isEnabled)
        }
        .onAppear {
            loadConfigFromProperties()
        }
        .onChange(of: viewModel.selectedClip?.properties["autoPanConfig"]) {
            loadConfigFromProperties()
        }
        .onChange(of: viewModel.liveProperties["gridConfig"]?.asString) { _, _ in
            if !isDraggingSlider {
                loadConfigFromProperties()
            }
        }
    }

    private var legStretchToggleRow: some View {
        let binding = Binding<Bool>(
            get: { localConfig.isEnabled },
            set: { newValue in
                localConfig.isEnabled = newValue
                if newValue {
                    if abs(localConfig.legStretchRatio - 1.0) < 0.001 {
                        GridSliceEngine.applyLegStretch(config: &localConfig, ratio: 1.10)
                    }
                    if let lines = AutoPanEngine.representativeBodyLines(from: autoPanKeyframes) {
                        localConfig.isDynamicLines = true
                        GridSliceEngine.setBodyLines(config: &localConfig, waistY: lines.waistY, ankleY: lines.ankleY)
                    }
                }
                commitConfig()
            }
        )
        return DSToggleRow(title: "Bật kéo dài chân", isOn: binding)
    }

    private var dynamicLinesToggleRow: some View {
        let binding = Binding<Bool>(
            get: { localConfig.isDynamicLines },
            set: { newValue in
                localConfig.isDynamicLines = newValue
                if newValue, let lines = AutoPanEngine.representativeBodyLines(from: autoPanKeyframes) {
                    GridSliceEngine.setBodyLines(config: &localConfig, waistY: lines.waistY, ankleY: lines.ankleY)
                }
                commitConfig()
            }
        )
        return DSToggleRow(title: "Tự động bám tiến/lùi (AI)", isOn: binding)
    }

    private var legStretchRatioSlider: some View {
        let binding = Binding<Double>(
            get: { localConfig.legStretchRatio },
            set: { newRatio in
                GridSliceEngine.applyLegStretch(config: &localConfig, ratio: newRatio)
                publishLiveConfig()
            }
        )
        return DSSliderWithInput(
            title: "Hệ số kéo dài",
            value: binding,
            range: GridSliceEngine.minLegStretchRatio...GridSliceEngine.maxLegStretchRatio,
            step: 0.01,
            defaultValue: 1.0,
            unit: "x",
            onEditingChanged: { editing in
                isDraggingSlider = editing
                viewModel.onSliderEditingChanged(key: "gridConfig", isEditing: editing)
            }
        )
    }

    private var waistLineSlider: some View {
        let binding = Binding<Double>(
            get: { localConfig.rowDividers.first ?? (1.0 / 3.0) },
            set: { newY in
                localConfig.isDynamicLines = false
                GridSliceEngine.moveHorizontalDivider(config: &localConfig, lineIndex: 0, newY: newY)
                publishLiveConfig()
            }
        )
        return DSSliderWithInput(
            title: "Line Thắt lưng",
            value: binding,
            range: 0.08...0.80,
            step: 0.01,
            defaultValue: 1.0 / 3.0,
            unit: "%",
            onEditingChanged: { editing in
                isDraggingSlider = editing
                viewModel.onSliderEditingChanged(key: "gridConfig", isEditing: editing)
            }
        )
    }

    private var ankleLineSlider: some View {
        let binding = Binding<Double>(
            get: { localConfig.rowDividers.count > 1 ? localConfig.rowDividers[1] : (2.0 / 3.0) },
            set: { newY in
                localConfig.isDynamicLines = false
                GridSliceEngine.moveHorizontalDivider(config: &localConfig, lineIndex: 1, newY: newY)
                publishLiveConfig()
            }
        )
        return DSSliderWithInput(
            title: "Line Mắt cá",
            value: binding,
            range: 0.20...0.95,
            step: 0.01,
            defaultValue: 2.0 / 3.0,
            unit: "%",
            onEditingChanged: { editing in
                isDraggingSlider = editing
                viewModel.onSliderEditingChanged(key: "gridConfig", isEditing: editing)
            }
        )
    }

    private var descriptionNote: some View {
        Text(hasVisionBodyLines && localConfig.isDynamicLines
             ? "2 đường Thắt lưng & Mắt cá đang tự động trượt mượt theo bước tiến/lùi của nhân vật với hệ số kéo dài không đổi (0.9x – 1.3x)."
             : "Chia khung hình thành 3 khối ngang (Thân trên - Chân - Mặt đất) và điều chỉnh chiều cao khối giữa trong khoảng 0.9x – 1.3x.")
            .font(.system(size: 11))
            .foregroundStyle(DSColors.textSecondary)
            .lineSpacing(2)
    }

    private func loadConfigFromProperties() {
        if let json = viewModel.liveProperties["gridConfig"]?.asString ?? viewModel.selectedClip?.properties["gridConfig"]?.asString,
           let decoded = GridConfiguration.decode(from: json) {
            localConfig = decoded
        } else {
            localConfig = GridConfiguration(rows: 3, columns: 1, isEnabled: false, legStretchRatio: 1.0, isDynamicLines: true)
        }
    }

    private func publishLiveConfig() {
        if let json = localConfig.encodeToString() {
            viewModel.updateLiveText(key: "gridConfig", text: json)
        }
    }

    private func commitConfig() {
        if let json = localConfig.encodeToString() {
            viewModel.updateDiscreteString(key: "gridConfig", value: json)
        }
    }
}
