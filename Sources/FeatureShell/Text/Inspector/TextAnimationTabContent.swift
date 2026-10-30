import SwiftUI
import Domain
import DesignSystem

/// Tab "Animation" cho Text Clip, hỗ trợ 3 nhóm hoạt ảnh chuyên nghiệp: Vào (In), Ra (Out), và Vòng lặp (Loop).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextAnimationTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: AnimationSubTab = .inAnimation

    public enum AnimationSubTab: String, CaseIterable {
        case inAnimation = "In"
        case outAnimation = "Out"
        case loopAnimation = "Loop"
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
                onSelectIn: { updateInAnimation($0) },
                onSelectOut: { updateOutAnimation($0) },
                onSelectLoop: { updateLoopAnimation($0) }
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
    }

    private var selectedClipDuration: Double {
        if let clip = viewModel.selectedClip {
            let sec = clip.timeRange.duration.seconds
            return sec > 0.1 ? sec : 3.0
        }
        return 3.0
    }

    private var hasActiveAnimationForCurrentSubTab: Bool {
        switch selectedSubTab {
        case .inAnimation:
            return currentConfig.animation.inType != .none
        case .outAnimation:
            return currentConfig.animation.outType != .none
        case .loopAnimation:
            return currentConfig.animation.loopType != .none
        }
    }

    // MARK: - SubTabBar (System Flat Segmented Style)

    private var subTabBar: some View {
        HStack(spacing: 2) {
            ForEach(AnimationSubTab.allCases, id: \.self) { tab in
                Button(action: { selectedSubTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedSubTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedSubTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(selectedSubTab == tab ? DSColors.windowBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - State & Selection Helpers

    private var currentConfig: TextConfiguration {
        if let json = viewModel.liveProperties["textConfig"]?.asString,
           let cfg = TextConfiguration.decode(from: json) {
            return cfg
        }
        if let json = viewModel.selectedClip?.properties["textConfig"]?.asString,
           let cfg = TextConfiguration.decode(from: json) {
            return cfg
        }
        return TextConfiguration()
    }

    private func updateInAnimation(_ item: TextInAnimationType) {
        var cfg = currentConfig
        if item == .none {
            cfg.animation.inType = .none
        } else {
            cfg.animation.inType = (cfg.animation.inType == item) ? .none : item
            if cfg.animation.inDuration <= 0.05 {
                cfg.animation.inDuration = 1.0
            }
        }
        commitConfig(cfg)
    }

    private func updateOutAnimation(_ item: TextOutAnimationType) {
        var cfg = currentConfig
        if item == .none {
            cfg.animation.outType = .none
        } else {
            cfg.animation.outType = (cfg.animation.outType == item) ? .none : item
            if cfg.animation.outDuration <= 0.05 {
                cfg.animation.outDuration = 1.0
            }
        }
        commitConfig(cfg)
    }

    private func updateLoopAnimation(_ item: TextLoopAnimationType) {
        var cfg = currentConfig
        if item == .none {
            cfg.animation.loopType = .none
        } else {
            cfg.animation.loopType = (cfg.animation.loopType == item) ? .none : item
        }
        commitConfig(cfg)
    }

    private func updateConfig(_ cfg: TextConfiguration, commit: Bool) {
        guard let json = cfg.encodeToJSON() else { return }
        if commit {
            viewModel.commitTextProperty(key: "textConfig", text: json)
        } else {
            viewModel.updateLiveText(key: "textConfig", text: json)
        }
    }

    private func commitConfig(_ cfg: TextConfiguration) {
        updateConfig(cfg, commit: true)
    }

    private func onSliderEditingEnded(_ editing: Bool) {
        viewModel.onSliderEditingChanged(key: "textConfig", isEditing: editing)
    }
}
