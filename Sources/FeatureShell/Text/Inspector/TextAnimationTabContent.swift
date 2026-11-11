import SwiftUI
import Domain
import DesignSystem

/// Tab `"Animation"` cho Text Clip:
/// Hiển thị danh mục các Kịch Bản Hoạt Ảnh đóng gói sẵn do Dev thiết kế (Script-Driven Animation),
/// can thiệp sâu vào Transform, Typography, Appearance, Effects và chạy xuyên suốt thời lượng.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextAnimationTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    public enum AnimationSubTab: String, CaseIterable, Sendable {
        case inAnimation = "In"
        case loopAnimation = "Loop"
        case outAnimation = "Out"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.none) {
            TextScriptAnimationCardsGrid(
                selectedScriptId: currentConfig.animation.scriptId,
                onSelectScript: selectScript,
                onClearScript: clearScript
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if currentConfig.animation.hasScriptAnimation {
                Divider()
                    .background(DSColors.blockBorder)

                animationBottomBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    @ViewBuilder
    private var animationBottomBar: some View {
        let padding: CGFloat = DSSpacing.md
        let anim = currentConfig.animation
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: padding) {
                DSNumberInput(
                    value: baseLoopSecondsBinding,
                    step: 1.0,
                    min: 1.0,
                    max: 20.0,
                    unit: "s",
                    prefix: "Loop:",
                    fractionDigits: 0,
                    isFlexibleWidth: true,
                    onEditingChanged: onSliderEditingEnded
                )
                .frame(maxWidth: .infinity)

                DSNumberInput(
                    value: scriptSpeedBinding,
                    step: 0.1,
                    min: 0.2,
                    max: 4.0,
                    unit: "x",
                    prefix: "Time Scale:",
                    fractionDigits: 1,
                    isFlexibleWidth: true,
                    onEditingChanged: onSliderEditingEnded
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: DSSpacing.sm) {
                Text("In: \(formatSeconds(anim.scriptInDuration))s")
                Text("•")
                Text("Loop: \(formatSeconds(anim.scriptLoopDuration))s")
                Text("•")
                Text("Out: \(formatSeconds(anim.scriptOutDuration))s")
                Spacer()
                Text("Total: \(formatSeconds(anim.scriptDuration))s")
                    .fontWeight(.semibold)
                    .foregroundStyle(DSColors.toggleCyan)
            }
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, padding)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColors.blockBackground)
    }

    private var baseLoopSecondsBinding: Binding<Double> {
        Binding(
            get: { Double(currentConfig.animation.scriptBaseLoopSeconds) },
            set: { val in
                var cfg = currentConfig
                let steps = max(1, min(20, Int(val.rounded())))
                cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: steps, speed: cfg.animation.scriptSpeed)
                updateConfig(cfg, commit: false)
            }
        )
    }

    private var scriptSpeedBinding: Binding<Double> {
        Binding(
            get: { currentConfig.animation.scriptSpeed },
            set: { val in
                var cfg = currentConfig
                let steps = cfg.animation.scriptBaseLoopSeconds
                cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: steps, speed: val)
                updateConfig(cfg, commit: false)
            }
        )
    }

    private func formatSeconds(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func selectScript(_ script: any TextAnimationScript) {
        var cfg = currentConfig
        cfg.animation.scriptId = script.id
        let baseSteps = max(1, Int(script.defaultLoopDuration.rounded()))
        cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: baseSteps, speed: 1.0)
        updateConfig(cfg, commit: true)

        if let clip = viewModel.selectedClip, clip.timeRange.duration > .zero {
            viewModel.timelineViewModel?.onLoopRangeRequested?(clip.timeRange)
        }
    }

    private func clearScript() {
        var cfg = currentConfig
        cfg.animation.scriptId = "none"
        updateConfig(cfg, commit: true)
        viewModel.timelineViewModel?.onStopPlaybackRequested?()
    }

    private var selectedClipDuration: Double {
        if let clip = viewModel.selectedClip {
            let sec = clip.timeRange.duration.seconds
            return sec > 0.1 ? sec : 3.0
        }
        return 3.0
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
            if let clip = viewModel.selectedClip, clip.timeRange.duration > .zero {
                viewModel.timelineViewModel?.onLoopRangeRequested?(clip.timeRange)
            }
        }
    }
}
