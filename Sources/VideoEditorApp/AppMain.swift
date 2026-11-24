import AppKit
import SwiftUI
import OSLog
import Domain
import FeatureShell
import Infrastructure

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private let appLogger = Logger(subsystem: "com.videoeditor.app", category: "AppMain")

@main
struct VideoEditorApp: App {
    private static let logger = appLogger

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel: ShellViewModel
    private let mcpTransport: (any MCPServerTransport)?
    private let memoryPressureMonitor = SystemMemoryPressureMonitor()

    init() {
        let dependencies = EditorDependencies()
        Self.configureCloudRepositories(for: dependencies)

        let registry = TabRegistry()
        let audioWaveformService = AudioWaveformService()
        let mediaViewModel = MediaLibraryViewModel(
            thumbnailService: MediaThumbnailService(),
            waveformService: audioWaveformService
        )
        let timelineViewModel = TimelineViewModel(
            thumbnailService: TimelineThumbnailService(),
            waveformService: audioWaveformService,
            audioAlignmentService: AudioAlignmentService(),
            audioBeatDetectionService: AudioBeatDetectionService(),
            audioReactiveAnalysisService: AudioReactiveAnalysisService(),
            subjectTrackingService: VisionSubjectTrackingService(),
            dependencies: dependencies
        )
        let shellViewModel = ShellViewModel(
            registry: registry,
            timelineViewModel: timelineViewModel,
            mediaLibraryViewModel: mediaViewModel
        )

        Self.bindCrossModuleCallbacks(
            shellViewModel: shellViewModel,
            mediaViewModel: mediaViewModel,
            timelineViewModel: timelineViewModel
        )
        Self.registerAllTabs(in: registry, mediaViewModel: mediaViewModel, timelineViewModel: timelineViewModel)
        _viewModel = State(initialValue: shellViewModel)

        let scriptEngine = TimelineScriptEngine(
            viewModel: timelineViewModel,
            commandExecutor: timelineViewModel.commandExecutor
        )
        let mcpDispatcher = MCPTimelineToolDispatcher(
            scriptEngine: scriptEngine,
            mediaLibraryViewModel: mediaViewModel,
            dependencies: dependencies
        )
        let transport = LocalNWServerTransport(port: 4088)
        transport.delegate = mcpDispatcher
        do {
            try transport.start()
        } catch {
            Self.logger.error("Failed to start MCP port 4088: \(error.localizedDescription, privacy: .public)")
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
                Button(String(localized: "Undo")) {
                    viewModel.timelineViewModel.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.timelineViewModel.canUndo)

                Button(String(localized: "Redo")) {
                    viewModel.timelineViewModel.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.timelineViewModel.canRedo)
            }
            CommandGroup(after: .newItem) {
                Button(String(localized: "Open Project...")) {
                    TimelineProjectIO.openProject(
                        into: viewModel.timelineViewModel,
                        mediaLibraryViewModel: viewModel.mediaLibraryViewModel
                    )
                    viewModel.updateTimelinePreview()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(String(localized: "Save Project")) {
                    TimelineProjectIO.saveProject(from: viewModel.timelineViewModel)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button(String(localized: "Save Project As...")) {
                    TimelineProjectIO.saveProject(from: viewModel.timelineViewModel, saveAs: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button(String(localized: "Export Video MP4...")) {
                    viewModel.exportViewModel.openDialog(mediaType: .video)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button(String(localized: "Export Audio Only...")) {
                    viewModel.exportViewModel.openDialog(mediaType: .audio)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandMenu(String(localized: "Clip")) {
                Button(String(localized: "Duplicate Clip")) {
                    viewModel.timelineViewModel.duplicateClips()
                }
                .keyboardShortcut("d", modifiers: .command)

                Button(String(localized: "Split at Playhead")) {
                    _ = viewModel.timelineViewModel.splitClips(at: viewModel.playheadState.currentTime)
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button(String(localized: "Copy Attributes")) {
                    viewModel.timelineViewModel.copyAttributes()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button(String(localized: "Paste Attributes...")) {
                    viewModel.timelineViewModel.openPasteAttributesModal()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])

                Divider()

                Button(String(localized: "Trim Clip Start to Playhead")) {
                    viewModel.timelineViewModel.trimSelectedClipsToPlayhead(at: viewModel.playheadState.currentTime, isStart: true)
                }
                .keyboardShortcut("[", modifiers: .option)

                Button(String(localized: "Trim Clip End to Playhead")) {
                    viewModel.timelineViewModel.trimSelectedClipsToPlayhead(at: viewModel.playheadState.currentTime, isStart: false)
                }
                .keyboardShortcut("]", modifiers: .option)
            }
        }
    }

    private static func configureCloudRepositories(for dependencies: EditorDependencies) {
        let sharedClient = SupabaseConfig.sharedClient
        let adjustmentRepo = SupabaseAdjustmentPresetRepository(client: sharedClient, templateLoader: dependencies.adjustmentTemplates)
        let textRepo = SupabaseTextPresetRepository(client: sharedClient, templateLoader: dependencies.textTemplates)
        let actionRepo = SupabaseActionRepository(client: sharedClient)
        let audioRepo = SupabaseAudioLibraryRepository(client: sharedClient)
        let stockRepo = SupabaseStockMediaRepository(client: sharedClient)
        let favRepo = SupabaseFavoriteRepository(client: sharedClient)

        dependencies.presetRepositories.adjustmentRepository = adjustmentRepo
        dependencies.presetRepositories.textRepository = textRepo
        dependencies.presetRepositories.audioRepository = audioRepo
        dependencies.presetRepositories.stockMediaRepository = stockRepo
        dependencies.presetRepositories.favoriteRepository = favRepo
        dependencies.actionRepositories.actionRepository = actionRepo

        SidebarFavoriteManager.shared.configure(repository: favRepo)

        Task {
            await prefetchPresetsSafely(
                adjustmentRepo: adjustmentRepo, textRepo: textRepo,
                actionRepo: actionRepo, audioRepo: audioRepo, stockRepo: stockRepo
            )
        }
    }

    private static func prefetchPresetsSafely(
        adjustmentRepo: SupabaseAdjustmentPresetRepository,
        textRepo: SupabaseTextPresetRepository,
        actionRepo: SupabaseActionRepository,
        audioRepo: SupabaseAudioLibraryRepository,
        stockRepo: SupabaseStockMediaRepository
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { do { _ = try await adjustmentRepo.fetchPresets() } catch { appLogger.warning("Prefetch adjustment_presets failed: \(String(describing: error))") } }
            group.addTask { do { _ = try await textRepo.fetchPresets() } catch { appLogger.warning("Prefetch text_presets failed: \(String(describing: error))") } }
            group.addTask { do { _ = try await actionRepo.fetchActions() } catch { appLogger.warning("Prefetch actions failed: \(String(describing: error))") } }
            group.addTask { do { _ = try await audioRepo.fetchAudioItems() } catch { appLogger.warning("Prefetch audio_library failed: \(String(describing: error))") } }
            group.addTask { do { _ = try await stockRepo.fetchStockItems() } catch { appLogger.warning("Prefetch stock_media failed: \(String(describing: error))") } }
        }
    }

    private static func bindCrossModuleCallbacks(
        shellViewModel: ShellViewModel,
        mediaViewModel: MediaLibraryViewModel,
        timelineViewModel: TimelineViewModel
    ) {
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
        timelineViewModel.onAssetsAdded = { [weak mediaViewModel] addedAssets in
            for asset in addedAssets {
                mediaViewModel?.registerAssetIfNeeded(asset)
            }
        }
    }

    private static func registerAllTabs(
        in registry: TabRegistry,
        mediaViewModel: MediaLibraryViewModel,
        timelineViewModel: TimelineViewModel
    ) {
        registry.register(MediaTabDescriptor(mediaViewModel: mediaViewModel, dependencies: timelineViewModel.dependencies))
        registry.register(AudioTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(AdjustmentTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(TextTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(EffectTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(TransitionTabDescriptor(timelineViewModel: timelineViewModel))
        registry.register(StickerTabDescriptor(timelineViewModel: timelineViewModel))
    }
}
