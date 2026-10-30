import Testing
import Foundation
import CoreMedia
import CoreImage
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
        let validVideoURL = ProceduralAssetProvider.shared.blackVideoURL()
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.5, preferredTimescale: 600)),
            mediaURL: validVideoURL
        )
        timelineVM.addClip(clip)
        timelineVM.seek(to: CMTime(seconds: 0.4, preferredTimescale: 600))
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
        for _ in 0..<50 {
            if !viewModel.isProcessing { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(!viewModel.isProcessing)
        #expect(viewModel.taskStates["autoColor"] == .completed)
        #expect(viewModel.taskStates["addTitle"] == .completed)
        #expect(viewModel.statusMessage?.contains("✓") == true)
        // Verify playhead automatically returned to start (0.0s)
        #expect(timelineVM.currentTime == .zero)
    }

    @Test("computeDynamicAutoColorJSON produces calibrated JSON with exposure and shadow offsets")
    func testComputeDynamicAutoColorJSON() async throws {
        let timelineVM = TimelineViewModel()
        let validVideoURL = ProceduralAssetProvider.shared.blackVideoURL()
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.5, preferredTimescale: 600)),
            mediaURL: validVideoURL
        )
        timelineVM.addClip(clip)

        let viewModel = ActionsPanelViewModel(timelineViewModel: timelineVM)
        let engine = TimelineScriptEngine(viewModel: timelineVM)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        let json = try await viewModel.computeDynamicAutoColorJSON(dispatcher: dispatcher)
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to parse AutoColor JSON")
            return
        }

        #expect(dict["kind"] as? String == "adjustment")
        // Dark procedural video -> AutoColorEngine boosts exposure (> 0) and shadow (> 0)
        let exposure = try #require(dict["exposure"] as? Int)
        let shadow = try #require(dict["shadow"] as? Int)
        #expect(exposure >= 5)
        #expect(shadow >= 10)
    }

    @Test("HistogramEngine analyzeTelemetry ignores letterbox black bars when computing blackPoint")
    func testHistogramEngineLetterboxExclusion() {
        let engine = HistogramEngine()
        // Create 128x72 image with mid-gray active area (y: 12..<60) and black letterbox bars top/bottom
        let baseBlack = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 128, height: 72))
        let midGrayCenter = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 12, width: 128, height: 48))
        let composited = midGrayCenter.composited(over: baseBlack)

        let telemetry = engine.analyzeTelemetry(from: composited)

        #expect(telemetry.averageLuma > 0.45 && telemetry.averageLuma < 0.55)
        #expect(telemetry.blackPoint > 0.40)
        #expect(telemetry.shadowClippingRatio == 0.0)
    }

    @Test("computeDynamicAutoColorJSON throws when video file does not exist")
    func testComputeDynamicAutoColorJSONThrowsOnUnreadableFile() async {
        let timelineVM = TimelineViewModel()
        let clip = TimelineClip(
            name: "Missing Clip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            mediaURL: URL(fileURLWithPath: "/tmp/non_existent_video_file_12345.mp4")
        )
        timelineVM.addClip(clip)

        let viewModel = ActionsPanelViewModel(timelineViewModel: timelineVM)
        let engine = TimelineScriptEngine(viewModel: timelineVM)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        await #expect(throws: AppError.self) {
            _ = try await viewModel.computeDynamicAutoColorJSON(dispatcher: dispatcher)
        }
    }

    @Test("computeDynamicAutoColorJSON throws when timeline has no video clip")
    func testComputeDynamicAutoColorJSONThrowsWhenEmpty() async {
        let timelineVM = TimelineViewModel()
        let viewModel = ActionsPanelViewModel(timelineViewModel: timelineVM)
        let engine = TimelineScriptEngine(viewModel: timelineVM)
        let dispatcher = MCPTimelineToolDispatcher(scriptEngine: engine)

        await #expect(throws: AppError.self) {
            _ = try await viewModel.computeDynamicAutoColorJSON(dispatcher: dispatcher)
        }
    }

    @Test("cycleAction steps forward and backward with wrapping")
    func testCycleAction() {
        let viewModel = ActionsPanelViewModel()
        let a1 = CustomAction(id: "a1", name: "Action 1", taskIDs: [])
        let a2 = CustomAction(id: "a2", name: "Action 2", taskIDs: [])
        let a3 = CustomAction(id: "a3", name: "Action 3", taskIDs: [])
        viewModel.actions = [a1, a2, a3]
        viewModel.selectAction(a1)

        viewModel.cycleAction(forward: true)
        #expect(viewModel.selectedActionID == "a2")

        viewModel.cycleAction(forward: true)
        #expect(viewModel.selectedActionID == "a3")

        viewModel.cycleAction(forward: true)
        #expect(viewModel.selectedActionID == "a1")

        viewModel.cycleAction(forward: false)
        #expect(viewModel.selectedActionID == "a3")
    }
}

