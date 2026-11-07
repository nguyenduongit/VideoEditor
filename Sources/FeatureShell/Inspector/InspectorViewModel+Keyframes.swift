import Foundation
import CoreMedia
import Domain
import DesignSystem

/// Extension trên InspectorViewModel cung cấp hệ thống điều khiển Universal Keyframe
/// (Add/Delete/Jump `< ◆ >`, chọn đường cong nội suy, và Auto-Keyframe khi kéo thanh trượt).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Function <= 50 dòng) của AGENTS.md.
extension InspectorViewModel {
    /// Các thuộc tính không áp dụng keyframe động (vì làm thay đổi cấu trúc độ dài clip trên Timeline).
    private static let nonKeyframeableKeys: Set<String> = [
        "speed", "duration", "pitchPreservation", "uniformScale", "isBeatCounter"
    ]

    public func isPropertyKeyframeable(_ key: String) -> Bool {
        !Self.nonKeyframeableKeys.contains(key)
    }

    public var currentClipLocalTime: Double {
        guard let clip = selectedClip, let timelineViewModel else { return 0.0 }
        let cur = timelineViewModel.currentTime
        let start = clip.timeRange.start
        let dur = max(0.0, CMTimeGetSeconds(clip.timeRange.duration))
        let offset = CMTimeGetSeconds(CMTimeSubtract(cur, start))
        return max(0.0, min(dur, offset))
    }

    public var currentKeyframeMap: ClipKeyframeMap {
        if let raw = liveProperties[ClipKeyframeMap.propertyKey]?.asString,
           let map = ClipKeyframeMap.decode(from: raw) {
            return map
        }
        if let clip = selectedClip, let map = ClipKeyframeMap.from(clip: clip) {
            return map
        }
        return ClipKeyframeMap()
    }

    public var keyframeCurveOptions: [DSKeyframeCurveOption] {
        KeyframeInterpolation.allCases.map {
            DSKeyframeCurveOption(id: $0.rawValue, title: $0.displayName, iconName: $0.iconName)
        }
    }

    public func hasKeyframes(for keys: [String]) -> Bool {
        let map = currentKeyframeMap
        return keys.contains { map.hasKeyframes(for: $0) }
    }

    public func hasKeyframeAtPlayhead(for keys: [String]) -> Bool {
        let validKeys = keys.filter { isPropertyKeyframeable($0) }
        guard !validKeys.isEmpty else { return false }
        let map = currentKeyframeMap
        let localSec = currentClipLocalTime
        return validKeys.allSatisfy { map.keyframe(for: $0, atLocalSeconds: localSec) != nil }
    }

    public func canJumpToPreviousKeyframe(for keys: [String]) -> Bool {
        let offsets = currentKeyframeMap.allKeyframeTimeOffsets(for: keys)
        let localSec = currentClipLocalTime
        return offsets.contains { $0 < localSec - ClipKeyframeMap.defaultFrameTolerance }
    }

    public func canJumpToNextKeyframe(for keys: [String]) -> Bool {
        let offsets = currentKeyframeMap.allKeyframeTimeOffsets(for: keys)
        let localSec = currentClipLocalTime
        return offsets.contains { $0 > localSec + ClipKeyframeMap.defaultFrameTolerance }
    }

    public func activeInterpolation(for keys: [String]) -> KeyframeInterpolation {
        let map = currentKeyframeMap
        let localSec = currentClipLocalTime
        for key in keys {
            if let pt = map.keyframe(for: key, atLocalSeconds: localSec) {
                return pt.interpolation
            }
            if let first = map.points(for: key).first {
                return first.interpolation
            }
        }
        return .smooth
    }

    /// Bật/tắt mốc Keyframe tại vị trí Playhead cho danh sách `keys` (có thể là 1 thuộc tính hoặc cả nhóm Transform/Mask).
    public func toggleKeyframe(for keys: [String], defaultValues: [String: Double] = [:]) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        ensurePlayheadAtOrWithinClip(clip: clip)
        let localSec = currentClipLocalTime
        var map = currentKeyframeMap
        let allAtPlayhead = keys.allSatisfy { map.keyframe(for: $0, atLocalSeconds: localSec) != nil }

        if allAtPlayhead {
            for key in keys {
                map.removeKeyframe(for: key, atLocalSeconds: localSec)
            }
        } else {
            for key in keys where isPropertyKeyframeable(key) {
                let fallback = defaultValues[key] ?? defaultNumberForKey(key, in: clip)
                let val = liveNumber(for: key, default: fallback)
                map.upsertKeyframe(for: key, atLocalSeconds: localSec, value: val)
            }
        }

