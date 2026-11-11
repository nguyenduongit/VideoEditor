import SwiftUI
import Domain
import DesignSystem

/// Khối điều khiển Bố cục & Biến đổi (Transform & Keyframes) cho Text Clip đơn dòng.
/// Hỗ trợ Position (X, Y), Scale, Rotation, Opacity và hỗ trợ Keyframe hoàn chỉnh.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextTransformSectionView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSSectionCard(
            title: String(localized: "Transform"),
            trailingAccessory: AnyView(keyframeControl(for: ["positionX", "positionY", "scale", "rotation", "opacity"]))
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                positionControl
                scaleControl
                rotationControl
                skewControl
                opacityControl
            }
        }
    }

    private var positionControl: some View {
        DSPositionControl(
            title: "Position",
            xValue: Binding(
                get: { currentConfig.positionX },
                set: { val in
                    var cfg = currentConfig
                    cfg.positionX = val
                    updateConfig(cfg, commit: false)
                }
            ),
            yValue: Binding(
                get: { currentConfig.positionY },
                set: { val in
                    var cfg = currentConfig
                    cfg.positionY = val
                    updateConfig(cfg, commit: false)
                }
            ),
            trailingAccessory: AnyView(keyframeControl(for: ["positionX", "positionY"])),
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var scaleControl: some View {
        DSSliderWithInput(
            title: "Scale",
            value: Binding(
                get: { currentConfig.scale },
                set: { val in
                    var cfg = currentConfig
                    cfg.scale = val
                    updateConfig(cfg, commit: false)
                }
            ),
            range: 0.1...15.0,
            step: 0.05,
            defaultValue: 1.0,
            trailingAccessory: AnyView(keyframeControl(for: ["scale"], defaultVal: 1.0)),
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var rotationControl: some View {
        DSRotationControl(
            title: "Rotation",
            angle: Binding(
                get: { currentConfig.rotation },
                set: { val in
                    var cfg = currentConfig
                    cfg.rotation = val
                    updateConfig(cfg, commit: false)
                }
            ),
            trailingAccessory: AnyView(keyframeControl(for: ["rotation"], defaultVal: 0.0)),
            onEditingChanged: onSliderEditingEnded
        )
    }

    private var skewControl: some View {
        VStack(spacing: DSSpacing.xs) {
            DSSliderWithInput(
                title: "Skew X",
                value: Binding(
                    get: { currentConfig.skewX },
                    set: { val in
                        var cfg = currentConfig
                        cfg.skewX = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: -60.0...60.0,
                step: 1.0,
                defaultValue: 0.0,
                unit: "°",
                onEditingChanged: onSliderEditingEnded
            )
            DSSliderWithInput(
                title: "Skew Y",
                value: Binding(
                    get: { currentConfig.skewY },
                    set: { val in
                        var cfg = currentConfig
                        cfg.skewY = val
                        updateConfig(cfg, commit: false)
                    }
                ),
                range: -60.0...60.0,
                step: 1.0,
                defaultValue: 0.0,
                unit: "°",
                onEditingChanged: onSliderEditingEnded
            )
        }
    }

    private var opacityControl: some View {
        DSSliderWithInput(
            title: "Opacity",
            value: Binding(
                get: { currentConfig.opacity },
                set: { val in
                    var cfg = currentConfig
                    cfg.opacity = val
                    updateConfig(cfg, commit: false)
                }
            ),
            range: 0.0...1.0,
            step: 0.01,
            defaultValue: 1.0,
            unit: "%",
            trailingAccessory: AnyView(keyframeControl(for: ["opacity"], defaultVal: 1.0)),
            onEditingChanged: onSliderEditingEnded
        )
    }

    private func keyframeControl(for keys: [String], defaultVal: Double? = nil) -> DSKeyframeControl {
        var defaults: [String: Double] = [:]
        if let defaultVal, keys.count == 1 {
            defaults[keys[0]] = defaultVal
        }
        return DSKeyframeControl(
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
