import Foundation
import Observation
import Domain

/// Trạng thái tiến trình của từng tác vụ trong danh sách checklist.
public enum TaskExecutionState: Sendable, Equatable {
    case idle
    case running
    case completed
    case failed
}

/// DTO mô tả mẫu Preset chữ nghệ thuật cho menu lựa chọn.
public struct TextPresetItemInfo: Identifiable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// ViewModel điều phối Sidebar Tác vụ & Checklist Action (Offline Native Automation).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R3.2 (@Observable).
@Observable
@MainActor
public final class ActionsPanelViewModel {
    public weak var timelineViewModel: TimelineViewModel?
    public weak var mediaLibraryViewModel: MediaLibraryViewModel? {
        didSet { dispatcher?.mediaLibraryViewModel = mediaLibraryViewModel }
    }

    public var actions: [CustomAction] = CustomAction.defaultActions
    public var selectedActionID: String? = CustomAction.defaultActions.first?.id
    public var tasks: [WorkflowTaskItem] = WorkflowTaskItem.allTasks
    public var selectedTaskIDs: Set<String> = Set(CustomAction.defaultActions.first?.taskIDs ?? [])

    public var taskStates: [String: TaskExecutionState] = [:]
    public var titleText: String = ""
    public var titlePresetID: String = ""
    public var availableTextPresets: [TextPresetItemInfo] = []
    public var isTitlePadExpanded: Bool = false
    public var isAddActionModalPresented: Bool = false

    public var isProcessing: Bool = false
    public var statusMessage: String?
    public var errorMessage: String?

    public let dependencies: EditorDependencies
    var dispatcher: MCPTimelineToolDispatcher?
    private var presetObserver: (any NSObjectProtocol)?

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil,
        dependencies: EditorDependencies? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        self.mediaLibraryViewModel = mediaLibraryViewModel
        self.dependencies = dependencies ?? timelineViewModel?.dependencies ?? EditorDependencies()
        self.actions = CustomAction.defaultActions
        if let timelineViewModel {
            configure(timelineViewModel: timelineViewModel, mediaLibraryViewModel: mediaLibraryViewModel)
        }
        loadActions()
        loadOnlineTextPresets()
        setupPresetObserver()
    }

    public func configure(
        timelineViewModel: TimelineViewModel,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        if let mediaLibraryViewModel {
            self.mediaLibraryViewModel = mediaLibraryViewModel
        }
        let scriptEngine = TimelineScriptEngine(viewModel: timelineViewModel)
        self.dispatcher = MCPTimelineToolDispatcher(
            scriptEngine: scriptEngine,
            mediaLibraryViewModel: self.mediaLibraryViewModel,
            dependencies: dependencies
        )
    }

    public func loadActions() {
        Task {
            guard let repo = dependencies.actionRepositories.actionRepository,
                  let fetched = try? await repo.fetchActions() else { return }
            self.actions = fetched
            if let first = fetched.first, self.selectedActionID == nil || !fetched.contains(where: { $0.id == self.selectedActionID }) {
                self.selectAction(first)
            } else if fetched.isEmpty {
                self.selectedActionID = nil; self.selectedTaskIDs = []
            }
        }
    }

    // MARK: - Action & Task Selection

    public func selectAction(_ action: CustomAction) {
        selectedActionID = action.id
        selectedTaskIDs = Set(action.taskIDs)
        if let text = action.titleText { titleText = text }
        if let preset = action.titlePresetID, !preset.isEmpty {
            let matched = availableTextPresets.first {
                $0.id.caseInsensitiveCompare(preset) == .orderedSame ||
                $0.name.caseInsensitiveCompare(preset) == .orderedSame
            }
            if let matched {
                titlePresetID = matched.id
            } else if let first = availableTextPresets.first {
                titlePresetID = first.id
            } else {
                titlePresetID = preset
            }
        } else if let first = availableTextPresets.first {
            titlePresetID = first.id
        }
        taskStates = [:]
        statusMessage = nil
    }

    public func cycleAction(forward: Bool) {
        guard !actions.isEmpty else { return }
        guard let currentID = selectedActionID,
              let currentIndex = actions.firstIndex(where: { $0.id == currentID }) else {
            if let first = actions.first { selectAction(first) }
            return
        }
        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % actions.count
        } else {
            nextIndex = (currentIndex - 1 + actions.count) % actions.count
        }
        selectAction(actions[nextIndex])
    }

    public func toggleTaskSelection(id: String) {
        if selectedTaskIDs.contains(id) { selectedTaskIDs.remove(id) } else { selectedTaskIDs.insert(id) }
        taskStates[id] = .idle
    }

    // MARK: - Text Presets Catalog (Online Only)

    public func loadOnlineTextPresets() {
        Task {
            if let repo = dependencies.presetRepositories.textRepository {
                if let fresh = try? await repo.fetchPresets(), !fresh.isEmpty {
                    self.availableTextPresets = fresh.map { TextPresetItemInfo(id: $0.id, name: $0.name) }
                    self.dependencies.textTemplates.setInMemoryTemplates(fresh)
                    let matched = self.availableTextPresets.first {
                        $0.id.caseInsensitiveCompare(self.titlePresetID) == .orderedSame ||
                        $0.name.caseInsensitiveCompare(self.titlePresetID) == .orderedSame
                    }
                    if let matched {
                        self.titlePresetID = matched.id
                    } else if let first = fresh.first {
                        self.titlePresetID = first.id
                    }
                    return
                }
            }
            let inMemory = dependencies.textTemplates.loadAllTemplates()
            if !inMemory.isEmpty {
                self.availableTextPresets = inMemory.map { TextPresetItemInfo(id: $0.id, name: $0.name) }
                let matched = self.availableTextPresets.first {
                    $0.id.caseInsensitiveCompare(self.titlePresetID) == .orderedSame ||
                    $0.name.caseInsensitiveCompare(self.titlePresetID) == .orderedSame
                }
                if let matched {
                    self.titlePresetID = matched.id
                } else if let first = inMemory.first {
                    self.titlePresetID = first.id
                }
            }
        }
    }

    private func setupPresetObserver() {
        presetObserver = NotificationCenter.default.addObserver(
            forName: .presetStoreDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadOnlineTextPresets()
            }
        }
    }

    public var selectedPresetName: String {
        availableTextPresets.first(where: {
            $0.id.caseInsensitiveCompare(titlePresetID) == .orderedSame ||
            $0.name.caseInsensitiveCompare(titlePresetID) == .orderedSame
        })?.name ?? (availableTextPresets.first?.name ?? "Mẫu chữ trực tuyến")
    }

    public var currentAction: CustomAction? {
        actions.first(where: { $0.id == selectedActionID }) ?? actions.first
    }

    public var currentActionTasks: [WorkflowTaskItem] {
        guard let action = currentAction else { return [] }
        return action.taskIDs.compactMap { WorkflowTaskItem.find(by: $0) }
    }

    func prepareDispatcher() {
        if dispatcher == nil, let timelineViewModel {
            configure(timelineViewModel: timelineViewModel, mediaLibraryViewModel: mediaLibraryViewModel)
        }
    }
}
