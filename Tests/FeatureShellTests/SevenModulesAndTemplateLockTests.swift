import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("Seven Modules & Open Template Core Tests")
@MainActor
struct SevenModulesAndTemplateLockTests {
    @Test("Both Basic Text and Text Presets share the unified 3-tab Inspector (Text, Background, Animation)")
    func textTemplatesUnlockAllThreeTabs() {
        let registry = ClipPropertyRegistry()
        let timelineViewModel = TimelineViewModel()
        let inspectorViewModel = InspectorViewModel(timelineViewModel: timelineViewModel, propertyRegistry: registry)

        timelineViewModel.addTextClip(named: "Basic Text", config: TextConfiguration(content: "Xin chào"))
        inspectorViewModel.syncWithSelection()
        #expect(!inspectorViewModel.isSelectedClipLockedTemplate)
        #expect(inspectorViewModel.availableTabs == ["Text", "Background", "Animation"])

        let preset = TextPreset(
            id: "cinema_epic_3d",
            name: "Cinema Epic",
            description: "Chữ điện ảnh mở khóa toàn phần",
            category: .cinema,
            config: TextConfiguration(content: "EPIC MOVIE")
        )
        timelineViewModel.addTextPreset(preset)
        inspectorViewModel.syncWithSelection()
        #expect(!inspectorViewModel.isSelectedClipLockedTemplate)
        #expect(inspectorViewModel.selectedClip?.originPresetID == "cinema_epic_3d")
        #expect(inspectorViewModel.availableTabs == ["Text", "Background", "Animation"])
    }

    @Test("Adjustment template unlocks all 5 Color Grading tabs while retaining originPresetID")
    func adjustmentTemplateUnlocksAllGradingTabs() {
        let registry = ClipPropertyRegistry()
        let timelineViewModel = TimelineViewModel()
        let inspectorViewModel = InspectorViewModel(timelineViewModel: timelineViewModel, propertyRegistry: registry)

        timelineViewModel.addAdjustmentClip(
            named: "Vintage 1980s",
            config: AdjustmentConfiguration(),
            durationSeconds: 5.0,
            originPresetID: "vintage_1980s"
        )
        inspectorViewModel.syncWithSelection()
        #expect(!inspectorViewModel.isSelectedClipLockedTemplate)
        #expect(inspectorViewModel.selectedClip?.originPresetID == "vintage_1980s")
        #expect(inspectorViewModel.availableTabs == ["Basic", "HSL", "Wheels", "Curves", "Effects"])
    }

    @Test("CutTransition selection switches Inspector to Transition mode")
    func cutTransitionInspectorSelection() {
        let timelineViewModel = TimelineViewModel()
        let inspectorViewModel = InspectorViewModel(timelineViewModel: timelineViewModel)

        let clip1 = TimelineClip(name: "Clip 1", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3000, timescale: 600)))
        let clip2 = TimelineClip(name: "Clip 2", kind: .video, timeRange: CMTimeRange(start: CMTime(value: 3000, timescale: 600), duration: CMTime(value: 3000, timescale: 600)))
        let layer = TimelineLayer(kind: .video, clips: [clip1, clip2])
        timelineViewModel.layers = [layer]

        let transition = timelineViewModel.addOrUpdateCutTransition(
            TransitionPreset.default,
            between: clip1.id,
            and: clip2.id
        )
        #expect(transition != nil)

        timelineViewModel.selectTransition(transition?.id)
        inspectorViewModel.syncWithSelection()

        #expect(inspectorViewModel.availableTabs == ["Transition"])
        #expect(inspectorViewModel.effectiveTab == "Transition")
        #expect(inspectorViewModel.selectedTransition?.presetID == "dissolve_default")

        inspectorViewModel.updateTransitionDuration(1.2)
        inspectorViewModel.updateTransitionAlignment(.startOnCut)

        #expect(abs((inspectorViewModel.selectedTransition?.duration.seconds ?? 0) - 1.2) < 0.01)
        #expect(inspectorViewModel.selectedTransition?.alignment == .startOnCut)
    }

    @Test("Sticker preset addition creates a .sticker clip with Sticker and Animation tabs")
    func stickerPresetAdditionAndProperties() {
        let timelineViewModel = TimelineViewModel()
        let inspectorViewModel = InspectorViewModel(timelineViewModel: timelineViewModel)

        let stickerPreset = StickerPreset(
            id: "test_heart_sticker",
            name: "Heart Like",
            description: "Heart animation",
            category: .social,
            format: .apng,
            tags: ["heart"],
            defaultDuration: 3.5,
            systemSymbolFallback: "heart.fill"
        )

        timelineViewModel.addStickerPreset(stickerPreset)
        inspectorViewModel.syncWithSelection()

        guard let clip = inspectorViewModel.selectedClip else {
            Issue.record("Sticker clip not added")
            return
        }
        #expect(clip.kind == .sticker)
        #expect(clip.name == "Heart Like")
        #expect(inspectorViewModel.availableTabs == ["Sticker", "Animation"])
        #expect(inspectorViewModel.effectiveTab == "Sticker")
    }

    @Test("MCP register template package and catalog listing")
    func mcpRegisterTemplatePackageAndCatalog() throws {
        let timelineViewModel = TimelineViewModel()
        let scriptEngine = TimelineScriptEngine(viewModel: timelineViewModel)
        let dependencies = EditorDependencies()
        let dispatcher = MCPTimelineToolDispatcher(
            scriptEngine: scriptEngine,
            mediaLibraryViewModel: nil,
            dependencies: dependencies
        )

        let newTransition = TransitionPreset(
            id: "custom_agent_wipe",
            name: "AI Agent Wipe",
            description: "Mẫu sinh tự động bởi Agent",
            category: .motion,
            shaderType: .whipPanRight
        )
        let jsonStr = try #require(newTransition.encodeToJSON())

        let registerArg = """
        {
            "kind": "transition",
            "payload": \(jsonStr)
        }
        """

        let regRes = try dispatcher.handleToolCall(toolName: "template_register_package", argumentsJSON: registerArg)
        #expect(regRes.contains("success"))

        let catalogJSON = try dispatcher.handleToolCall(toolName: "library_get_catalog", argumentsJSON: "{}")
        #expect(catalogJSON.contains("custom_agent_wipe"))
        #expect(catalogJSON.contains("transitionTemplates"))
        #expect(catalogJSON.contains("stickerTemplates"))
    }
}
