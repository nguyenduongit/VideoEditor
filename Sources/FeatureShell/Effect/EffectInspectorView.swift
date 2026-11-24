import SwiftUI
import Domain
import DesignSystem

/// Inspector panel for visual Effect Layer clips.
/// Dynamically renders custom shader parameter sliders defined in `EffectConfiguration.customParameters`.
/// System-only Effects do not expose User Preset Save/Overwrite controls per AGENTS.md Article 15.
public struct EffectInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            headerSection
            Divider().background(DSColors.blockBorder)
            slidersSection
            if !currentConfig.customParameters.isEmpty {
                Divider().background(DSColors.blockBorder)
                customParametersSection
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var headerSection: some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(DSColors.clipEffect.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: currentConfig.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DSColors.clipEffect)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.selectedClip?.name ?? currentConfig.type.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)

                Text(currentConfig.type.description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "EFFECT PARAMETERS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: String(localized: "Intensity"),
                value: Binding(
                    get: { viewModel.liveNumber(for: "intensity", default: currentConfig.intensity) },
                    set: { val in updateConfig(key: "intensity", value: val) { $0.intensity = val } }
                ),
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                trailingAccessory: effectKeyframeAccessory(for: "intensity", defaultVal: currentConfig.intensity),
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            DSSliderWithInput(
                title: String(localized: "Speed"),
                value: Binding(
                    get: { viewModel.liveNumber(for: "effectSpeed", default: currentConfig.speed) },
                    set: { val in updateConfig(key: "effectSpeed", value: val) { $0.speed = val } }
                ),
                range: 0.2...3.0,
                step: 0.05,
                defaultValue: 1.0,
                unit: "x",
                trailingAccessory: effectKeyframeAccessory(for: "effectSpeed", defaultVal: currentConfig.speed),
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            beatSyncControl

            if currentConfig.type == .cinematicBlur && currentConfig.customParameters.isEmpty {
                DSSliderWithInput(
                    title: String(localized: "Blur Radius"),
                    value: Binding(
                        get: { viewModel.liveNumber(for: "blurRadius", default: currentConfig.blurRadius) },
                        set: { val in updateConfig(key: "blurRadius", value: val) { $0.blurRadius = val } }
                    ),
                    range: 2.0...80.0,
                    step: 1.0,
                    defaultValue: 20.0,
                    unit: "px",
                    trailingAccessory: effectKeyframeAccessory(for: "blurRadius", defaultVal: currentConfig.blurRadius),
                    onEditingChanged: { editing in
                        if !editing { commitConfig() }
                    }
                )
            }
        }
    }

    private var beatSyncControl: some View {
        HStack(spacing: DSSpacing.sm) {
            ZStack {
                Circle()
                    .fill(currentConfig.isBeatSynced ? DSColors.toggleCyan.opacity(0.2) : DSColors.windowBackground)
                    .frame(width: 28, height: 28)
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(currentConfig.isBeatSynced ? DSColors.toggleCyan : DSColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Beat Sync"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text(String(localized: "Auto shake, bounce, or mini-zoom to audio beats"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(DSColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { currentConfig.isBeatSynced },
                set: { val in
                    updateConfig(key: "isBeatSynced", value: val ? 1.0 : 0.0) { $0.isBeatSynced = val }
                    commitConfig()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(DSColors.blockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(currentConfig.isBeatSynced ? DSColors.toggleCyan.opacity(0.4) : DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var customParametersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "CREATIVE SHADER PARAMETERS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            ForEach(currentConfig.customParameters) { param in
                DSSliderWithInput(
                    title: param.title,
                    value: Binding(
                        get: { viewModel.liveNumber(for: param.id, default: currentConfig.value(forParameter: param.id)) },
                        set: { val in updateConfig(key: param.id, value: val) { $0.setValue(val, forParameter: param.id) } }
                    ),
                    range: param.minValue...param.maxValue,
                    step: param.step,
                    defaultValue: param.defaultValue,
                    unit: param.unit,
                    trailingAccessory: effectKeyframeAccessory(for: param.id, defaultVal: param.defaultValue),
                    onEditingChanged: { editing in
                        if !editing { commitConfig() }
                    }
                )
            }
        }
    }

    private func effectKeyframeAccessory(for key: String, defaultVal: Double) -> AnyView {
        let keys = [key]
        return AnyView(
            DSKeyframeControl(
                hasKeyframesOnTrack: viewModel.hasKeyframes(for: keys),
                isAtKeyframe: viewModel.hasKeyframeAtPlayhead(for: keys),
                canGoPrevious: viewModel.canJumpToPreviousKeyframe(for: keys),
                canGoNext: viewModel.canJumpToNextKeyframe(for: keys),
                selectedCurveID: viewModel.activeInterpolation(for: keys).rawValue,
                curveOptions: viewModel.keyframeCurveOptions,
                onToggleKeyframe: { viewModel.toggleKeyframe(for: keys, defaultValues: [key: defaultVal]) },
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

    private var currentConfig: EffectConfiguration {
        let str = viewModel.liveProperties["effectConfig"]?.asString
            ?? viewModel.selectedClip?.properties["effectConfig"]?.asString ?? ""
        return EffectConfiguration.decode(from: str) ?? EffectConfiguration()
    }

    private func updateConfig(key: String, value: Double, _ mutate: (inout EffectConfiguration) -> Void) {
        var cfg = currentConfig
        mutate(&cfg)
        if let json = cfg.encodeToJSON() {
            viewModel.updateLiveText(key: "effectConfig", text: json)
            viewModel.updateLiveValue(key: key, value: value)
        }
    }

    private func commitConfig() {
        if let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "effectConfig", text: json)
        }
    }
}