        commitKeyframeMap(map, for: clip, timelineViewModel: timelineViewModel)
    }

    public func clearAllKeyframes(for keys: [String]) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        var map = currentKeyframeMap
        for key in keys {
            map.removeAllKeyframes(for: key)
        }
        commitKeyframeMap(map, for: clip, timelineViewModel: timelineViewModel)
    }

    public func setInterpolation(_ interpolation: KeyframeInterpolation, for keys: [String]) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        var map = currentKeyframeMap
        let localSec = currentClipLocalTime
        for key in keys where map.hasKeyframes(for: key) {
            if map.keyframe(for: key, atLocalSeconds: localSec) != nil {
                map.setInterpolation(interpolation, for: key, atLocalSeconds: localSec)
            } else {
                map.setInterpolation(interpolation, for: key, atLocalSeconds: nil)
            }
        }
        commitKeyframeMap(map, for: clip, timelineViewModel: timelineViewModel)
    }

    public func jumpToPreviousKeyframe(for keys: [String]) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        let offsets = currentKeyframeMap.allKeyframeTimeOffsets(for: keys)
        let localSec = currentClipLocalTime
        guard let targetLocal = offsets.last(where: { $0 < localSec - ClipKeyframeMap.defaultFrameTolerance }) else {
            return
        }
        let targetTimeline = CMTimeAdd(
            clip.timeRange.start,
            CMTime(seconds: targetLocal, preferredTimescale: 600)
        )
        timelineViewModel.seek(to: targetTimeline)
    }

    public func jumpToNextKeyframe(for keys: [String]) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        let offsets = currentKeyframeMap.allKeyframeTimeOffsets(for: keys)
        let localSec = currentClipLocalTime
        guard let targetLocal = offsets.first(where: { $0 > localSec + ClipKeyframeMap.defaultFrameTolerance }) else {
            return
        }
        let targetTimeline = CMTimeAdd(
            clip.timeRange.start,
            CMTime(seconds: targetLocal, preferredTimescale: 600)
        )
        timelineViewModel.seek(to: targetTimeline)
    }

    /// Tự động cập nhật hoặc chèn Keyframe mới tại vị trí Playhead nếu thuộc tính đang bật chế độ Keyframe (Auto-Keyframe).
    func applyAutoKeyframeIfNeeded(key: String, value: Double) {
        guard isPropertyKeyframeable(key) else { return }
        var map = currentKeyframeMap
        guard map.hasKeyframes(for: key) else { return }
        let localSec = currentClipLocalTime
        map.upsertKeyframe(for: key, atLocalSeconds: localSec, value: value)
        if let json = map.encodeToJSON() {
            liveProperties[ClipKeyframeMap.propertyKey] = .string(json)
        } else {
            liveProperties.removeValue(forKey: ClipKeyframeMap.propertyKey)
        }
    }

    public func keyframeKeys(for desc: PropertyDescriptor) -> [String] {
        switch desc.control {
        case .slider, .rotation, .numberField:
            return isPropertyKeyframeable(desc.id) ? [desc.id] : []
        case .position2D(let xID, let yID, _):
            return [xID, yID]
        default:
            return []
        }
    }

    public func keyframeKeys(forGroup descriptors: [PropertyDescriptor]) -> [String] {
        descriptors.flatMap { keyframeKeys(for: $0) }
    }

    private func defaultNumberForKey(_ key: String, in clip: TimelineClip) -> Double {
        if let desc = propertyRegistry.descriptors(for: clip.kind).first(where: { $0.id == key }),
           let num = desc.defaultValue.asNumber {
            return num
        }
        return clip.properties[key]?.asNumber ?? 0.0
    }

    private func ensurePlayheadAtOrWithinClip(clip: TimelineClip) {
        guard let timelineViewModel else { return }
        let cur = timelineViewModel.currentTime
        if cur < clip.timeRange.start || cur > clip.timeRange.end {
            timelineViewModel.seek(to: clip.timeRange.start)
        }
    }

    private func commitKeyframeMap(
        _ map: ClipKeyframeMap,
        for clip: TimelineClip,
        timelineViewModel: TimelineViewModel
    ) {
        if let json = map.encodeToJSON() {
            liveProperties[ClipKeyframeMap.propertyKey] = .string(json)
        } else {
            liveProperties.removeValue(forKey: ClipKeyframeMap.propertyKey)
        }
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }
}

