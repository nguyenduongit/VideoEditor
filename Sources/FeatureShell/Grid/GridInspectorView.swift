import SwiftUI
import Domain
import DesignSystem

/// Dedicated Inspector pane for the Video Grid tab.
/// Complies with R3.1, R8.1, and R8.2 of AGENTS.md.
public struct GridInspectorView: View {
    @Bindable var viewModel: InspectorViewModel

    @State private var localConfig: GridConfiguration = GridConfiguration(rows: 3, columns: 1)
    @State private var isDraggingSlider: Bool = false

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            headerInputsSection
            interactiveGridSection
            scaleSliderSection
        }
        .onAppear {
            loadConfigFromProperties()
        }
        .onChange(of: viewModel.liveProperties["gridConfig"]?.asString) { _, _ in
            if !isDraggingSlider {
                loadConfigFromProperties()
            }
        }
    }

    private var headerInputsSection: some View {
        HStack(spacing: DSSpacing.md) {
            rowsInputView
            columnsInputView
        }
    }

    private var rowsInputView: some View {
        let rowsBinding = Binding<Double>(
            get: { Double(localConfig.rows) },
            set: { newRows in
                let r = Int(newRows)
                GridSliceEngine.updateGridDimensions(config: &localConfig, rows: r, columns: localConfig.columns)
                commitConfig()
            }
        )
        return DSNumberInput(
            value: rowsBinding,
            step: 1,
            min: 1,
            max: 10,
            prefix: "Rows"
        )
    }

    private var columnsInputView: some View {
        let colsBinding = Binding<Double>(
            get: { Double(localConfig.columns) },
            set: { newCols in
                let c = Int(newCols)
                GridSliceEngine.updateGridDimensions(config: &localConfig, rows: localConfig.rows, columns: c)
                commitConfig()
            }
        )
        return DSNumberInput(
            value: colsBinding,
            step: 1,
            min: 1,
            max: 10,
            prefix: "Cols"
        )
    }

    private var interactiveGridSection: some View {
        VStack(spacing: DSSpacing.xs) {
            GridInteractiveSquareView(
                config: $localConfig,
                onCommit: { commitConfig() }
            )
            .onChange(of: localConfig) { _, _ in
                publishLiveConfig()
            }
        }
    }

    @ViewBuilder
    private var scaleSliderSection: some View {
        if let target = localConfig.selectedTarget {
            switch target {
            case .row(let r):
                if r >= 0, r < localConfig.rows {
                    rowScaleSlider(row: r)
                }
            case .column(let c):
                if c >= 0, c < localConfig.columns {
                    columnScaleSlider(col: c)
                }
            }
        }
    }

    private func rowScaleSlider(row: Int) -> some View {
        let binding = Binding<Double>(
            get: { localConfig.rowHeights[row] },
            set: { newH in
                GridSliceEngine.scaleRow(config: &localConfig, index: row, newHeight: newH)
                publishLiveConfig()
            }
        )
        return DSSliderWithInput(
            title: "Row \(row + 1) Height",
            value: binding,
            range: 0.05...2.5,
            step: 0.01,
            defaultValue: 1.0 / Double(localConfig.rows),
            unit: "%",
            onEditingChanged: { editing in
                isDraggingSlider = editing
                viewModel.onSliderEditingChanged(key: "gridConfig", isEditing: editing)
            }
        )
    }

    private func columnScaleSlider(col: Int) -> some View {
        let binding = Binding<Double>(
            get: { localConfig.colWidths[col] },
            set: { newW in
                GridSliceEngine.scaleColumn(config: &localConfig, index: col, newWidth: newW)
                publishLiveConfig()
            }
        )
        return DSSliderWithInput(
            title: "Column \(col + 1) Width",
            value: binding,
            range: 0.05...2.5,
            step: 0.01,
            defaultValue: 1.0 / Double(localConfig.columns),
            unit: "%",
            onEditingChanged: { editing in
                isDraggingSlider = editing
                viewModel.onSliderEditingChanged(key: "gridConfig", isEditing: editing)
            }
        )
    }

    private func loadConfigFromProperties() {
        if let json = viewModel.liveProperties["gridConfig"]?.asString,
           let decoded = GridConfiguration.decode(from: json) {
            localConfig = decoded
        } else {
            localConfig = GridConfiguration(rows: 3, columns: 1)
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
