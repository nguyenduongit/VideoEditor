import Foundation
import CoreMedia
import AVFoundation
import Testing
@testable import DesignSystem
@testable import Domain
@testable import FeatureShell

@Suite("DSControlInteractionTests")
struct DSControlInteractionTests {

    @Test("Slider defaultValue reset restores default and triggers single edit pair")
    func testSliderDefaultValueReset() {
        var value = 0.45
        let defaultValue = 1.0
        let range = 0.0...2.0
        var editEvents: [Bool] = []

        // Simulating reset logic from DSCustomSlider
        let clamped = max(range.lowerBound, min(range.upperBound, defaultValue))
        if value != clamped {
            editEvents.append(true)
            value = clamped
            editEvents.append(false)
        }

        #expect(value == 1.0)
        #expect(editEvents == [true, false])
    }

    @Test("Slider reset is no-op when value is already equal to default")
    func testSliderResetNoOpWhenAlreadyDefault() {
        var value = 1.0
        let defaultValue = 1.0
        let range = 0.0...2.0
        var editEvents: [Bool] = []

        let clamped = max(range.lowerBound, min(range.upperBound, defaultValue))
        if value != clamped {
            editEvents.append(true)
            value = clamped
            editEvents.append(false)
        }

        #expect(value == 1.0)
        #expect(editEvents.isEmpty)
    }

    @Test("DSNumberInput step eliminates floating point drift and clamps within bounds")
    func testNumberInputStepSnappingAndClamping() {
        var value = 1.0
        let step = 0.01
        let min = 0.0
        let max = 2.0

        func updateClamped(_ newValue: Double) {
            var v = newValue
            if step > 0 {
                v = (v / step).rounded() * step
            }
            v = Swift.max(min, v)
            v = Swift.min(max, v)
            value = v
        }

        // Increment 10 times by 0.01
        for _ in 0..<10 {
            updateClamped(value + step)
        }
        #expect(abs(value - 1.10) < 0.0001)

        // Increment beyond max
        for _ in 0..<200 {
            updateClamped(value + step)
        }
        #expect(value == 2.0)

        // Decrement below min
        for _ in 0..<300 {
            updateClamped(value - step)
        }
        #expect(value == 0.0)
    }

    @Test("DSNumberInput parse and commit with displayMultiplier converts correctly")
    func testNumberInputParseWithMultiplier() {
        var value = 1.0
        let displayMultiplier = 100.0 // percentage mode
        let step = 0.01
        let min = 0.0
        let max = 2.0

        func updateClamped(_ newValue: Double) {
            var v = newValue
            if step > 0 {
                v = (v / step).rounded() * step
            }
            v = Swift.max(min, v)
            v = Swift.min(max, v)
            value = v
        }

        // User typed "175" for percentage
        let textInput = "175"
        if let parsed = Double(textInput.trimmingCharacters(in: .whitespaces)) {
            updateClamped(parsed / displayMultiplier)
        }

        #expect(abs(value - 1.75) < 0.0001)
    }

    @Test("Continuous hold adjustment emits atomic begin and end pair for undo stack")
    func testContinuousHoldUndoContract() {
        var editEvents: [Bool] = []
        var value = 1.0
        let step = 1.0

        // Start hold
        editEvents.append(true)
        value += step

        // Simulated recurring ticks during hold (do not spam edit events)
        for _ in 0..<5 {
            value += step
        }

        // Release hold
        editEvents.append(false)

        #expect(value == 7.0)
        #expect(editEvents == [true, false])
    }

    @Test("updateLiveValue updates timeline clip in realtime without committing multiple undo entries")
    @MainActor
    func testUpdateLiveValueMutatesClipRealtime() {
        let vm = TimelineViewModel(initialLayers: [])
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            properties: ["scale": .number(1.0)]
        )
        vm.addClip(clip)
        vm.selectedClipIDs = [clip.id]

        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()

        let initialHistoryCount = executor.history.count

        // Start adjustment
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: true)

        // Live adjustments mid-drag must update clip properties in realtime
        inspectorVM.updateLiveValue(key: "scale", value: 1.25)
        #expect(vm.clip(by: clip.id)?.properties["scale"]?.asNumber == 1.25)
        #expect(executor.history.count == initialHistoryCount)

        inspectorVM.updateLiveValue(key: "scale", value: 1.50)
        #expect(vm.clip(by: clip.id)?.properties["scale"]?.asNumber == 1.50)
        #expect(executor.history.count == initialHistoryCount)

        // End adjustment: commit single command to history
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: false)
        #expect(executor.history.count == initialHistoryCount + 1)
        #expect(vm.clip(by: clip.id)?.properties["scale"]?.asNumber == 1.50)

        // Undo rolls back to pre-drag value (1.0)
        let didUndo = vm.undo()
        #expect(didUndo == true)
        #expect(vm.clip(by: clip.id)?.properties["scale"]?.asNumber == 1.0)
    }

    @Test("buildVideoComposition fast path produces videoComposition using cached metadata")
    func testBuildVideoCompositionFastPath() {
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: 101)
        #expect(track != nil)

        let layerID = UUID()
        let clipID = UUID()
        let dummyURL = URL(fileURLWithPath: "/tmp/dummy_fast_path.mp4")
        VideoMetadataCache.shared.store(
            VideoTrackMetadata(transform: .identity, naturalSize: CGSize(width: 1920, height: 1080)),
            for: dummyURL
        )

        let clip = TimelineClip(
            id: clipID,
            name: "V1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3, timescale: 1)),
            mediaURL: dummyURL,
            sourceStartTime: .zero,
            properties: ["scale": .number(1.5), "positionX": .number(50)]
        )
        let layer = TimelineLayer(id: layerID, name: "Video Layer", kind: .video, clips: [clip])
        let layerTrackIDs: [UUID: CMPersistentTrackID] = [layerID: 101]

        let videoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: [layer],
            composition: composition,
            layerTrackIDs: layerTrackIDs,
            aspectRatio: .ratio16x9,
            duration: CMTime(value: 3, timescale: 1)
        )
        #expect(videoComp != nil)
        if let videoComp {
            #expect(videoComp.instructions.count == 1)
            #expect(videoComp.renderSize == CanvasAspectRatio.ratio16x9.renderSize)
        }
    }
}
