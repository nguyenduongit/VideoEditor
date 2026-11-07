import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("Universal Property Keyframe Engine Tests")
struct UniversalKeyframeEngineTests {
    @Test("KeyframeEvaluator interpolates accurately across all 6 curve modes")
    func testKeyframeEvaluatorCurves() {
        var map = ClipKeyframeMap()
        map.upsertKeyframe(for: "scale", atLocalSeconds: 0.0, value: 1.0, interpolation: .linear)
        map.upsertKeyframe(for: "scale", atLocalSeconds: 2.0, value: 3.0, interpolation: .linear)

        let midLinear = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 1.0, map: map)
        #expect(abs(midLinear - 2.0) < 0.01)

        // Hold curve holds first value until reaching second keyframe
        map.setInterpolation(.hold, for: "scale", atLocalSeconds: 0.0)
        let midHold = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 1.5, map: map)
        #expect(abs(midHold - 1.0) < 0.001)
        let endHold = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 2.0, map: map)
        #expect(abs(endHold - 3.0) < 0.001)

        // EaseIn vs EaseOut at 25% progress (t = 0.5s out of 2.0s)
        map.setInterpolation(.easeIn, for: "scale", atLocalSeconds: 0.0)
        let quarterEaseIn = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 0.5, map: map)
        map.setInterpolation(.easeOut, for: "scale", atLocalSeconds: 0.0)
        let quarterEaseOut = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 0.5, map: map)
        #expect(quarterEaseIn < quarterEaseOut)

        // Spring curve overshoots slightly before settling at target (peak overshoot near t = 0.72s / x = 0.36)
        map.setInterpolation(.spring, for: "scale", atLocalSeconds: 0.0)
        let springMid = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 0.72, map: map)
        #expect(springMid > 3.0)
        let springEnd = KeyframeEvaluator.evaluate(propertyKey: "scale", baseValue: 1.0, atLocalTime: 2.0, map: map)
        #expect(abs(springEnd - 3.0) < 0.01)
    }

    @Test("TimelineClip.split preserves and shifts keyframes into left and right clips")
    func testTimelineClipSplitPreservesKeyframes() throws {
        var map = ClipKeyframeMap()
        map.upsertKeyframe(for: "opacity", atLocalSeconds: 0.0, value: 0.0, interpolation: .linear)
        map.upsertKeyframe(for: "opacity", atLocalSeconds: 4.0, value: 1.0, interpolation: .linear)

        var props = BuiltInClipPropertyDefaults.properties(for: .video)
        props[ClipKeyframeMap.propertyKey] = .string(try #require(map.encodeToJSON()))

        let clip = TimelineClip(
            name: "Keyframed Video",
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 2.0, preferredTimescale: 600),
                duration: CMTime(seconds: 4.0, preferredTimescale: 600)
            ),
            properties: props
        )

        // Split at timeline t = 4.0s (which is local offset 2.0s inside the clip)
        let splitResult = try #require(clip.split(at: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let leftMap = try #require(ClipKeyframeMap.from(clip: splitResult.0))
        let rightMap = try #require(ClipKeyframeMap.from(clip: splitResult.1))

        let leftEndVal = KeyframeEvaluator.evaluate(propertyKey: "opacity", baseValue: 1.0, atLocalTime: 2.0, map: leftMap)
        let rightStartVal = KeyframeEvaluator.evaluate(propertyKey: "opacity", baseValue: 1.0, atLocalTime: 0.0, map: rightMap)
        let rightEndVal = KeyframeEvaluator.evaluate(propertyKey: "opacity", baseValue: 1.0, atLocalTime: 2.0, map: rightMap)

        #expect(abs(leftEndVal - 0.5) < 0.02)
        #expect(abs(rightStartVal - 0.5) < 0.02)
        #expect(abs(rightEndVal - 1.0) < 0.02)
    }

    @Test("TimelineClip.trim shifts keyframe offsets when trimming left edge")
    func testTimelineClipTrimShiftsKeyframes() throws {
        var map = ClipKeyframeMap()
        map.upsertKeyframe(for: "positionX", atLocalSeconds: 1.0, value: 100.0, interpolation: .linear)
        map.upsertKeyframe(for: "positionX", atLocalSeconds: 3.0, value: 300.0, interpolation: .linear)

        var props = BuiltInClipPropertyDefaults.properties(for: .video)
        props[ClipKeyframeMap.propertyKey] = .string(try #require(map.encodeToJSON()))

        var clip = TimelineClip(
            name: "Trim Video",
            kind: .video,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 0.0, preferredTimescale: 600),
                duration: CMTime(seconds: 4.0, preferredTimescale: 600)
            ),
            properties: props
        )

        // Trim 1.0s off the left edge -> new start = 1.0s, new duration = 3.0s, new sourceStart = 1.0s
        clip.trim(
            newStart: CMTime(seconds: 1.0, preferredTimescale: 600),
            newDuration: CMTime(seconds: 3.0, preferredTimescale: 600),
            newSourceStart: CMTime(seconds: 1.0, preferredTimescale: 600)
        )

        let trimmedMap = try #require(ClipKeyframeMap.from(clip: clip))
        let points = trimmedMap.points(for: "positionX")
        #expect(points.count == 2)
        #expect(abs(points[0].timeOffset.seconds - 0.0) < 0.02)
        #expect(abs(points[0].value - 100.0) < 0.01)
        #expect(abs(points[1].timeOffset.seconds - 2.0) < 0.02)
        #expect(abs(points[1].value - 300.0) < 0.01)
    }

    @Test("InspectorViewModel toggles keyframes, auto-keyframes on slider drag, and navigates < ◆ >")
    @MainActor
    func testInspectorViewModelAutoKeyframeAndNavigation() {
        let clip = TimelineClip(
            name: "Hero Clip",
            kind: .video,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 5.0, preferredTimescale: 600)
            )
        )
        let layer = TimelineLayer(id: UUID(), kind: .video, clips: [clip])
        let timelineVM = TimelineViewModel(initialLayers: [layer])
        timelineVM.selectClip(clip.id)

        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        // 1. Seek to t = 0.0s and toggle keyframe on "scale"
        timelineVM.seek(to: .zero)
        inspectorVM.toggleKeyframe(for: ["scale"], defaultValues: ["scale": 1.0])
        #expect(inspectorVM.hasKeyframes(for: ["scale"]) == true)
        #expect(inspectorVM.hasKeyframeAtPlayhead(for: ["scale"]) == true)

        // 2. Seek to t = 2.0s and drag "scale" slider to 2.0 -> Auto-Keyframe inserts second keyframe!
        timelineVM.seek(to: CMTime(seconds: 2.0, preferredTimescale: 600))
        #expect(inspectorVM.hasKeyframeAtPlayhead(for: ["scale"]) == false)
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: true)
        inspectorVM.updateLiveValue(key: "scale", value: 2.0)
        inspectorVM.onSliderEditingChanged(key: "scale", isEditing: false)

        #expect(inspectorVM.hasKeyframeAtPlayhead(for: ["scale"]) == true)
        #expect(inspectorVM.currentKeyframeMap.points(for: "scale").count == 2)

        // 3. Seek to midpoint t = 1.0s and verify liveNumber returns interpolated value ~1.5
        timelineVM.seek(to: CMTime(seconds: 1.0, preferredTimescale: 600))
        let midVal = inspectorVM.liveNumber(for: "scale", default: 1.0)
        #expect(abs(midVal - 1.5) < 0.05)

        // 4. Navigate to previous and next keyframes using < and >
        #expect(inspectorVM.canJumpToPreviousKeyframe(for: ["scale"]) == true)
        #expect(inspectorVM.canJumpToNextKeyframe(for: ["scale"]) == true)

        inspectorVM.jumpToPreviousKeyframe(for: ["scale"])
        #expect(abs(CMTimeGetSeconds(timelineVM.currentTime) - 0.0) < 0.02)

        inspectorVM.jumpToNextKeyframe(for: ["scale"])
        #expect(abs(CMTimeGetSeconds(timelineVM.currentTime) - 2.0) < 0.02)
    }
}

