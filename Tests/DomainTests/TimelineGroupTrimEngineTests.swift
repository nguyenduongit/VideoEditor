import Foundation
import CoreMedia
import Testing
@testable import Domain

@Suite("Timeline Group Trim Engine Tests")
struct TimelineGroupTrimEngineTests {
    @Test("Left trim giới hạn chuẩn khi không có chướng ngại vật")
    func testLeftTrimLimitsWithoutObstacles() {
        // Clip 1: [5s, 10s] (dur = 5s), procedural (không giới hạn source)
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let clip1 = TimelineClip(name: "V1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600)), properties: p1)

        // Clip 2: [2s, 8s] (dur = 6s), procedural
        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let clip2 = TimelineClip(name: "A1", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 6, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [clip2])

        let limits = TimelineGroupTrimEngine.calculateLeftLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [clip1.id, clip2.id]
        )

        // Mở rộng về trái (delta < 0): Clip 2 bắt đầu ở 2s -> mở rộng tối đa 2s (delta min = -2s)
        #expect(abs(CMTimeGetSeconds(limits.minDelta) - (-2.0)) < 0.001)

        // Thu ngắn vào trong (delta > 0): Clip 1 ngắn hơn (dur = 5s) -> thu ngắn tối đa 5s - 1 frame
        let minDur = TimeRational.time(forFrame: 1)
        let expectedMaxDelta = CMTimeSubtract(CMTime(seconds: 5, preferredTimescale: 600), minDur)
        #expect(abs(CMTimeGetSeconds(limits.maxDelta) - CMTimeGetSeconds(expectedMaxDelta)) < 0.001)
        #expect(limits.canTrim)

        // Test clamp
        let clamped = TimelineGroupTrimEngine.clamp(
            delta: CMTime(seconds: -10, preferredTimescale: 600),
            limits: limits
        )
        #expect(abs(CMTimeGetSeconds(clamped) - (-2.0)) < 0.001)
    }

    @Test("Left trim bị chặn bởi clip đứng trước trên cùng layer")
    func testLeftTrimLimitsBlockedByPreviousClip() {
        // Layer 1: U1 [0, 4s], S1 [6s, 10s] có sourceStartTime = 4s -> S1 mở rộng về trái tối đa tới 4s do gặp U1 (delta min = -2s)
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let u1 = TimelineClip(name: "U1", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4, preferredTimescale: 600)))
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 6, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)), properties: p1)

        // Layer 2: S2 [8s, 14s] -> không có clip trước, có thể mở rộng tới 0s (delta min = -8s)
        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let s2 = TimelineClip(name: "S2", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 8, preferredTimescale: 600), duration: CMTime(seconds: 6, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [u1, s1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [s2])

        let limits = TimelineGroupTrimEngine.calculateLeftLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )

        // Nhóm chỉ có thể mở rộng tối đa -2s vì S1 đụng U1 ở mốc 4s
        #expect(abs(CMTimeGetSeconds(limits.minDelta) - (-2.0)) < 0.001)
    }

    @Test("Right trim giới hạn mở rộng khi bị chặn bởi clip đứng sau trên cùng layer")
    func testRightTrimLimitsBlockedByNextClip() {
        // Layer 1: S1 [2s, 6s] (dur = 4s, end = 6s), U1 [8s, 12s] -> S1 mở rộng tối đa tới 8s (delta max = +2s)
        var p1: [String: PropertyValue] = [:]
        p1["isProcedural"] = .bool(true)
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)), properties: p1)
        let u1 = TimelineClip(name: "U1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 8, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))

        // Layer 2: S2 [2s, 10s] (dur = 8s, end = 10s) -> không có clip sau
        var p2: [String: PropertyValue] = [:]
        p2["isProcedural"] = .bool(true)
        let s2 = TimelineClip(name: "S2", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 8, preferredTimescale: 600)), properties: p2)

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [s1, u1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, clips: [s2])

        let limits = TimelineGroupTrimEngine.calculateRightLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )

        // Nhóm chỉ có thể mở rộng tối đa +2s vì S1 đụng U1 ở mốc 8s
        #expect(abs(CMTimeGetSeconds(limits.maxDelta) - 2.0) < 0.001)

        // Thu ngắn tối đa (delta < 0): S1 ngắn hơn (dur = 4s) -> delta min = -(4s - 1 frame)
        let minDur = TimeRational.time(forFrame: 1)
        let expectedMinDelta = CMTimeSubtract(minDur, CMTime(seconds: 4, preferredTimescale: 600))
        #expect(abs(CMTimeGetSeconds(limits.minDelta) - CMTimeGetSeconds(expectedMinDelta)) < 0.001)
    }

    @Test("Layer bị khoá chặn toàn bộ hoạt động group trim")
    func testLockedLayerBlocksGroupTrim() {
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))
        let s2 = TimelineClip(name: "S2", kind: .audio, timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)))

        let layer1 = TimelineLayer(id: UUID(), name: "Video", kind: .video, isLocked: true, clips: [s1])
        let layer2 = TimelineLayer(id: UUID(), name: "Audio", kind: .audio, isLocked: false, clips: [s2])

        let leftLimits = TimelineGroupTrimEngine.calculateLeftLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )
        #expect(!leftLimits.canTrim)
        #expect(leftLimits.minDelta == .zero && leftLimits.maxDelta == .zero)

        let rightLimits = TimelineGroupTrimEngine.calculateRightLimits(
            layers: [layer1, layer2],
            selectedClipIDs: [s1.id, s2.id]
        )
        #expect(!rightLimits.canTrim)
        #expect(rightLimits.minDelta == .zero && rightLimits.maxDelta == .zero)
    }

    @Test("Group trim tuân thủ giới hạn sourceStartTime và maxDuration của file media")
    func testSourceDurationLimits() {
        // Video clip có maxDuration = 10s, hiện đang cắt [2s, 6s] với sourceStartTime = 2s
        let clip = TimelineClip(
            name: "Video Source",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 600), duration: CMTime(seconds: 4, preferredTimescale: 600)),
            maxDuration: CMTime(seconds: 10, preferredTimescale: 600),
            sourceStartTime: CMTime(seconds: 2, preferredTimescale: 600)
        )
        let layer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip])

        // Left trim: sourceStartTime = 2s -> mở rộng về trước tối đa 2s (delta min = -2s)
        let leftLimits = TimelineGroupTrimEngine.calculateLeftLimits(layers: [layer], selectedClipIDs: [clip.id])
        #expect(abs(CMTimeGetSeconds(leftLimits.minDelta) - (-2.0)) < 0.001)

        // Right trim: source hiện tại từ 2s -> 6s (đã dùng 4s). Max = 10s -> còn lại 4s để mở rộng (delta max = +4s)
        let rightLimits = TimelineGroupTrimEngine.calculateRightLimits(layers: [layer], selectedClipIDs: [clip.id])
        #expect(abs(CMTimeGetSeconds(rightLimits.maxDelta) - 4.0) < 0.001)
    }
}
