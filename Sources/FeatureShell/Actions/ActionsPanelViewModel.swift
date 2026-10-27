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
    private var dispatcher: MCPTimelineToolDispatcher?
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
        if let preset = action.titlePresetID { titlePresetID = preset }
        taskStates = [:]
        statusMessage = nil
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
                    if !fresh.contains(where: { $0.id == self.titlePresetID }), let first = fresh.first {
                        self.titlePresetID = first.id
                    }
                    return
                }
            }
            let inMemory = dependencies.textTemplates.loadAllTemplates()
            if !inMemory.isEmpty {
                self.availableTextPresets = inMemory.map { TextPresetItemInfo(id: $0.id, name: $0.name) }
                if !inMemory.contains(where: { $0.id == self.titlePresetID }), let first = inMemory.first {
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
        availableTextPresets.first(where: { $0.id.lowercased() == titlePresetID.lowercased() })?.name
            ?? (availableTextPresets.first?.name ?? "Mẫu chữ trực tuyến")
    }

    // MARK: - Execution

    public func executeSelectedTasks() {
        guard !isProcessing, !selectedTaskIDs.isEmpty else { return }
        prepareDispatcher()
        guard let dispatcher else {
            errorMessage = "Chưa kết nối được với Timeline."
            return
        }

        isProcessing = true
        taskStates = [:]
        errorMessage = nil
        let orderedTasks = tasks.filter { selectedTaskIDs.contains($0.id) }
        statusMessage = "Đang thực thi \(orderedTasks.count) tác vụ..."
        let startTime = CFAbsoluteTimeGetCurrent()

        Task {
            var completedCount = 0
            for task in orderedTasks {
                self.taskStates[task.id] = .running
                do {
                    try await executeSingleTask(id: task.id, dispatcher: dispatcher)
                    self.taskStates[task.id] = .completed
                    completedCount += 1
                } catch {
                    self.taskStates[task.id] = .failed
                }
            }
            await seekPlayheadToStart(dispatcher: dispatcher)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            self.statusMessage = String(format: "✓ Đã hoàn thành %d/%d tác vụ (%.2fs)", completedCount, orderedTasks.count, elapsed)
            self.isProcessing = false
        }
    }

    public func runTaskItem(_ task: WorkflowTaskItem) { selectedTaskIDs = [task.id]; executeSelectedTasks() }
    public func runActionItem(_ action: CustomAction) { selectAction(action); executeSelectedTasks() }

    private func seekPlayheadToStart(dispatcher: MCPTimelineToolDispatcher) async {
        _ = try? await dispatcher.handleToolCallAsync(toolName: "timeline_edit_clip", argumentsJSON: "{\"operation\": \"seek\", \"atTimeSeconds\": 0.0}")
        self.timelineViewModel?.seek(to: .zero)
    }

    private func executeSingleTask(id: String, dispatcher: MCPTimelineToolDispatcher) async throws {
        switch id {
        case "syncAudio":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_sync_audio",
                argumentsJSON: "{\"muteVideo\": true, \"trimExcessTail\": true}"
            )
        case "autoColor":
            let colorJSON = await computeDynamicAutoColorJSON(dispatcher: dispatcher)
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_apply_template",
                argumentsJSON: colorJSON
            )
        case "aspect916":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_edit_clip",
                argumentsJSON: "{\"operation\": \"setAspectRatio\", \"aspectRatio\": \"9:16\"}"
            )
        case "addTitle":
            let content = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tiêu đề video" : titleText
            var dict: [String: Any] = [
                "kind": "text",
                "customText": content,
                "position": "top",
                "startTimeSeconds": 0.0,
                "durationSeconds": 5.0
            ]
            if !titlePresetID.isEmpty { dict["templateId"] = titlePresetID }
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let jsonString = String(data: data, encoding: .utf8) {
                _ = try await dispatcher.handleToolCallAsync(
                    toolName: "timeline_apply_template",
                    argumentsJSON: jsonString
                )
            }
        case "visionFraming":
            _ = try await dispatcher.handleToolCallAsync(
                toolName: "timeline_ai_vision_framing",
                argumentsJSON: "{\"centerSubject\": true, \"enableAutoPan\": true, \"targetSubjectHeightRatio\": 0.33, \"enableLegStretch\": true, \"legStretchRatio\": 1.12}"
            )
        default:
            break
        }
    }

    public var currentAction: CustomAction? {
        actions.first(where: { $0.id == selectedActionID }) ?? actions.first
    }

    public var currentActionTasks: [WorkflowTaskItem] {
        guard let action = currentAction else { return [] }
        return action.taskIDs.compactMap { WorkflowTaskItem.find(by: $0) }
    }

    // MARK: - Action CRUD

    public func createNewAction(name: String, icon: String, taskIDs: [String]) {
        let newAction = CustomAction(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            taskIDs: taskIDs,
            titleText: titleText,
            titlePresetID: titlePresetID,
            createdAt: Date(),
            isSystem: false
        )
        actions.append(newAction)
        selectedActionID = newAction.id
        selectedTaskIDs = Set(taskIDs)
        Task {
            try? await dependencies.actionRepositories.actionRepository?.saveAction(newAction)
        }
        statusMessage = "Đã lưu Action mới: \(name)"
    }

    public func saveCurrentAsNewAction(name: String) {
        let orderedIDs = tasks.filter { selectedTaskIDs.contains($0.id) }.map(\.id)
        createNewAction(name: name, icon: "play.fill", taskIDs: orderedIDs.isEmpty ? (currentAction?.taskIDs ?? []) : orderedIDs)
    }

    public func deleteAction(id: String) {
        actions.removeAll { $0.id == id }
        if selectedActionID == id {
            selectedActionID = actions.first?.id
            if let first = actions.first {
                selectedTaskIDs = Set(first.taskIDs)
            }
        }
        Task {
            try? await dependencies.actionRepositories.actionRepository?.deleteAction(id: id)
        }
    }

    private func prepareDispatcher() {
        if dispatcher == nil, let timelineViewModel {
            configure(timelineViewModel: timelineViewModel, mediaLibraryViewModel: mediaLibraryViewModel)
        }
    }
}
