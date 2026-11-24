import SwiftUI
import Domain
import DesignSystem

/// Sticker `"Animation"` Inspector tab:
/// Uses the shared `DSAnimationScriptBrowser` layout with a compact Sticker-specific bottom bar:
/// - `Loop` and `Total` derive automatically from the actual Timeline clip length dragged by the user.
/// - `Beat Sync` automatically syncs to the overlapping Audio clip's detected BPM underneath.
public struct StickerAnimationTabView: View {
    @Bindable var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    private var currentConfig: StickerConfiguration {
        viewModel.stickerConfiguration
    }

    private var currentAnimation: StickerAnimationConfiguration {
        currentConfig.animation
    }

    private var clipDurationSeconds: Double {
        max(0.2, viewModel.selectedClip?.timeRange.duration.seconds ?? 3.0)
    }

    private var audioTempo: ResolvedAudioTempo {
        viewModel.resolvedAudioTempoForSelectedClip
    }

    private var resolvedPhases: ResolvedAnimationPhases {
        var anim = currentAnimation
        if anim.isBeatSyncEnabled, let detected = audioTempo.bpm {
            anim.beatBPM = detected
        }
        let cycleSec = StickerAnimationScriptRegistry.shared.script(for: anim.scriptId)?.baseCycleSeconds ?? 1.0
        return anim.resolvedPhases(forClipDuration: clipDurationSeconds, baseCycleSeconds: cycleSec)
    }

    public var body: some View {
        StickerScriptAnimationCardsGrid(
            selectedScriptId: currentAnimation.scriptId,
            sourceStickerConfig: currentConfig,
            showBottomPanel: currentAnimation.hasScriptAnimation,
            onSelectScript: selectScript,
            onClearScript: clearScript
        ) {
            animationBottomBar
        }
        .onAppear {
            viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
        }
        .onChange(of: viewModel.selectedClip?.id) { _, _ in
            viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
        }
        .onChange(of: currentAnimation.isBeatSyncEnabled) { _, enabled in
            if enabled {
                viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
            }
        }
        .onChange(of: audioTempo.bpm) { _, newBPM in
            if currentAnimation.isBeatSyncEnabled, let detectedBPM = newBPM, abs(currentAnimation.beatBPM - detectedBPM) > 0.5 {
                var cfg = currentConfig
                cfg.animation.beatBPM = detectedBPM
                viewModel.updateStickerConfiguration(cfg, commit: true)
            }
        }
    }

    private var animationBottomBar: some View {
        let padding: CGFloat = DSSpacing.md
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            speedAndIntensityRow(padding: padding)
            AnimationBeatSyncRowView(
                isBeatSyncEnabled: beatSyncBinding,
                beatBarMode: beatBarModeBinding,
                beatBPM: beatBPMBinding,
                audioTempo: audioTempo,
                onEditingChanged: commitOnFinish
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
                value: speedScaleBinding,
                step: 0.1, min: 0.25, max: 4.0, unit: "x", prefix: "Time Scale:", fractionDigits: 1,
                isFlexibleWidth: true, onEditingChanged: commitOnFinish
            )
            .frame(maxWidth: .infinity)

            DSNumberInput(
                value: intensityBinding,
                step: 10.0, min: 10.0, max: 200.0, unit: "%", prefix: "Intensity:", fractionDigits: 0,
                isFlexibleWidth: true, onEditingChanged: commitOnFinish
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bindings

    private var speedScaleBinding: Binding<Double> {
        Binding(
            get: { currentAnimation.scriptSpeed },
            set: { newSpeed in
                var cfg = currentConfig
                let script = StickerAnimationScriptRegistry.shared.script(for: cfg.animation.scriptId)
                cfg.animation.updateTimingForSpeed(
                    newSpeed,
                    clipDuration: clipDurationSeconds,
                    baseCycleSeconds: script?.baseCycleSeconds ?? 1.0
                )
                viewModel.updateStickerConfiguration(cfg, commit: false)
            }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { currentAnimation.scriptIntensity * 100.0 },
            set: { val in
                var cfg = currentConfig
                cfg.animation.scriptIntensity = max(0.1, min(2.0, val / 100.0))
                viewModel.updateStickerConfiguration(cfg, commit: false)
            }
        )
    }

    private var beatSyncBinding: Binding<Bool> {
        Binding(
            get: { currentAnimation.isBeatSyncEnabled },
            set: { enabled in
                var cfg = currentConfig
                cfg.animation.isBeatSyncEnabled = enabled
                if enabled {
                    viewModel.ensureAudioBeatsAnalyzedForSelectedClip()
                    if let detectedBPM = audioTempo.bpm {
                        cfg.animation.beatBPM = detectedBPM
                    }
                }
                viewModel.updateStickerConfiguration(cfg, commit: true)
            }
        )
    }

    private var beatBarModeBinding: Binding<AnimationBeatBarMode> {
        Binding(
            get: { currentAnimation.beatBarMode },
            set: { mode in
                var cfg = currentConfig
                cfg.animation.beatBarMode = mode
                viewModel.updateStickerConfiguration(cfg, commit: true)
            }
        )
    }

    private var beatBPMBinding: Binding<Double> {
        Binding(
            get: { currentAnimation.beatBPM },
            set: { val in
                var cfg = currentConfig
                cfg.animation.beatBPM = max(40.0, min(240.0, val))
                viewModel.updateStickerConfiguration(cfg, commit: false)
            }
        )
    }

    // MARK: - Actions

    private func commitOnFinish(_ isEditing: Bool) {
        if !isEditing {
            viewModel.updateStickerConfiguration(currentConfig, commit: true)
        }
    }

    private func selectScript(_ id: String) {
        guard let script = StickerAnimationScriptRegistry.shared.script(for: id) else { return }
        var cfg = currentConfig
        let speed = cfg.animation.hasScriptAnimation ? cfg.animation.scriptSpeed : 1.0
        cfg.animation.scriptId = script.id
        cfg.animation.updateTimingForSpeed(
            speed,
            clipDuration: clipDurationSeconds,
            baseCycleSeconds: script.baseCycleSeconds
        )
        if cfg.animation.isBeatSyncEnabled, let detectedBPM = audioTempo.bpm {
            cfg.animation.beatBPM = detectedBPM
        }
        viewModel.updateStickerConfiguration(cfg, commit: true)
    }

    private func clearScript() {
        var cfg = currentConfig
        cfg.animation.scriptId = ""
        viewModel.updateStickerConfiguration(cfg, commit: true)
    }
}
