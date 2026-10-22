import AppKit
import SwiftUI
import Domain
import DesignSystem

public struct TopbarView: View {
    private let viewModel: ShellViewModel

    public init(viewModel: ShellViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        DSBlockContainer {
            HStack(spacing: DSSpacing.none) {
                leftColumn
                    .padding(.leading, DSSize.trafficLightVerticalPadding)
                Spacer()
                middleColumn
                Spacer()
                rightColumn
                    .padding(.trailing, DSSize.exportButtonVerticalPadding)
            }
            .frame(height: DSSize.topbarHeight)
        }
    }

    private var leftColumn: some View {
        HStack(spacing: DSSpacing.sm) {
            DSTrafficLights(
                onClose: handleClose,
                onMinimize: handleMinimize,
                onZoom: handleZoom
            )
            undoRedoControls
        }
    }

    private var undoRedoControls: some View {
        HStack(spacing: DSSpacing.xs) {
            Button(action: { viewModel.timelineViewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.timelineViewModel.canUndo ? DSColors.textPrimary : DSColors.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.timelineViewModel.canUndo)
            .help("Undo (⌘Z)")

            Button(action: { viewModel.timelineViewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.timelineViewModel.canRedo ? DSColors.textPrimary : DSColors.textSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.timelineViewModel.canRedo)
            .help("Redo (⇧⌘Z)")
        }
        .padding(.leading, DSSpacing.xs)
    }

    private var middleColumn: some View {
        HStack(spacing: DSSpacing.none) {
            ForEach(viewModel.registry.tabs, id: \.id) { tab in
                DSTabButton(
                    title: tab.title,
                    isSelected: viewModel.selectedTabID == tab.id,
                    action: { viewModel.selectTab(tab.id) }
                )
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var rightColumn: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: handleImport) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Import Script")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(DSColors.textSecondary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(DSColors.blockBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
            }
            .buttonStyle(.plain)
            .help("Import Project Script JSON (⇧⌘I)")

            DSActionButton(title: "Export Script", action: handleExport)
                .help("Export Project Script JSON (⇧⌘S)")
        }
    }

    private func handleClose() {
        NSApplication.shared.keyWindow?.performClose(nil)
    }

    private func handleMinimize() {
        NSApplication.shared.keyWindow?.miniaturize(nil)
    }

    private func handleZoom() {
        NSApplication.shared.keyWindow?.zoom(nil)
    }

    private func handleImport() {
        TimelineProjectIO.importProjectScript(
            into: viewModel.timelineViewModel,
            mediaLibraryViewModel: viewModel.mediaLibraryViewModel
        )
        viewModel.updateTimelinePreview()
    }

    private func handleExport() {
        TimelineProjectIO.exportProjectScript(from: viewModel.timelineViewModel)
    }
}
