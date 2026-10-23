import SwiftUI
import DesignSystem

public struct MainLayoutView: View {
    private let viewModel: ShellViewModel

    public init(viewModel: ShellViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geometry in
            let previewWidth = max(0, geometry.size.width - (2 * DSSize.sidebarWidth) - (4 * DSSpacing.gap))
            let previewViewportHeight = previewWidth * DSSize.previewAspectMultiplier
            let middleHeight = previewViewportHeight + DSSize.previewBottomBarHeight

            VStack(spacing: DSSpacing.gap) {
                TopbarView(viewModel: viewModel)
                middleSection(height: middleHeight)
                TimelineView(
                    viewModel: viewModel.timelineViewModel,
                    playheadState: viewModel.playheadState,
                    onTimelineActivated: { viewModel.switchToTimelinePreview() }
                )
            }
            .padding(DSSpacing.gap)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DSColors.windowBackground)
        .background(WindowAccessor())
        .ignoresSafeArea()
    }

    private func middleSection(height: CGFloat) -> some View {
        let activeTab = viewModel.registry.descriptor(for: viewModel.selectedTabID)
        let sidebarTitle = activeTab?.title ?? "L-Sidebar"
        let sidebarContent = viewModel.registry.sidebarView(for: viewModel.selectedTabID)
        let sidebarAccessory = viewModel.registry.sidebarTrailingAccessory(for: viewModel.selectedTabID)

        return HStack(spacing: DSSpacing.gap) {
            SidebarView(
                title: sidebarTitle,
                customContent: sidebarContent,
                trailingAccessory: sidebarAccessory
            )
            PreviewView(viewModel: viewModel)
            InspectorView(viewModel: viewModel.inspectorViewModel)
        }
        .frame(height: height)
    }
}
