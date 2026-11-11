import SwiftUI
import Domain
import DesignSystem

/// Dynamic Inspector Panel that renders editable property controls from descriptors.
/// Uses the topbar as the unified tab bar for all objects and removes redundant metadata blocks.
/// Complies with R6.2, R6.3, and R8.2 of AGENTS.md.
public struct InspectorView: View {
    @Bindable var viewModel: InspectorViewModel
    @State private var selectedSubtabByTab: [String: String] = [:]

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSBlockContainer {
            VStack(alignment: .leading, spacing: DSSpacing.none) {
                DSInspectorTabBar(
                    tabs: viewModel.availableTabs,
                    selectedTab: $viewModel.selectedTab,
                    fallbackTitle: "Tác vụ",
                    trailing: {
                        InspectorTopbarToastView(viewModel: viewModel.actionsPanelViewModel)
                    }
                )
                contentArea
            }
            .frame(width: DSSize.sidebarWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(width: DSSize.sidebarWidth)
        .onAppear {
            viewModel.syncWithSelection()
        }
        .onChange(of: viewModel.selectedClip?.id) {
            viewModel.syncWithSelection()
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.selectedTransition != nil {
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                TransitionInspectorView(viewModel: viewModel)
                    .padding(DSSize.inspectorContentPadding)
            }
        } else if let clip = viewModel.selectedClip {
            if clip.kind == .text {
                TextInspectorView(viewModel: viewModel)
            } else if viewModel.effectiveTab == "Animation" && clip.kind == .sticker {
                StickerAnimationTabView(viewModel: viewModel)
            } else {
                DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                    clipInspectorContent(for: clip)
                        .padding(DSSize.inspectorContentPadding)
                }
            }
        } else {
            ActionsPanelView(viewModel: viewModel.actionsPanelViewModel)
        }
    }

    @ViewBuilder
    private func clipInspectorContent(for clip: TimelineClip) -> some View {
        switch clip.kind {
        case .adjustment:
            AdjustmentInspectorView(viewModel: viewModel)
        case .effect:
            EffectInspectorView(viewModel: viewModel)
        case .sticker:
            StickerInspectorView(viewModel: viewModel)
        default:
            if viewModel.effectiveTab == "Adjustment" {
                UnifiedColorInspectorView(viewModel: viewModel)
            } else if viewModel.effectiveTab == "AI" || viewModel.effectiveTab == "Grid" {
                AIInspectorView(viewModel: viewModel)
            } else {
                propertyGroupsList
            }
        }
    }

    private var propertyGroupsList: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            let subtabs = viewModel.activeSubtabs
            if subtabs.isEmpty {
                emptyPlaceholder
            } else if subtabs.count > 1 {
                let currentSubtab = effectiveSubtab(for: subtabs)

                DSSubTabBar(
                    tabs: subtabs,
                    selectedTab: Binding(
                        get: { currentSubtab },
                        set: { selectedSubtabByTab[viewModel.selectedTab] = $0 }
                    )
                )

                let groups = viewModel.groups(forSubtab: currentSubtab)
                ForEach(groups, id: \.group) { group in
                    groupSectionCard(group: group)
                }
            } else {
                let groups = viewModel.groups(forSubtab: subtabs.first ?? "")
                ForEach(groups, id: \.group) { group in
                    groupSectionCard(group: group)
                }
            }
        }
    }

    private func effectiveSubtab(for subtabs: [String]) -> String {
        if let saved = selectedSubtabByTab[viewModel.selectedTab],
           subtabs.contains(where: { $0.caseInsensitiveCompare(saved) == .orderedSame }) {
            return saved
        }
        return subtabs.first ?? ""
    }

    private func groupSectionCard(group: (group: String, descriptors: [PropertyDescriptor])) -> some View {
        let groupKeys = viewModel.keyframeKeys(forGroup: group.descriptors)
        return DSSectionCard(
            title: group.group,
            trailingAccessory: keyframeAccessory(for: groupKeys),
            onReset: { viewModel.resetGroup(name: group.group) }
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                ForEach(group.descriptors) { desc in descriptorControl(for: desc) }
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "square.dashed")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.45))
            Text(String(localized: "Tính năng \(viewModel.selectedTab) đang được phát triển"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
