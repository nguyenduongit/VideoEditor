import SwiftUI
import Domain
import DesignSystem

/// Text `"Animation"` Inspector tab:
/// Displays the curated continuous `TextAnimationScript` catalog (`Intro -> Loop -> Outro` unified block)
/// and continuous parameter controls (`Loop`, `Time Scale`, `Intensity`, `Unit`, `Order`, `Beat Sync`).
public struct TextAnimationTabContent: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var clipDurationSeconds: Double {
        let sec = viewModel.selectedClip?.timeRange.duration.seconds ?? currentConfig.animation.scriptDuration
        return max(0.5, sec)
    }

    private var audioTempo: ResolvedAudioTempo {
        viewModel.resolvedAudioTempoForSelectedClip
    }

    private var resolvedPhases: ResolvedAnimationPhases {
        var anim = currentConfig.animation
        if anim.isBeatSyncEnabled, let detected = audioTempo.bpm {
            anim.beatBPM = detected
        }
        let cycleSec = anim.graph?.loopCycleDuration
            ?? TextAnimationScriptRegistry.shared.script(for: anim.scriptId)?.loopCycleDuration
            ?? 1.0
        return anim.resolvedPhases(forClipDuration: clipDurationSeconds, baseCycleSeconds: cycleSec)
    }

    public var body: some View {
        TextScriptAnimationCardsGrid(
            selectedScriptId: currentConfig.animation.graph?.id ?? currentConfig.animation.scriptId,
            showBottomPanel: currentConfig.animation.hasScriptAnimation,
            onSelectItem: selectCatalogItem,
            onClearScript: clearScript
        ) {
            animationBottomBar
        }
        .onAppear { viewModel.ensureAudioBeatsAnalyzedForSelectedClip() }
        .onChange(of: viewModel.selectedClip?.id) { _, _ in
            viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
        }
        .onChange(of: currentConfig.animation.isBeatSyncEnabled) { _, enabled in
            if enabled { viewModel.ensureAudioBeatsAnalyzedForSelectedClip() }
        }
        .onChange(of: audioTempo.bpm) { _, newBPM in
            if currentConfig.animation.isBeatSyncEnabled,
               let detectedBPM = newBPM,
               abs(currentConfig.animation.beatBPM - detectedBPM) > 0.5 {
                var cfg = currentConfig
                cfg.animation.beatBPM = detectedBPM
                updateConfig(cfg, commit: true)
            }
        }
    }

    private var animationBottomBar: some View {
        let padding: CGFloat = DSSpacing.md
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            speedAndIntensityRow(padding: padding)
            shapingControlsRow(padding: padding)
            AnimationBeatSyncRowView(
                isBeatSyncEnabled: beatSyncBinding,
                beatBarMode: beatBarModeBinding,
                beatBPM: beatBPMBinding,
                audioTempo: audioTempo,
                onEditingChanged: onSliderEditingEnded
            )
            AnimationTimingSummaryRowView(phases: resolvedPhases)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, padding)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColors.blockBackground)
    }

    private func speedAndIntensityRow(padding: CGFloat) -> some View {
        HStack(spacing: padding) {
            DSNumberInput(
                value: scriptSpeedBinding,
                step: 0.1, min: 0.25, max: 4.0, unit: "x", prefix: "Time Scale:", fractionDigits: 1,
                isFlexibleWidth: true, onEditingChanged: onSliderEditingEnded
            )
            .frame(maxWidth: .infinity)

            DSNumberInput(
                value: intensityBinding,
                step: 10.0, min: 20.0, max: 200.0, unit: "%", prefix: "Intensity:", fractionDigits: 0,
                isFlexibleWidth: true, onEditingChanged: onSliderEditingEnded
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func shapingControlsRow(padding: CGFloat) -> some View {
        HStack(spacing: padding) {
            HStack(spacing: DSSpacing.xs) {
                Text("Unit:")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                Picker("Unit", selection: scopeOverrideBinding) {
                    Text("Auto").tag(TextAnimationScope?.none)
                    ForEach(TextAnimationScope.allCases) { scope in
                        Text(scope.title).tag(TextAnimationScope?.some(scope))
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .help("Animation Segmentation Unit")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: DSSpacing.xs) {
                Text("Order:")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textSecondary)
                Picker("Order", selection: staggerDirectionBinding) {
                    ForEach(TextStaggerDirection.allCases) { dir in
                        Text(dir.title).tag(dir)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .help("Stagger Reveal Direction")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bindings

    private var scriptSpeedBinding: Binding<Double> {
        Binding(
            get: { currentConfig.animation.scriptSpeed },
            set: { val in
                var cfg = currentConfig
                let cycleSec = cfg.animation.graph?.loopCycleDuration
                    ?? TextAnimationScriptRegistry.shared.script(for: cfg.animation.scriptId)?.loopCycleDuration
                    ?? 1.0
                cfg.animation.updateTimingForSpeed(val, clipDuration: clipDurationSeconds, baseCycleSeconds: cycleSec)
                updateConfig(cfg, commit: false)
            }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { currentConfig.animation.scriptIntensity * 100.0 },
            set: { val in
                var cfg = currentConfig
                cfg.animation.scriptIntensity = max(0.2, min(2.0, val / 100.0))
                updateConfig(cfg, commit: false)
            }
        )
    }

    private var scopeOverrideBinding: Binding<TextAnimationScope?> {
        Binding(
            get: { currentConfig.animation.scopeOverride },
            set: { val in
                var cfg = currentConfig
                cfg.animation.scopeOverride = val
                updateConfig(cfg, commit: true)
            }
        )
    }

    private var staggerDirectionBinding: Binding<TextStaggerDirection> {
        Binding(
            get: { currentConfig.animation.staggerDirection },
            set: { val in
                var cfg = currentConfig
                cfg.animation.staggerDirection = val
                updateConfig(cfg, commit: true)
            }
        )
    }

    private var beatSyncBinding: Binding<Bool> {
        Binding(
            get: { currentConfig.animation.isBeatSyncEnabled },
            set: { enabled in
                var cfg = currentConfig
                cfg.animation.isBeatSyncEnabled = enabled
                if enabled, let detectedBPM = audioTempo.bpm {
                    cfg.animation.beatBPM = detectedBPM
                }
                updateConfig(cfg, commit: true)
                if enabled {
                    viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
                }
            }
        )
    }

    private var beatBarModeBinding: Binding<AnimationBeatBarMode> {
        Binding(
            get: { currentConfig.animation.beatBarMode },
            set: { mode in
                var cfg = currentConfig
                cfg.animation.beatBarMode = mode
                updateConfig(cfg, commit: true)
            }
        )
    }

    private var beatBPMBinding: Binding<Double> {
        Binding(
            get: { currentConfig.animation.beatBPM },
            set: { val in
                var cfg = currentConfig
                cfg.animation.beatBPM = max(40.0, min(240.0, val))
                updateConfig(cfg, commit: false)
            }
        )
    }

    // MARK: - Actions

    private func selectCatalogItem(_ item: TextAnimationCatalogItem) {
        var cfg = currentConfig
        switch item {
        case .script(let script):
            cfg.animation.graph = nil
            cfg.animation.scriptId = script.id
        case .graph(let graph, _, _):
            cfg.animation.graph = graph
            cfg.animation.scriptId = graph.id
        }
        if let detectedBPM = audioTempo.bpm {
            cfg.animation.beatBPM = detectedBPM
        }
        cfg.animation.updateTimingForSpeed(1.0, clipDuration: clipDurationSeconds, baseCycleSeconds: item.loopCycleDuration)
        updateConfig(cfg, commit: true)
        viewModel.ensureAudioBeatsAnalyzedForSelectedClip()

        if let clip = viewModel.selectedClip, clip.timeRange.duration > .zero {
            viewModel.timelineViewModel?.onLoopRangeRequested?(clip.timeRange)
        }
    }

    private func clearScript() {
        var cfg = currentConfig
        cfg.animation.graph = nil
        cfg.animation.scriptId = "none"
        cfg.animation.scopeOverride = nil
        updateConfig(cfg, commit: true)
        viewModel.timelineViewModel?.onStopPlaybackRequested?()
    }

    private var currentConfig: TextConfiguration { viewModel.textConfiguration }
    private func updateConfig(_ config: TextConfiguration, commit: Bool) { viewModel.updateTextConfiguration(config, commit: commit) }

    private func onSliderEditingEnded(isEditing: Bool) {
        if !isEditing {
            viewModel.updateTextConfiguration(currentConfig, commit: true)
            if let clip = viewModel.selectedClip, clip.timeRange.duration > .zero {
                viewModel.timelineViewModel?.onLoopRangeRequested?(clip.timeRange)
            }
        }
    }
}
