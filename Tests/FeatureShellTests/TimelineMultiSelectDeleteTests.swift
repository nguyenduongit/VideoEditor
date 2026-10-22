import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

struct TimelineMultiSelectDeleteTests {
    @Test @MainActor func testMultiSelectionWithCmd() {
        let vm = TimelineViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let clip1 = TimelineClip(id: id1, name: "C1", kind: .video, timeRange: .zero)
        let clip2 = TimelineClip(id: id2, name: "C2", kind: .video, timeRange: .zero)
        let clip3 = TimelineClip(id: id3, name: "C3", kind: .video, timeRange: .zero)

        let layer = vm.createLayer(for: .video)
        vm.addClip(clip1, to: layer.id)
        vm.addClip(clip2, to: layer.id)
        vm.addClip(clip3, to: layer.id)

        // Single select without Cmd
        vm.selectClip(id1, isCmdPressed: false)
        #expect(vm.selectedClipIDs == [id1])
        #expect(vm.selectedClipID == id1)

        // Select another without Cmd replaces selection
        vm.selectClip(id2, isCmdPressed: false)
        #expect(vm.selectedClipIDs == [id2])

        // Cmd + Click adds to selection
        vm.selectClip(id3, isCmdPressed: true)
        #expect(vm.selectedClipIDs == [id2, id3])

        // Cmd + Click on selected clip deselects it
        vm.selectClip(id2, isCmdPressed: true)
        #expect(vm.selectedClipIDs == [id3])

        // Background click clears selection
        vm.selectClip(nil)
        #expect(vm.selectedClipIDs.isEmpty)
    }

    @Test @MainActor func testDeleteSelectedClipsCleansLayers() {
        let vm = TimelineViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let url1 = URL(fileURLWithPath: "/tmp/v1.mp4")
        let url2 = URL(fileURLWithPath: "/tmp/a1.mp3")

        let asset1 = MediaAsset(id: id1, url: url1, type: .video)
        let asset2 = MediaAsset(id: id2, url: url2, type: .audio)

        vm.addAsset(asset1)
        vm.addAsset(asset2)
        #expect(vm.layers.count == 2)

        let videoClip = vm.layers.first(where: { $0.kind == .video })?.clips.first
        let audioClip = vm.layers.first(where: { $0.kind == .audio })?.clips.first

        guard let vID = videoClip?.id, let aID = audioClip?.id else {
            Issue.record("Clips should exist")
            return
        }

        // Multi-select both clips
        vm.selectClip(vID, isCmdPressed: false)
        vm.selectClip(aID, isCmdPressed: true)
        #expect(vm.selectedClipIDs == [vID, aID])

        var deletedReported: [UUID] = []
        vm.onClipsDeleted = { ids in
            deletedReported = ids
        }

        vm.deleteSelectedClips()

        #expect(vm.layers.isEmpty)
        #expect(vm.selectedClipIDs.isEmpty)
        #expect(Set(deletedReported) == [vID, aID])
    }

    @Test @MainActor func testDeleteSelectedPartialClipsRetainsLayer() {
        let vm = TimelineViewModel()
        let id1 = UUID()
        let id2 = UUID()

        let clip1 = TimelineClip(id: id1, name: "C1", kind: .video, timeRange: .zero)
        let clip2 = TimelineClip(id: id2, name: "C2", kind: .video, timeRange: .zero)

        let layer = vm.createLayer(for: .video)
        vm.addClip(clip1, to: layer.id)
        vm.addClip(clip2, to: layer.id)
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 2)

        // Select only clip1
        vm.selectClip(id1, isCmdPressed: false)
        vm.deleteSelectedClips()

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
        #expect(vm.layers[0].clips[0].id == id2)
        #expect(vm.selectedClipIDs.isEmpty)
    }
}
