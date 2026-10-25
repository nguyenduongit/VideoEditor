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
        .sheet(isPresented: Binding(
            get: { viewModel.exportViewModel.isPresented },
            set: { viewModel.exportViewModel.isPresented = $0 }
        )) {
            ExportDialogView(
                viewModel: viewModel.exportViewModel,
                timelineViewModel: viewModel.timelineViewModel
            )
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
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.timelineViewModel.canUndo)
            .help("Undo (⌘Z)")

            Button(action: { viewModel.timelineViewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.timelineViewModel.canRedo ? DSColors.textPrimary : DSColors.textSecondary.opacity(0.4))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
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
            importScriptButton
            exportScriptButton
            exportVideoButton
        }
    }

    private var importScriptButton: some View {
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
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.control))
        }
        .buttonStyle(.plain)
        .help("Import Project Script JSON (⇧⌘I)")
    }

    private var exportScriptButton: some View {
        Button(action: handleExportScript) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("Export Script")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(DSColors.textSecondary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.control))
        }
        .buttonStyle(.plain)
        .help("Export Project Script JSON (⇧⌘S)")
    }

    private var exportVideoButton: some View {
        DSActionButton(
            title: "Xuất Video",
            icon: "film.fill",
            action: handleOpenExportDialog
        )
        .help("Xuất dự án ra video MP4 (⌘E)")
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

    private func handleExportScript() {
        TimelineProjectIO.exportProjectScript(from: viewModel.timelineViewModel)
    }

    private func handleOpenExportDialog() {
        viewModel.exportViewModel.openDialog()
    }
}
