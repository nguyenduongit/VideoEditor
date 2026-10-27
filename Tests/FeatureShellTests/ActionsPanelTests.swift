import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("ActionsPanelTests")
@MainActor
struct ActionsPanelTests {

    @Test("ActionsPanelViewModel initializes with empty default actions and 5 standard tasks")
    func testInitialization() {
        let viewModel = ActionsPanelViewModel()
        #expect(viewModel.actions.isEmpty)
        #expect(viewModel.selectedActionID == nil)

        #expect(viewModel.tasks.count == 5)
        #expect(viewModel.tasks.contains { $0.id == "syncAudio" })
        #expect(viewModel.tasks.contains { $0.id == "autoColor" })
        #expect(viewModel.tasks.contains { $0.id == "aspect916" })
        #expect(viewModel.tasks.contains { $0.id == "addTitle" })
        #expect(viewModel.tasks.contains { $0.id == "visionFraming" })
        #expect(!viewModel.tasks.contains { $0.id == "seekStart" })
    }

    @Test("Selecting actions updates selectedActionID and task list")
    func testActionSelection() {
        let viewModel = ActionsPanelViewModel()
        let action1 = CustomAction(id: "custom_1", name: "Action 1", taskIDs: ["syncAudio", "autoColor"])
        let action2 = CustomAction(id: "custom_2", name: "Action 2", taskIDs: ["aspect916", "visionFraming", "addTitle"])
        viewModel.actions = [action1, action2]

        viewModel.selectAction(action1)
        #expect(viewModel.selectedActionID == "custom_1")
        #expect(viewModel.currentActionTasks.map(\.id) == ["syncAudio", "autoColor"])

        viewModel.selectAction(action2)
        #expect(viewModel.selectedActionID == "custom_2")
        #expect(viewModel.currentActionTasks.map(\.id) == ["aspect916", "visionFraming", "addTitle"])
    }

    @Test("Toggling task selection updates selectedTaskIDs")
    func testToggleTaskSelection() {
        let viewModel = ActionsPanelViewModel()
        viewModel.selectedTaskIDs = ["syncAudio"]

        viewModel.toggleTaskSelection(id: "aspect916")
        #expect(viewModel.selectedTaskIDs.contains("aspect916"))

        viewModel.toggleTaskSelection(id: "aspect916")
        #expect(!viewModel.selectedTaskIDs.contains("aspect916"))
    }

    @Test("Saving current selection as new action persists and selects it")
    func testSaveNewAction() {
        let viewModel = ActionsPanelViewModel()
        let initialCount = viewModel.actions.count

        viewModel.selectedTaskIDs = ["syncAudio", "autoColor"]
        viewModel.titleText = "My Video Intro"
        viewModel.titlePresetID = "custom_intro_preset"

        viewModel.saveCurrentAsNewAction(name: "Vlog Mùa Thu")
        #expect(viewModel.actions.count == initialCount + 1)
        guard let saved = viewModel.actions.first(where: { $0.name == "Vlog Mùa Thu" }) else {
            Issue.record("Failed to find saved action")
            return
        }

        #expect(viewModel.selectedActionID == saved.id)
        #expect(saved.taskIDs == ["syncAudio", "autoColor"])
        #expect(saved.titleText == "My Video Intro")
        #expect(saved.titlePresetID == "custom_intro_preset")
        #expect(!saved.isSystem)

        viewModel.deleteAction(id: saved.id)
        #expect(viewModel.actions.count == initialCount)
    }

    @Test("createNewAction creates custom ordered action and selects it")
    func testCreateNewActionWithCustomOrder() {
        let viewModel = ActionsPanelViewModel()
        let initialCount = viewModel.actions.count

        viewModel.createNewAction(
            name: "Custom Workflow",
            icon: "star.fill",
            taskIDs: ["aspect916", "visionFraming", "autoColor"]
        )

        #expect(viewModel.actions.count == initialCount + 1)
        #expect(viewModel.currentAction?.name == "Custom Workflow")
        #expect(viewModel.currentActionTasks.map(\.id) == ["aspect916", "visionFraming", "autoColor"])
    }

    @Test("Title pad supports configuring custom text and preset ID")
    func testTitlePadConfiguration() {
        let viewModel = ActionsPanelViewModel()
        #expect(!viewModel.isTitlePadExpanded)

        viewModel.isTitlePadExpanded = true
        #expect(viewModel.isTitlePadExpanded)

        viewModel.titleText = "Hành Trình Mới"
        #expect(viewModel.titleText == "Hành Trình Mới")

        viewModel.availableTextPresets = [
            TextPresetItemInfo(id: "preset_neon", name: "Neon Vàng Rực Rỡ")
        ]
        viewModel.titlePresetID = "preset_neon"
        #expect(viewModel.selectedPresetName.contains("Neon"))
    }

    @Test("Executing selected tasks updates taskStates to completed and seeks playhead to start")
    func testExecutionWithMockTimeline() async {
        let timelineVM = TimelineViewModel()
        timelineVM.seek(to: CMTime(seconds: 4.5, preferredTimescale: 600))
        #expect(CMTimeGetSeconds(timelineVM.currentTime) > 0)

        let viewModel = ActionsPanelViewModel(timelineViewModel: timelineVM)
        let action = CustomAction(id: "test_action", name: "Test Action", taskIDs: ["autoColor", "addTitle"])
        viewModel.actions = [action]
        viewModel.selectAction(action)
        viewModel.titleText = "Test Title"
        viewModel.titlePresetID = "test_preset_id"

        viewModel.executeSelectedTasks()
        #expect(viewModel.isProcessing)

        // Wait for asynchronous execution to complete
        try? await Task.sleep(nanoseconds: 250_000_000)

        #expect(!viewModel.isProcessing)
        #expect(viewModel.taskStates["autoColor"] == .completed)
        #expect(viewModel.taskStates["addTitle"] == .completed)
        #expect(viewModel.statusMessage?.contains("✓") == true)
        // Verify playhead automatically returned to start (0.0s)
        #expect(timelineVM.currentTime == .zero)
    }

    @Test("computeDynamicAutoColorJSON produces calibrated JSON with exposure and shadow offsets")
    func testComputeDynamicAutoColorJSON() async {
        let timelineVM = TimelineViewModel()
        let viewModel = ActionsPanelViewModel(timelineViewModel: timelineVM)
        let engine = TimelineScriptEngine(viewModel: timelineVM)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let json = await viewModel.computeDynamicAutoColorJSON(dispatcher: dispatcher)
        #expect(json.contains("adjustment"))
        #expect(json.contains("Cân chỉnh màu tự động"))
        #expect(json.contains("exposure"))
        #expect(json.contains("shadow"))
    }
}
