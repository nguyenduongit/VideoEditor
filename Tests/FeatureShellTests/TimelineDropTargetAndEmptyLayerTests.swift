import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

@Suite("TimelineDropTargetAndEmptyLayerTests")
@MainActor
struct TimelineDropTargetAndEmptyLayerTests {

    @Test func testDropTargetMiddle10PercentBandHighlightsBoundary() {
        let vm = TimelineViewModel(initialLayers: [])
        _ = vm.createLayer(for: .effect)
        _ = vm.createLayer(for: .effect)
        let topLayer = vm.layers[0]
        let bottomLayer = vm.layers[1]
        let h = vm.layerHeight(for: .effect)

        // Starting from sourceIndex = 0 (top layer).
        // boundary between layer 0 and layer 1 is at +h/2 (downwards from center of layer 0).
        let boundary01 = h / 2
        let halfBand = h * 0.05

        // Case 1: dragY is exactly on the boundary -> Must highlight boundary 1
        vm.updateDropTarget(sourceIndex: 0, movingClipKind: .effect, dragY: boundary01)
        #expect(vm.dropBetweenIndex == 1)
        #expect(vm.hoverLayerID == nil)

        // Case 2: dragY is within the 10% middle band (boundary01 - 0.04 * h) -> Must highlight boundary 1
        vm.updateDropTarget(sourceIndex: 0, movingClipKind: .effect, dragY: boundary01 - halfBand * 0.8)
        #expect(vm.dropBetweenIndex == 1)
        #expect(vm.hoverLayerID == nil)

        // Case 3: dragY is within the 10% middle band (boundary01 + 0.04 * h) -> Must highlight boundary 1
        vm.updateDropTarget(sourceIndex: 0, movingClipKind: .effect, dragY: boundary01 + halfBand * 0.8)
        #expect(vm.dropBetweenIndex == 1)
        #expect(vm.hoverLayerID == nil)

        // Case 4: dragY is outside the 10% band and center is well inside layer 1 (>50% area)
        // -> No boundary highlight (dropBetweenIndex == nil), target is bottomLayer (layer 1)
        let centerInLayer1 = boundary01 + h / 2
        vm.updateDropTarget(sourceIndex: 0, movingClipKind: .effect, dragY: centerInLayer1)
        #expect(vm.dropBetweenIndex == nil)
        #expect(vm.hoverLayerID == bottomLayer.id)

        // Case 5: dragY is outside the 10% band and center remains inside layer 0
        // -> No boundary highlight (dropBetweenIndex == nil), target is topLayer (layer 0)
        let centerInLayer0 = boundary01 - h * 0.3
        vm.updateDropTarget(sourceIndex: 0, movingClipKind: .effect, dragY: centerInLayer0)
        #expect(vm.dropBetweenIndex == nil)
        #expect(vm.hoverLayerID == topLayer.id)
    }

    @Test func testMoveClipAcrossLayersCleansUpEmptySourceLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let layer1 = vm.createLayer(for: .effect)
        let layer2 = vm.createLayer(for: .effect)

        let clip1 = TimelineClip(
            name: "Effect 1",
            kind: .effect,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
        )
        let clip2 = TimelineClip(
            name: "Effect 2",
            kind: .effect,
            timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 3, preferredTimescale: 600))
        )

        vm.addClip(clip1, to: layer1.id)
        vm.addClip(clip2, to: layer2.id)
        #expect(vm.layers.count == 2)

        // Move clip1 from layer1 into layer2 (non-colliding at 8s)
        vm.moveClip(
            clipID: clip1.id,
            from: layer1.id,
            to: layer2.id,
            insertAtIndex: nil,
            newStartTime: CMTime(seconds: 8, preferredTimescale: 600)
        )

        // layer1 is now empty and MUST be removed automatically
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].id == layer2.id)
        #expect(vm.layers[0].clips.count == 2)

        // Undo move: layer1 must be restored
        #expect(vm.canUndo == true)
        vm.undo()
        #expect(vm.layers.count == 2)
        #expect(vm.layers.first(where: { $0.id == layer1.id })?.clips.count == 1)
        #expect(vm.layers.first(where: { $0.id == layer2.id })?.clips.count == 1)
    }

    @Test func testMoveClipInsertBetweenLayersCleansUpEmptySourceLayer() {
        let vm = TimelineViewModel(initialLayers: [])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor

        let layer1 = vm.createLayer(for: .effect)
        let layer2 = vm.createLayer(for: .effect)

        let clip1 = TimelineClip(
            name: "Effect 1",
            kind: .effect,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
        )
        let clip2 = TimelineClip(
            name: "Effect 2",
            kind: .effect,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
        )

        vm.addClip(clip1, to: layer1.id)
        vm.addClip(clip2, to: layer2.id)
        #expect(vm.layers.count == 2)

        // Insert clip1 between layers (insertAtIndex: 1)
        vm.moveClip(
            clipID: clip1.id,
            from: layer1.id,
            to: nil,
            insertAtIndex: 1,
            newStartTime: CMTime(seconds: 0, preferredTimescale: 600)
        )

        // All remaining layers must have clips (no empty layers)
        for layer in vm.layers {
            #expect(!layer.clips.isEmpty)
        }
    }
}

