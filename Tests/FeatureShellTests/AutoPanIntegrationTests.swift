import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
@testable import Domain
@testable import FeatureShell

@Suite("AutoPanIntegrationTests")
@MainActor
struct AutoPanIntegrationTests {
    @Test("TimelineCompositionBuilder detects active Auto Pan and routes to TimelineVideoCompositor")
    func testTimelineCompositionBuilderWithActiveAutoPan() {
        let keyframes = [
            AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.3),
            AutoPanKeyframe(timeSeconds: 5.0, normalizedX: 0.7)
        ]
        let autoPan = AutoPanConfiguration(isEnabled: true, smoothness: 0.5, keyframes: keyframes)
        guard let encoded = autoPan.encodeToString() else {
            Issue.record("Failed to encode AutoPanConfiguration")
            return
        }

        let clipWithAutoPan = TimelineClip(
            name: "AutoPan Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            properties: ["autoPanConfig": .string(encoded)]
        )
        let layer = TimelineLayer(kind: .video, clips: [clipWithAutoPan])
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [layer]))

        let comp = AVMutableComposition()
        let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        guard let track else {
            Issue.record("Failed to create mock track")
            return
        }

        let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: [layer],
            composition: comp,
            layerTrackIDs: [layer.id: track.trackID],
            aspectRatio: .ratio9x16,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        #expect(videoComp?.customVideoCompositorClass == TimelineVideoCompositor.self)
        guard let instruction = videoComp?.instructions.first as? TimelineCustomVideoCompositionInstruction else {
            Issue.record("Instruction is not TimelineCustomVideoCompositionInstruction")
            return
        }
        #expect(instruction.layerInfos.count == 1)
        let layerInfo = instruction.layerInfos[0]
        #expect(layerInfo.autoPanConfig?.isEnabled == true)
        #expect(layerInfo.autoPanConfig?.keyframes.count == 2)
    }

    @Test("InspectorViewModel interacts with AI tab and persists autoPanConfig")
    func testInspectorViewModelAITabPersistence() {
        let vm = TimelineViewModel(initialLayers: [])
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample_video.mp4"), type: .video)
        vm.addAsset(asset, at: .zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.availableTabs.contains("AI"))
        inspectorVM.selectedTab = "AI"
        #expect(inspectorVM.effectiveTab == "AI")

        // Set Auto Pan config
        let config = AutoPanConfiguration(isEnabled: true, smoothness: 0.8, keyframes: [
            AutoPanKeyframe(timeSeconds: 1.0, normalizedX: 0.4)
        ])
        guard let encoded = config.encodeToString() else { return }

        inspectorVM.updateDiscreteString(key: "autoPanConfig", value: encoded)

        // Verify clip on timeline has updated property
        let updatedClip = vm.clip(by: clip.id)
        let savedConfigStr = updatedClip?.properties["autoPanConfig"]?.asString
        #expect(savedConfigStr != nil)
        let decoded = savedConfigStr.flatMap { AutoPanConfiguration.decode(from: $0) }
        #expect(decoded?.isEnabled == true)
        #expect(abs((decoded?.smoothness ?? 0.0) - 0.8) < 0.001)

        // Test Undo
        #expect(vm.canUndo == true)
        vm.undo()
        let undoneClip = vm.clip(by: clip.id)
        #expect(undoneClip?.properties["autoPanConfig"] == nil)

        // Test Redo
        #expect(vm.canRedo == true)
        vm.redo()
        let redoneClip = vm.clip(by: clip.id)
        #expect(redoneClip?.properties["autoPanConfig"]?.asString != nil)
    }

    @Test("Background subject tracking survives tab switch and updates clip on completion")
    func testBackgroundSubjectTrackingSurvivesTabSwitch() async throws {
        let expectedKeyframes = [
            AutoPanKeyframe(timeSeconds: 0.0, normalizedX: 0.4),
            AutoPanKeyframe(timeSeconds: 2.0, normalizedX: 0.6)
        ]
        let mockService = MockSubjectTrackingService(keyframes: expectedKeyframes)
        let vm = TimelineViewModel(
            subjectTrackingService: mockService,
            initialLayers: []
        )
        let asset = MediaAsset(url: URL(fileURLWithPath: "/tmp/sample_background.mp4"), type: .video)
        vm.addAsset(asset, at: CMTime.zero)

        guard let clip = vm.layers.first?.clips.first else {
            Issue.record("Clip not found")
            return
        }

        vm.selectClip(clip.id)
        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        inspectorVM.selectedTab = "AI"

        // 1. Start tracking
        vm.startSubjectTracking(for: clip.id, smoothness: 0.5)
        #expect(vm.isTrackingSubject(for: clip.id) == true)

        // 2. Simulate user switching to "Video" tab or other tabs while tracking is in progress
        inspectorVM.selectedTab = "Video"
        #expect(inspectorVM.selectedTab == "Video")
        #expect(vm.isTrackingSubject(for: clip.id) == true)

        // 3. Wait for background task to complete
        for _ in 0..<50 {
            if !vm.isTrackingSubject(for: clip.id) { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(vm.isTrackingSubject(for: clip.id) == false)
        let completedClip = vm.clip(by: clip.id)
        let configStr = completedClip?.properties["autoPanConfig"]?.asString
        #expect(configStr != nil)

        let decoded = configStr.flatMap { AutoPanConfiguration.decode(from: $0) }
        #expect(decoded?.isEnabled == true)
        #expect(decoded?.keyframes.count == 2)

        // 4. Switch back to "AI" tab and sync
        inspectorVM.selectedTab = "AI"
        inspectorVM.syncWithSelection()
        let liveConfig = inspectorVM.liveProperties["autoPanConfig"]?.asString.flatMap {
            AutoPanConfiguration.decode(from: $0)
        }
        #expect(liveConfig?.isEnabled == true)
        #expect(liveConfig?.keyframes.count == 2)
    }
}

private struct MockSubjectTrackingService: SubjectTrackingServiceProtocol {
    let keyframes: [AutoPanKeyframe]

    func trackSubject(
        in mediaURL: URL,
        timeRange: CMTimeRange,
        samplesPerSecond: Double,
        smoothness: Double,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> [AutoPanKeyframe] {
        onProgress?(0.5)
        try await Task.sleep(nanoseconds: 20_000_000)
        onProgress?(1.0)
        return keyframes
    }
}
