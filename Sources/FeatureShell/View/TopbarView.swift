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
        HStack(spacing: DSSpacing.none) {
            leftColumn
                .padding(.leading, DSSpacing.gap)
            Spacer()
            rightColumn
                .padding(.trailing, DSSpacing.gap)
        }
        .frame(height: DSSize.topbarHeight)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
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
        DSTrafficLights(
            onClose: handleClose,
            onMinimize: handleMinimize,
            onZoom: handleZoom
        )
    }

    private var rightColumn: some View {
        HStack(spacing: DSSpacing.xs) {
            openButton
            saveButton
            exportButton
        }
    }

    private var openButton: some View {
        DSTopbarButton(
            title: "Open",
            icon: "folder",
            style: .secondary,
            action: handleOpenProject
        )
        .help(String(localized: "Open Project (⌘O)"))
    }

    private var saveButton: some View {
        DSTopbarButton(
            title: "Save",
            icon: "square.and.arrow.down",
            style: .secondary,
            action: handleSaveProject
        )
        .help(String(localized: "Save Project (⌘S)"))
    }

    private var exportButton: some View {
        DSTopbarButton(
            title: "Export",
            icon: "film.fill",
            style: .primary,
            action: handleOpenExportDialog
        )
        .help(String(localized: "Export Video MP4 (⌘E)"))
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

    private func handleOpenProject() {
        TimelineProjectIO.openProject(
            into: viewModel.timelineViewModel,
            mediaLibraryViewModel: viewModel.mediaLibraryViewModel
        )
        viewModel.updateTimelinePreview()
    }

    private func handleSaveProject() {
        TimelineProjectIO.saveProject(from: viewModel.timelineViewModel)
    }

    private func handleOpenExportDialog() {
        viewModel.exportViewModel.openDialog()
    }
}
