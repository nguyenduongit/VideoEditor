import AppKit
import SwiftUI
import Domain
import FeatureShell
import Infrastructure

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct VideoEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel: ShellViewModel
    private let mcpTransport: (any MCPServerTransport)?

    init() {
        PresetRepositoryProvider.shared.adjustmentRepository = SupabaseAdjustmentPresetRepository()
        PresetRepositoryProvider.shared.textRepository = SupabaseTextPresetRepository()
        ActionRepositoryProvider.shared.actionRepository = SupabaseActionRepository()

        Task {
            _ = try? await PresetRepositoryProvider.shared.textRepository?.fetchPresets()
            _ = try? await ActionRepositoryProvider.shared.actionRepository?.fetchActions()
        }

        let registry = TabRegistry()
        let thumbnailService = MediaThumbnailService()
        let timelineThumbnailService = TimelineThumbnailService()
        let audioWaveformService = AudioWaveformService()
        let audioAlignmentService = AudioAlignmentService()
        let subjectTrackingService = VisionSubjectTrackingService()
        let mediaViewModel = MediaLibraryViewModel(
            thumbnailService: thumbnailService,
            waveformService: audioWaveformService
        )
        let timelineViewModel = TimelineViewModel(
            thumbnailService: timelineThumbnailService,
            waveformService: audioWaveformService,
            audioAlignmentService: audioAlignmentService,
            subjectTrackingService: subjectTrackingService
        )
        let shellViewModel = ShellViewModel(
            registry: registry,
            timelineViewModel: timelineViewModel,
            mediaLibraryViewModel: mediaViewModel
        )

        mediaViewModel.onActiveAssetChange = { [weak shellViewModel] asset in
            shellViewModel?.setPreviewAsset(asset)
        }

        shellViewModel.onTimelineActivated = { [weak mediaViewModel] in
            mediaViewModel?.clearSelection()
        }

        mediaViewModel.onAddAssetToTimeline = { [weak shellViewModel, weak timelineViewModel] asset in
            timelineViewModel?.addAsset(asset)
            shellViewModel?.switchToTimelinePreview()
        }

        mediaViewModel.onAddAssetsToTimeline = { [weak shellViewModel, weak timelineViewModel] assets in
            timelineViewModel?.addAssets(assets)
            shellViewModel?.switchToTimelinePreview()
        }

        mediaViewModel.onAssetsDeleted = { [weak timelineViewModel, weak shellViewModel] deletedAssets in
            let ids = Set(deletedAssets.map(\.id))
            let urls = Set(deletedAssets.map(\.url))
            timelineViewModel?.removeClips(forAssetIDs: ids, urls: urls)
            shellViewModel?.updateTimelinePreview()
        }

        mediaViewModel.onUndoRequested = { [weak timelineViewModel] in
            timelineViewModel?.undo() ?? false
        }
        mediaViewModel.onRedoRequested = { [weak timelineViewModel] in
            timelineViewModel?.redo() ?? false
        }
        timelineViewModel.onClipsRestored = { [weak mediaViewModel] restoredClips in
            mediaViewModel?.restoreAssetsForClips(restoredClips)
        }

        Self.registerAllTabs(in: registry, mediaViewModel: mediaViewModel, timelineViewModel: timelineViewModel)
        _viewModel = State(initialValue: shellViewModel)

        let scriptEngine = TimelineScriptEngine(
            viewModel: timelineViewModel,
            commandExecutor: timelineViewModel.commandExecutor
        )
        let mcpDispatcher = MCPTimelineToolDispatcher(scriptEngine: scriptEngine)
        let transport = LocalNWServerTransport(port: 4088)
        transport.delegate = mcpDispatcher
        do {
            try transport.start()
        } catch {
            // Port might be occupied; fails safely without crashing
        }
        self.mcpTransport = transport
    }

    var body: some Scene {
        WindowGroup {
            MainLayoutView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    viewModel.timelineViewModel.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.timelineViewModel.canUndo)

                Button("Redo") {
                    viewModel.timelineViewModel.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.timelineViewModel.canRedo)
            }
            CommandGroup(after: .newItem) {
                Button("Import Project Script...") {
                    TimelineProjectIO.importProjectScript(
                        into: viewModel.timelineViewModel,
                        mediaLibraryViewModel: viewModel.mediaLibraryViewModel
                    )
                    viewModel.updateTimelinePreview()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Project Script...") {
                    TimelineProjectIO.exportProjectScript(from: viewModel.timelineViewModel)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }

    private static func registerAllTabs(
        in registry: TabRegistry,
        mediaViewModel: MediaLibraryViewModel,
        timelineViewModel: TimelineViewModel
    ) {
        registry.register(MediaTabDescriptor(mediaViewModel: mediaViewModel))
        registry.register(AudioTabDescriptor())
        registry.register(TextTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(AdjustmentTabDescriptor(timelineViewModel: timelineViewModel))
    }
}
