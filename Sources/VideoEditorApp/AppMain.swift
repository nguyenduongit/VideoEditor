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

@main
struct VideoEditorApp: App {
    private static let logger = Logger(subsystem: "com.videoeditor.app", category: "AppMain")

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
            Self.logger.error("Không thể khởi động cổng MCP 4088: \(error.localizedDescription, privacy: .public)")
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

                Button(String(localized: "Xuất Video MP4...")) {
                    viewModel.exportViewModel.openDialog(mediaType: .video)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button(String(localized: "Xuất Audio Only...")) {
                    viewModel.exportViewModel.openDialog(mediaType: .audio)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }

    private static func configureCloudRepositories(for dependencies: EditorDependencies) {
        let adjustmentRepo = SupabaseAdjustmentPresetRepository(templateLoader: dependencies.adjustmentTemplates)
        let textRepo = SupabaseTextPresetRepository(templateLoader: dependencies.textTemplates)
        let animationRepo = SupabaseAnimationPresetRepository(templateLoader: dependencies.animationTemplates)
        let effectRepo = SupabaseEffectPresetRepository(templateLoader: dependencies.effectTemplates)
        let stickerRepo = SupabaseStickerPresetRepository(templateLoader: dependencies.stickerTemplates)
        let transitionRepo = SupabaseTransitionPresetRepository(templateLoader: dependencies.transitionTemplates)
        let actionRepo = SupabaseActionRepository()
        let audioRepo = SupabaseAudioPresetRepository()
        let stockRepo = SupabaseStockMediaRepository()
        let favRepo = SupabaseFavoriteRepository()

        dependencies.presetRepositories.adjustmentRepository = adjustmentRepo
        dependencies.presetRepositories.textRepository = textRepo
        dependencies.presetRepositories.animationRepository = animationRepo
        dependencies.presetRepositories.effectRepository = effectRepo
        dependencies.presetRepositories.stickerRepository = stickerRepo
        dependencies.presetRepositories.transitionRepository = transitionRepo
        dependencies.presetRepositories.audioRepository = audioRepo
        dependencies.presetRepositories.stockMediaRepository = stockRepo
        dependencies.presetRepositories.favoriteRepository = favRepo
        dependencies.actionRepositories.actionRepository = actionRepo

        SidebarFavoriteManager.shared.configure(repository: favRepo)

        Task {
            await prefetchPresetsSafely(
                adjustmentRepo: adjustmentRepo, textRepo: textRepo, animationRepo: animationRepo,
                effectRepo: effectRepo, stickerRepo: stickerRepo, transitionRepo: transitionRepo,
                actionRepo: actionRepo, audioRepo: audioRepo, stockRepo: stockRepo
            )
        }
    }

    private static func prefetchPresetsSafely(
        adjustmentRepo: SupabaseAdjustmentPresetRepository,
        textRepo: SupabaseTextPresetRepository,
        animationRepo: SupabaseAnimationPresetRepository,
        effectRepo: SupabaseEffectPresetRepository,
        stickerRepo: SupabaseStickerPresetRepository,
        transitionRepo: SupabaseTransitionPresetRepository,
        actionRepo: SupabaseActionRepository,
        audioRepo: SupabaseAudioPresetRepository,
        stockRepo: SupabaseStockMediaRepository
    ) async {
        do { _ = try await adjustmentRepo.fetchPresets() } catch { logger.warning("Prefetch adjustment_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await textRepo.fetchPresets() } catch { logger.warning("Prefetch text_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await animationRepo.fetchPresets() } catch { logger.warning("Prefetch animation_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await effectRepo.fetchPresets() } catch { logger.warning("Prefetch effect_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await stickerRepo.fetchPresets() } catch { logger.warning("Prefetch sticker_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await transitionRepo.fetchPresets() } catch { logger.warning("Prefetch transition_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await actionRepo.fetchActions() } catch { logger.warning("Prefetch actions lỗi: \(error.localizedDescription)") }
        do { _ = try await audioRepo.fetchPresets() } catch { logger.warning("Prefetch audio_presets lỗi: \(error.localizedDescription)") }
        do { _ = try await stockRepo.fetchStockItems() } catch { logger.warning("Prefetch stock_media lỗi: \(error.localizedDescription)") }
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
