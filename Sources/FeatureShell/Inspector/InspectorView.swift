import SwiftUI
import Domain
import DesignSystem

/// Dynamic Inspector Panel that renders editable property controls from descriptors.
/// Uses the topbar as the unified tab bar for all objects and removes redundant metadata blocks.
/// Complies with R6.2, R6.3, and R8.2 of AGENTS.md.
public struct InspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSBlockContainer {
            VStack(alignment: .leading, spacing: DSSpacing.none) {
                DSInspectorTabBar(
                    tabs: viewModel.availableTabs,
                    selectedTab: $viewModel.selectedTab,
                    fallbackTitle: "Tác vụ",
                    trailing: {
                        InspectorTopbarToastView(viewModel: viewModel.actionsPanelViewModel)
                    }
                )
                contentArea
            }
            .frame(width: DSSize.sidebarWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(width: DSSize.sidebarWidth)
        .onAppear {
            viewModel.syncWithSelection()
        }
        .onChange(of: viewModel.selectedClip?.id) {
            viewModel.syncWithSelection()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.selectedClip != nil {
            if viewModel.effectiveTab == "Animation" {
                TextAnimationTabContent(viewModel: viewModel)
            } else {
                DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                    if viewModel.selectedClip?.kind == .adjustment {
                        AdjustmentInspectorView(viewModel: viewModel)
                            .padding(.leading, DSSize.inspectorContentPadding)
                            .padding(.trailing, DSSpacing.md)
                            .padding(.vertical, DSSpacing.md)
                    } else if viewModel.effectiveTab == "Adjustment" {
                        UnifiedColorInspectorView(viewModel: viewModel)
                            .padding(.leading, DSSize.inspectorContentPadding)
                            .padding(.trailing, DSSpacing.md)
                            .padding(.vertical, DSSpacing.md)
                    } else if viewModel.selectedClip?.kind == .text || viewModel.effectiveTab == "Văn bản" || viewModel.effectiveTab == "Hiệu ứng" {
                        TextInspectorView(viewModel: viewModel)
                            .padding(.leading, DSSize.inspectorContentPadding)
                            .padding(.trailing, DSSpacing.md)
                            .padding(.vertical, DSSpacing.md)
                    } else if viewModel.effectiveTab == "AI" || viewModel.effectiveTab == "Grid" {
                        AIInspectorView(viewModel: viewModel)
                            .padding(.leading, DSSize.inspectorContentPadding)
                            .padding(.trailing, DSSpacing.md)
                            .padding(.vertical, DSSpacing.md)
                    } else {
                        propertyGroupsList
                            .padding(.leading, DSSize.inspectorContentPadding)
                            .padding(.trailing, DSSpacing.md)
                            .padding(.vertical, DSSpacing.md)
                    }
                }
            }
        } else {
            ActionsPanelView(viewModel: viewModel.actionsPanelViewModel)
        }
    }

