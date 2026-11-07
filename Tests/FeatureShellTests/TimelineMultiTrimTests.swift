import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("Timeline Multi Trim Tests")
struct TimelineMultiTrimTests {

    @Test("updateGroupTrim cập nhật groupTrimLeftOffset và groupTrimRightOffset đồng thời theo pixelsPerSecond")
    @MainActor
    func testUpdateGroupTrimOffsets() {
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 6, preferredTimescale: 600)), properties: p1)

        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 8, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let vm = TimelineViewModel(initialLayers: [layer1, layer2])
        vm.pixelsPerSecond = 100.0
        vm.selectedClipIDs = [clip1.id, clip2.id]

        // Kéo trim trái vào trong 1.0s (dx = 100px)
        vm.updateGroupTrim(isLeft: true, dx: 100.0)
        #expect(abs(vm.groupTrimLeftOffset - 100.0) < 1.0)
        #expect(vm.groupTrimRightOffset == 0)

        // Reset
        vm.resetGroupTrim()
        #expect(vm.groupTrimLeftOffset == 0)

        // Kéo trim phải ra ngoài 2.0s (dx = 200px)
        vm.updateGroupTrim(isLeft: false, dx: 200.0)
        #expect(abs(vm.groupTrimRightOffset - 200.0) < 1.0)
        #expect(vm.groupTrimLeftOffset == 0)
    }

    @Test("commitGroupTrim Left đồng loạt thay đổi start và duration của tất cả clip được chọn")
    @MainActor
    func testCommitGroupTrimLeft() {
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)), properties: p1)

        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 3, preferredTimescale: 600), duration: CMTime(seconds: 7, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let vm = TimelineViewModel(initialLayers: [layer1, layer2])
        vm.selectedClipIDs = [clip1.id, clip2.id]

        // Trim trái vào trong 2s (delta = +2s)
        let delta = CMTime(seconds: 2.0, preferredTimescale: 600)
        vm.commitGroupTrim(isLeft: true, delta: delta)

        // Clip 1 mới: start = 5 + 2 = 7s, duration = 5 - 2 = 3s
        let updatedClip1 = vm.layers[0].clips.first(where: { $0.id == clip1.id })!
        #expect(abs(CMTimeGetSeconds(updatedClip1.timeRange.start) - 7.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(updatedClip1.timeRange.duration) - 3.0) < 0.05)

        // Clip 2 mới: start = 3 + 2 = 5s, duration = 7 - 2 = 5s
        let updatedClip2 = vm.layers[1].clips.first(where: { $0.id == clip2.id })!
        #expect(abs(CMTimeGetSeconds(updatedClip2.timeRange.start) - 5.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(updatedClip2.timeRange.duration) - 5.0) < 0.05)

        // Sau commit, offsets phải được reset về 0
        #expect(vm.groupTrimLeftOffset == 0)
        #expect(vm.groupTrimRightOffset == 0)
    }

    @Test("commitGroupTrim Right đồng loạt thay đổi duration của tất cả clip được chọn")
    @MainActor
    func testCommitGroupTrimRight() {
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)), properties: p1)

        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 6, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let vm = TimelineViewModel(initialLayers: [layer1, layer2])
        vm.selectedClipIDs = [clip1.id, clip2.id]

        // Trim phải mở rộng thêm 3s (delta = +3s)
        let delta = CMTime(seconds: 3.0, preferredTimescale: 600)
        vm.commitGroupTrim(isLeft: false, delta: delta)

        // Clip 1 mới: start giữ nguyên 2s, duration = 4 + 3 = 7s
        let updatedClip1 = vm.layers[0].clips.first(where: { $0.id == clip1.id })!
        #expect(abs(CMTimeGetSeconds(updatedClip1.timeRange.start) - 2.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(updatedClip1.timeRange.duration) - 7.0) < 0.05)

        // Clip 2 mới: start giữ nguyên 2s, duration = 6 + 3 = 9s
        let updatedClip2 = vm.layers[1].clips.first(where: { $0.id == clip2.id })!
        #expect(abs(CMTimeGetSeconds(updatedClip2.timeRange.start) - 2.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(updatedClip2.timeRange.duration) - 9.0) < 0.05)
    }

    @Test("commitGroupTrim với CommandExecutor hỗ trợ Undo và Redo trọn vẹn trong 1 bước")
    @MainActor
    func testCommitGroupTrimUndoRedo() {
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)), properties: p1)

        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 4, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let vm = TimelineViewModel(initialLayers: [layer1, layer2])
        let executor = TimelineCommandExecutor(viewModel: vm)
        vm.commandExecutor = executor
        vm.selectedClipIDs = [clip1.id, clip2.id]

        // Trim phải co lại 2s (delta = -2s)
        let delta = CMTime(seconds: -2.0, preferredTimescale: 600)
        vm.commitGroupTrim(isLeft: false, delta: delta)

        // Cả 2 clip duration còn 3s
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.duration) - 3.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.duration) - 3.0) < 0.05)

        // 1 lần Undo phải phục hồi cả 2 clip về duration 5s
        #expect(executor.canUndo)
        executor.undo()
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.duration) - 5.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.duration) - 5.0) < 0.05)

        // 1 lần Redo phải đưa cả 2 clip về duration 3s
        #expect(executor.canRedo)
        executor.redo()
        #expect(abs(CMTimeGetSeconds(vm.layers[0].clips[0].timeRange.duration) - 3.0) < 0.05)
        #expect(abs(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.duration) - 3.0) < 0.05)
    }
}

