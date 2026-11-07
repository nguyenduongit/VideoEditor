import SwiftUI
import Domain
import DesignSystem

/// Tab `"Animation"` cho Text Clip, kết nối Kho Thư Viện Animation Sáng Tạo Mở (`AnimationPreset` + Supabase)
/// hỗ trợ 3 pha: Vào (`In`), Ra (`Out`), và Vòng lặp (`Loop`) kèm thanh trượt thông số động.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextAnimationTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: AnimationSubTab = .inAnimation
    @State private var inPresets: [AnimationPreset] = AnimationPreset.inCatalog
    @State private var outPresets: [AnimationPreset] = AnimationPreset.outCatalog
    @State private var loopPresets: [AnimationPreset] = AnimationPreset.loopCatalog

    public enum AnimationSubTab: String, CaseIterable {
        case inAnimation = "In"
        case loopAnimation = "Loop"
        case outAnimation = "Out"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.none) {
            subTabBar
                .padding(.horizontal, DSSpacing.md)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.xs)

            TextAnimationCardsGrid(
                selectedSubTab: selectedSubTab,
                config: currentConfig,
                inPresets: inPresets,
                outPresets: outPresets,
                loopPresets: loopPresets,
                onSelectInPreset: { updateInPreset($0) },
                onSelectOutPreset: { updateOutPreset($0) },
                onSelectLoopPreset: { updateLoopPreset($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasActiveAnimationForCurrentSubTab {
                Divider()
                    .background(DSColors.blockBorder)

                TextAnimationSlidersView(
                    selectedSubTab: selectedSubTab,
                    config: Binding(get: { currentConfig }, set: { _ in }),
                    clipDuration: selectedClipDuration,
                    onCommit: commitConfig,
                    onUpdateLive: { updateConfig($0, commit: false) },
                    onEditingEnded: onSliderEditingEnded
                )
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.blockBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
        .task {
            reloadFromTemplateLoader()
            if !viewModel.dependencies.animationTemplates.hasSyncedFromRemote,
               let repo = viewModel.dependencies.presetRepositories.animationRepository,
               let _ = try? await repo.fetchPresets() {
                reloadFromTemplateLoader()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .presetStoreDidUpdate)) { _ in
            reloadFromTemplateLoader()
        }
    }

    private func reloadFromTemplateLoader() {
        let loader = viewModel.dependencies.animationTemplates
        inPresets = loader.loadTemplates(for: .inAnimation)
        outPresets = loader.loadTemplates(for: .outAnimation)
        loopPresets = loader.loadTemplates(for: .loopAnimation)
    }

    private var selectedClipDuration: Double {
        if let clip = viewModel.selectedClip {
            let sec = clip.timeRange.duration.seconds
            return sec > 0.1 ? sec : 3.0
        }
        return 3.0
    }

    private var hasActiveAnimationForCurrentSubTab: Bool {
        currentConfig.animation.hasInAnimation
            || currentConfig.animation.hasOutAnimation
            || currentConfig.animation.hasLoopAnimation
    }

    private func hasAnimation(for tab: AnimationSubTab) -> Bool {
        switch tab {
        case .inAnimation:
            return currentConfig.animation.hasInAnimation
        case .outAnimation:
            return currentConfig.animation.hasOutAnimation
        case .loopAnimation:
            return currentConfig.animation.hasLoopAnimation
        }
    }

    private var subTabBar: some View {
        HStack(spacing: 2) {
            ForEach(AnimationSubTab.allCases, id: \.self) { tab in
                let isSelected = selectedSubTab == tab
                Button(action: { selectedSubTab = tab }) {
                    HStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                        if hasAnimation(for: tab) {
                            Circle()
                                .fill(DSColors.toggleCyan)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(isSelected ? DSColors.windowBackground : Color.clear)
                    .contentShape(RoundedRectangle(cornerRadius: 5))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var currentConfig: TextConfiguration {
        viewModel.textConfiguration
    }

    private func updateInPreset(_ preset: AnimationPreset?) {
        var cfg = currentConfig
        cfg.animation.inType = .none
        if let preset {
            if cfg.animation.inManifest?.id == preset.manifest.id {
                cfg.animation.inManifest = nil
            } else {
                cfg.animation.inManifest = preset.manifest
                cfg.animation.scope = preset.manifest.defaultScope
                cfg.animation.staggerDirection = preset.manifest.defaultStaggerDirection
                if cfg.animation.inDuration <= 0.05 { cfg.animation.inDuration = 1.0 }
            }
        } else {
            cfg.animation.inManifest = nil
        }
        commitConfig(cfg)
    }

    private func updateOutPreset(_ preset: AnimationPreset?) {
        var cfg = currentConfig
        cfg.animation.outType = .none
        if let preset {
            if cfg.animation.outManifest?.id == preset.manifest.id {
                cfg.animation.outManifest = nil
            } else {
                cfg.animation.outManifest = preset.manifest
                if cfg.animation.outDuration <= 0.05 { cfg.animation.outDuration = 1.0 }
            }
        } else {
            cfg.animation.outManifest = nil
        }
        commitConfig(cfg)
    }

    private func updateLoopPreset(_ preset: AnimationPreset?) {
        var cfg = currentConfig
        cfg.animation.loopType = .none
        if let preset {
            if cfg.animation.loopManifest?.id == preset.manifest.id {
                cfg.animation.loopManifest = nil
            } else {
                cfg.animation.loopManifest = preset.manifest
            }
        } else {
            cfg.animation.loopManifest = nil
        }
        commitConfig(cfg)
    }

    private func updateConfig(_ cfg: TextConfiguration, commit: Bool) {
        viewModel.updateTextConfiguration(cfg, commit: commit)
    }

    private func commitConfig(_ cfg: TextConfiguration) {
        updateConfig(cfg, commit: true)
    }

    private func onSliderEditingEnded(_ editing: Bool) {
        let key = viewModel.selectedClip?.kind == .sticker ? "stickerConfig" : "textConfig"
        viewModel.onSliderEditingChanged(key: key, isEditing: editing)
    }
}