    private var propertyGroupsList: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            if viewModel.groupedDescriptors.isEmpty {
                VStack(spacing: DSSpacing.sm) {
                    Spacer(minLength: 40)
                    Image(systemName: "square.dashed")
                        .font(.system(size: 26))
                        .foregroundStyle(DSColors.textSecondary.opacity(0.45))
                    Text("Tính năng \(viewModel.selectedTab) đang được phát triển")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.groupedDescriptors, id: \.group) { group in
                    DSCollapsibleSection(
                        title: group.group,
                        defaultExpanded: isGroupDefaultExpanded(group.group),
                        onReset: { viewModel.resetGroup(name: group.group) }
                    ) {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            ForEach(group.descriptors) { desc in
                                descriptorControl(for: desc)
                            }
                        }
                    }
                }
            }
        }
    }

    private func isGroupDefaultExpanded(_ groupName: String) -> Bool {
        if groupName == "Audio" && viewModel.selectedClip?.kind == .video {
            return false
        }
        return true
    }

    @ViewBuilder
    private func descriptorControl(for desc: PropertyDescriptor) -> some View {
        switch desc.control {
        case .slider(let min, let max, let step, let unit):
            sliderRow(desc: desc, min: min, max: max, step: step, unit: unit)
        case .toggle:
            toggleRow(desc: desc)
        case .position2D(let xID, let yID, let step):
            positionRow(desc: desc, xID: xID, yID: yID, step: step)
        case .rotation(_, _, let step):
            rotationRow(desc: desc, step: step)
        case .numberField(_, _, let step, let unit, _):
            numberFieldRow(desc: desc, step: step, unit: unit)
        case .textField:
            textFieldRow(desc: desc)
        case .picker(let options):
            pickerRow(desc: desc, options: options)
        }
    }

    private func sliderRow(desc: PropertyDescriptor, min: Double, max: Double, step: Double, unit: String?) -> some View {
        let valueBinding = Binding<Double>(
            get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? min) },
            set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
        )
        return DSSliderWithInput(
            title: desc.title,
            value: valueBinding,
            range: min...max,
            step: step,
            defaultValue: desc.defaultValue.asNumber,
            unit: unit,
            onEditingChanged: { isEditing in
                viewModel.onSliderEditingChanged(key: desc.id, isEditing: isEditing)
            }
        )
    }

    private func toggleRow(desc: PropertyDescriptor) -> some View {
        let boolBinding = Binding<Bool>(
            get: { viewModel.liveBool(for: desc.id, default: desc.defaultValue.asBool ?? false) },
            set: { viewModel.updateLiveBool(key: desc.id, value: $0) }
        )
        return DSToggleRow(
            title: desc.title,
            isOn: boolBinding
        )
    }

    private func positionRow(desc: PropertyDescriptor, xID: String, yID: String, step: Double) -> some View {
        let isAutoPanActive = viewModel.isAutoPanActive && (xID == "positionX")
        let xBinding = Binding<Double>(
            get: { isAutoPanActive ? 0.0 : viewModel.liveNumber(for: xID, default: 0.0) },
            set: { viewModel.updateLiveValue(key: xID, value: $0) }
        )
        let yBinding = Binding<Double>(
            get: { viewModel.liveNumber(for: yID, default: 0.0) },
            set: { viewModel.updateLiveValue(key: yID, value: $0) }
        )
        return DSPositionControl(
            title: desc.title,
            xValue: xBinding,
            yValue: yBinding,
            step: step,
            isXDisabled: isAutoPanActive,
            onEditingChanged: { isEditing in
                viewModel.onSliderEditingChanged(key: desc.id, isEditing: isEditing)
            }
        )
    }

    private func rotationRow(desc: PropertyDescriptor, step: Double) -> some View {
        let rotBinding = Binding<Double>(
            get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? 0.0) },
            set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
        )
        return DSRotationControl(
            title: desc.title,
            angle: rotBinding,
            step: step,
            onEditingChanged: { isEditing in
                viewModel.onSliderEditingChanged(key: desc.id, isEditing: isEditing)
            }
        )
    }

    private func numberFieldRow(desc: PropertyDescriptor, step: Double?, unit: String?) -> some View {
        let valueBinding = Binding<Double>(
            get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? 0) },
            set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
        )
        return DSNumberField(
            title: desc.title,
            value: valueBinding,
            step: step ?? 1,
            unit: unit ?? "px",
            onEditingChanged: { isEditing in
                viewModel.onSliderEditingChanged(key: desc.id, isEditing: isEditing)
            }
        )
    }

    private func textFieldRow(desc: PropertyDescriptor) -> some View {
        let textBinding = Binding<String>(
            get: { viewModel.liveString(for: desc.id, default: desc.defaultValue.asString ?? "") },
            set: { viewModel.updateLiveText(key: desc.id, text: $0) }
        )
        return DSTextField(
            title: desc.title,
            text: textBinding,
            onCommit: {
                viewModel.commitTextProperty(key: desc.id, text: textBinding.wrappedValue)
            }
        )
    }

    private func pickerRow(desc: PropertyDescriptor, options: [PickerOption]) -> some View {
        let stringBinding = Binding<String>(
            get: { viewModel.liveString(for: desc.id, default: desc.defaultValue.asString ?? "") },
            set: { viewModel.updateDiscreteString(key: desc.id, value: $0) }
        )
        let dsOptions = options.map { DSPickerOption(id: $0.id, title: $0.title, iconName: $0.iconName) }
        return DSPickerRow(
            title: desc.title,
            selectedID: stringBinding,
            options: dsOptions
        )
    }
}
