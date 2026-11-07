import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector chuyên dụng cho clip Hiệu ứng thị giác (Effect Layer).
/// Tự động sinh các thanh trượt tùy chỉnh (`customParameters`) được định nghĩa trong Gói Sáng Tạo Mở.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
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
            Text(String(localized: "THÔNG SỐ HIỆU ỨNG"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: String(localized: "Cường độ"),
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
                title: String(localized: "Tốc độ"),
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

            if currentConfig.type == .cinematicBlur && currentConfig.customParameters.isEmpty {
                DSSliderWithInput(
                    title: String(localized: "Bán kính mờ"),
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

    private var customParametersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "THAM SỐ GÓI SÁNG TẠO (CUSTOM SHADER)"))
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
