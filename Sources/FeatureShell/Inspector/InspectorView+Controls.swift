import SwiftUI
import Domain
import DesignSystem

extension InspectorView {
    @ViewBuilder
    func descriptorControl(for desc: PropertyDescriptor) -> some View {
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
        case .dropdown(let options):
            dropdownRow(desc: desc, options: options)
        case .flip(let horizontalID, let verticalID):
            flipRow(desc: desc, horizontalID: horizontalID, verticalID: verticalID)
        }
    }

    private func sliderRow(desc: PropertyDescriptor, min: Double, max: Double, step: Double, unit: String?) -> some View {
        let valueBinding = Binding<Double>(
            get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? min) },
            set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
        )
        let isVolume = desc.id == "volume"
        let kfKeys = viewModel.keyframeKeys(for: desc)
        return DSSliderWithInput(
            title: desc.title,
            value: valueBinding,
            range: min...max,
            step: step,
            defaultValue: desc.defaultValue.asNumber,
            unit: unit,
            leadingIcon: isVolume ? viewModel.volumeLeadingIcon : nil,
            isLeadingIconActive: isVolume && viewModel.isVolumeMuted,
            leadingIconHelp: isVolume ? viewModel.volumeLeadingIconHelp : nil,
            isDimmed: isVolume && viewModel.isSelectedClipLayerMuted,
            trailingAccessory: keyframeAccessory(for: kfKeys, defaultVal: desc.defaultValue.asNumber),
            onLeadingIconTap: isVolume ? { viewModel.toggleVolumeMute() } : nil,
            onEditingChanged: { isEditing in
                viewModel.onSliderEditingChanged(key: desc.id, isEditing: isEditing)
            }
        )
    }

    private func toggleRow(desc: PropertyDescriptor) -> some View {
        DSToggleRow(
            title: desc.title,
            isOn: Binding(
                get: { viewModel.liveBool(for: desc.id, default: desc.defaultValue.asBool ?? false) },
                set: { viewModel.updateLiveBool(key: desc.id, value: $0) }
            )
        )
    }

    private func positionRow(desc: PropertyDescriptor, xID: String, yID: String, step: Double) -> some View {
        let isAutoPanActive = viewModel.isAutoPanActive && (xID == "positionX")
        return DSPositionControl(
            title: desc.title,
            xValue: Binding(
                get: { isAutoPanActive ? 0.0 : viewModel.liveNumber(for: xID, default: 0.0) },
                set: { viewModel.updateLiveValue(key: xID, value: $0) }
            ),
            yValue: Binding(
                get: { viewModel.liveNumber(for: yID, default: 0.0) },
                set: { viewModel.updateLiveValue(key: yID, value: $0) }
            ),
            step: step,
            isXDisabled: isAutoPanActive,
            trailingAccessory: keyframeAccessory(for: viewModel.keyframeKeys(for: desc)),
            onEditingChanged: { viewModel.onSliderEditingChanged(key: desc.id, isEditing: $0) }
        )
    }

    private func rotationRow(desc: PropertyDescriptor, step: Double) -> some View {
        DSRotationControl(
            title: desc.title,
            angle: Binding(
                get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? 0.0) },
                set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
            ),
            step: step,
            trailingAccessory: keyframeAccessory(for: viewModel.keyframeKeys(for: desc), defaultVal: desc.defaultValue.asNumber),
            onEditingChanged: { viewModel.onSliderEditingChanged(key: desc.id, isEditing: $0) }
        )
    }

    func keyframeAccessory(for keys: [String], defaultVal: Double? = nil) -> AnyView? {
        guard !keys.isEmpty else { return nil }
        var defaults: [String: Double] = [:]
        if let defaultVal, keys.count == 1 {
            defaults[keys[0]] = defaultVal
        }
        return AnyView(
            DSKeyframeControl(
                hasKeyframesOnTrack: viewModel.hasKeyframes(for: keys),
                isAtKeyframe: viewModel.hasKeyframeAtPlayhead(for: keys),
                canGoPrevious: viewModel.canJumpToPreviousKeyframe(for: keys),
                canGoNext: viewModel.canJumpToNextKeyframe(for: keys),
                selectedCurveID: viewModel.activeInterpolation(for: keys).rawValue,
                curveOptions: viewModel.keyframeCurveOptions,
                onToggleKeyframe: { viewModel.toggleKeyframe(for: keys, defaultValues: defaults) },
                onPreviousKeyframe: { viewModel.jumpToPreviousKeyframe(for: keys) },
                onNextKeyframe: { viewModel.jumpToNextKeyframe(for: keys) },
                onSelectCurve: { curveID in
                    if let interp = KeyframeInterpolation(rawValue: curveID) {
                        viewModel.setInterpolation(interp, for: keys)
                    }
                },
                onClearAllKeyframes: { viewModel.clearAllKeyframes(for: keys) }
            )
        )
    }

    private func numberFieldRow(desc: PropertyDescriptor, step: Double?, unit: String?) -> some View {
        DSNumberField(
            title: desc.title,
            value: Binding(
                get: { viewModel.liveNumber(for: desc.id, default: desc.defaultValue.asNumber ?? 0) },
                set: { viewModel.updateLiveValue(key: desc.id, value: $0) }
            ),
            step: step ?? 1,
            unit: unit ?? "px",
            onEditingChanged: { viewModel.onSliderEditingChanged(key: desc.id, isEditing: $0) }
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
            onCommit: { viewModel.commitTextProperty(key: desc.id, text: textBinding.wrappedValue) }
        )
    }

    private func pickerRow(desc: PropertyDescriptor, options: [PickerOption]) -> some View {
        DSPickerRow(
            title: desc.title,
            selectedID: Binding(
                get: { viewModel.liveString(for: desc.id, default: desc.defaultValue.asString ?? "") },
                set: { viewModel.updateDiscreteString(key: desc.id, value: $0) }
            ),
            options: options.map { DSPickerOption(id: $0.id, title: $0.title, iconName: $0.iconName) }
        )
    }

    private func dropdownRow(desc: PropertyDescriptor, options: [PickerOption]) -> some View {
        let currentID = viewModel.liveString(for: desc.id, default: desc.defaultValue.asString ?? "")
        let currentTitle = options.first(where: { $0.id == currentID })?.title ?? desc.title
        return HStack(spacing: 8) {
            Text(desc.title)
                .font(.system(size: 12))
                .foregroundStyle(DSColors.textPrimary)
            Spacer(minLength: 4)
            DSDropdown(
                selectedTitle: currentTitle,
                options: options.map { DSDropdownOption(id: $0.id, title: $0.title, iconName: $0.iconName) },
                width: 140,
                onSelect: { viewModel.updateDiscreteString(key: desc.id, value: $0) }
            )
        }
        .frame(height: 26)
    }

    private func flipRow(desc: PropertyDescriptor, horizontalID: String, verticalID: String) -> some View {
        HStack(spacing: 8) {
            Text(desc.title)
                .font(.system(size: 12))
                .foregroundStyle(DSColors.textPrimary)
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                flipButton(
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    isActive: viewModel.liveBool(for: horizontalID, default: false),
                    help: "Lật ngang"
                ) {
                    let cur = viewModel.liveBool(for: horizontalID, default: false)
                    viewModel.updateLiveBool(key: horizontalID, value: !cur)
                }
                flipButton(
                    icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                    isActive: viewModel.liveBool(for: verticalID, default: false),
                    help: "Lật dọc"
                ) {
                    let cur = viewModel.liveBool(for: verticalID, default: false)
                    viewModel.updateLiveBool(key: verticalID, value: !cur)
                }
            }
        }
        .frame(height: 26)
    }

    private func flipButton(icon: String, isActive: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? DSColors.accent : DSColors.textSecondary)
                .frame(width: 32, height: 26)
                .background(isActive ? DSColors.accent.opacity(0.18) : DSColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? DSColors.accent.opacity(0.8) : DSColors.inputBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
