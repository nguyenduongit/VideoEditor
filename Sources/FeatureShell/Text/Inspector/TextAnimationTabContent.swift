import SwiftUI
import Domain
import DesignSystem

/// Tab "Animation" cho Text Clip, hỗ trợ 4 nhóm hoạt ảnh: In, Out, Loop, Combo và tùy chỉnh Motion Easing / Scope.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextAnimationTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedSubTab: AnimationSubTab = .inAnimation

    public enum AnimationSubTab: String, CaseIterable {
        case inAnimation = "In"
        case outAnimation = "Out"
        case loopAnimation = "Loop"
        case comboAnimation = "Combo"
    }

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            subTabBar
            TextAnimationSlidersView(
                selectedSubTab: selectedSubTab,
                config: Binding(get: { currentConfig }, set: { _ in }),
                onCommit: commitConfig,
                onUpdateLive: { updateConfig($0, commit: false) },
                onEditingEnded: onSliderEditingEnded
            )
            TextAnimationCardsGrid(
                selectedSubTab: selectedSubTab,
                config: currentConfig,
                onSelectIn: { updateInAnimation($0) },
                onSelectOut: { updateOutAnimation($0) },
                onSelectLoop: { updateLoopAnimation($0) },
                onSelectCombo: { updateComboAnimation($0) }
            )
        }
        .padding(.vertical, DSSpacing.sm)
    }

    // MARK: - SubTabBar

    private var subTabBar: some View {
        HStack(spacing: 4) {
            ForEach(AnimationSubTab.allCases, id: \.self) { tab in
                Button {
                    selectedSubTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedSubTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedSubTab == tab ? DSColors.textPrimary : DSColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            selectedSubTab == tab
                                ? DSColors.activeTabBackground
                                : Color.white.opacity(0.04)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: DSRadius.small)
                                .stroke(selectedSubTab == tab ? DSColors.toggleCyan.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - State & Selection Helpers

    private var currentConfig: TextConfiguration {
        let json = viewModel.liveProperties["textConfig"]?.asString ?? ""
        return TextConfiguration.decode(from: json) ?? TextConfiguration()
    }

    private func updateInAnimation(_ item: TextInAnimationType) {
        var cfg = currentConfig
        cfg.animation.inType = item
        commitConfig(cfg)
    }

    private func updateOutAnimation(_ item: TextOutAnimationType) {
        var cfg = currentConfig
        cfg.animation.outType = item
        commitConfig(cfg)
    }

    private func updateLoopAnimation(_ item: TextLoopAnimationType) {
        var cfg = currentConfig
        cfg.animation.loopType = item
        commitConfig(cfg)
    }

    private func updateComboAnimation(_ item: TextComboAnimationType) {
        var cfg = currentConfig
        cfg.animation.comboType = item
        commitConfig(cfg)
    }

    private func updateConfig(_ cfg: TextConfiguration, commit: Bool) {
        guard let json = cfg.encodeToJSON() else { return }
        if commit {
            viewModel.updateDiscreteString(key: "textConfig", value: json)
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
