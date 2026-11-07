import Foundation
import CoreMedia

/// Chế độ nội suy (interpolation curve) giữa điểm keyframe hiện tại và điểm keyframe kế tiếp.
/// Tuân thủ quy tắc R3.1 và R4.1 của AGENTS.md.
public enum KeyframeInterpolation: String, Codable, Sendable, CaseIterable, Hashable {
    case linear = "linear"
    case smooth = "smooth"
    case easeIn = "easeIn"
    case easeOut = "easeOut"
    case spring = "spring"
    case hold = "hold"

    public var displayName: String {
        switch self {
        case .linear: return "Tuyến tính (Linear)"
        case .smooth: return "Mượt (Smooth Ease)"
        case .easeIn: return "Tăng tốc (Ease In)"
        case .easeOut: return "Giảm tốc (Ease Out)"
        case .spring: return "Đàn hồi (Spring)"
        case .hold: return "Giữ bậc thang (Hold)"
        }
    }

    public var iconName: String {
        switch self {
        case .linear: return "line.diagonal"
        case .smooth: return "point.topleft.down.curvedto.point.bottomright.up"
        case .easeIn: return "arrow.up.right"
        case .easeOut: return "arrow.down.right"
        case .spring: return "waveform.path.ecg"
        case .hold: return "stairs"
        }
    }
}

/// Một mốc Keyframe đơn lẻ trên đường thời gian nội bộ của Clip (`0.0s ... clip.duration`).
public struct KeyframePoint: Identifiable, Codable, Sendable, Hashable, Equatable {
    public var id: UUID
    public var timeOffset: RationalTime
    public var value: Double
    public var interpolation: KeyframeInterpolation

    public init(
        id: UUID = UUID(),
        timeOffset: RationalTime,
        value: Double,
        interpolation: KeyframeInterpolation = .smooth
    ) {
        self.id = id
        self.timeOffset = timeOffset
        self.value = value
        self.interpolation = interpolation
    }

    public init(
        id: UUID = UUID(),
        seconds: Double,
        value: Double,
        interpolation: KeyframeInterpolation = .smooth
    ) {
        let clampedSec = max(0.0, seconds)
        let snapped = TimeRational.snapToFrame(time: CMTime(seconds: clampedSec, preferredTimescale: 600))
        self.id = id
        self.timeOffset = RationalTime(cmTime: snapped)
        self.value = value
        self.interpolation = interpolation
    }
}

/// Bản đồ lưu trữ toàn bộ các đường Keyframe của một Clip theo `propertyKey`.
/// Được mã hóa JSON vào `clip.properties["keyframeMap"]` để tương thích tự động 100% với Undo/Redo.
public struct ClipKeyframeMap: Codable, Sendable, Hashable, Equatable {
    public static let propertyKey = "keyframeMap"
    public static let defaultFrameTolerance: Double = 0.025 // ~1.5 frames at 60fps

    public var tracks: [String: [KeyframePoint]]

    public init(tracks: [String: [KeyframePoint]] = [:]) {
        var normalized: [String: [KeyframePoint]] = [:]
        for (key, pts) in tracks where !pts.isEmpty {
            normalized[key] = pts.sorted { $0.timeOffset < $1.timeOffset }
        }
        self.tracks = normalized
    }

    public var isEmpty: Bool {
        tracks.values.allSatisfy { $0.isEmpty }
    }

    public func points(for propertyKey: String) -> [KeyframePoint] {
        tracks[propertyKey] ?? []
    }

    public func hasKeyframes(for propertyKey: String) -> Bool {
        !(tracks[propertyKey]?.isEmpty ?? true)
    }

    public func keyframe(
        for propertyKey: String,
        atLocalSeconds seconds: Double,
        tolerance: Double = ClipKeyframeMap.defaultFrameTolerance
    ) -> KeyframePoint? {
        guard let list = tracks[propertyKey], !list.isEmpty else { return nil }
        return list.min(by: { abs($0.timeOffset.seconds - seconds) < abs($1.timeOffset.seconds - seconds) })
            .flatMap { abs($0.timeOffset.seconds - seconds) <= tolerance ? $0 : nil }
    }

    public mutating func upsertKeyframe(
        for propertyKey: String,
        atLocalSeconds seconds: Double,
        value: Double,
        interpolation: KeyframeInterpolation? = nil,
        tolerance: Double = ClipKeyframeMap.defaultFrameTolerance
    ) {
        var list = tracks[propertyKey] ?? []
        if let idx = list.firstIndex(where: { abs($0.timeOffset.seconds - seconds) <= tolerance }) {
            list[idx].value = value
            if let interpolation {
                list[idx].interpolation = interpolation
            }
        } else {
            let inheritedCurve = interpolation ?? list.last?.interpolation ?? .smooth
            let point = KeyframePoint(seconds: seconds, value: value, interpolation: inheritedCurve)
            list.append(point)
            list.sort { $0.timeOffset < $1.timeOffset }
        }
        tracks[propertyKey] = list
    }

    public mutating func removeKeyframe(
        for propertyKey: String,
        atLocalSeconds seconds: Double,
        tolerance: Double = ClipKeyframeMap.defaultFrameTolerance
    ) {
        guard var list = tracks[propertyKey] else { return }
        list.removeAll { abs($0.timeOffset.seconds - seconds) <= tolerance }
        if list.isEmpty {
            tracks.removeValue(forKey: propertyKey)
        } else {
            tracks[propertyKey] = list
        }
    }

    public mutating func removeAllKeyframes(for propertyKey: String) {
        tracks.removeValue(forKey: propertyKey)
    }

    public mutating func setInterpolation(
        _ interpolation: KeyframeInterpolation,
        for propertyKey: String,
        atLocalSeconds seconds: Double? = nil,
        tolerance: Double = ClipKeyframeMap.defaultFrameTolerance
    ) {
        guard var list = tracks[propertyKey], !list.isEmpty else { return }
        if let seconds, let idx = list.firstIndex(where: { abs($0.timeOffset.seconds - seconds) <= tolerance }) {
            list[idx].interpolation = interpolation
        } else {
            for i in list.indices {
                list[i].interpolation = interpolation
            }
        }
        tracks[propertyKey] = list
    }

    /// Trả về danh sách tất cả các mốc thời gian (giây) có ít nhất một keyframe trên bất kỳ thuộc tính nào.
    public func allKeyframeTimeOffsets(for keys: [String]? = nil, tolerance: Double = 0.01) -> [Double] {
        let relevantLists: [[KeyframePoint]]
        if let keys {
            relevantLists = keys.compactMap { tracks[$0] }
        } else {
            relevantLists = Array(tracks.values)
        }
        let allSeconds = relevantLists.flatMap { $0.map(\.timeOffset.seconds) }.sorted()
        var unique: [Double] = []
        for sec in allSeconds {
            if let last = unique.last, abs(sec - last) <= tolerance {
                continue
            }
            unique.append(sec)
        }
        return unique
    }

    public func encodeToJSON() -> String? {
        guard !isEmpty,
              let data = try? JSONEncoder().encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    public static func decode(from json: String) -> ClipKeyframeMap? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ClipKeyframeMap.self, from: data)
    }

    public static func from(properties: [String: PropertyValue]) -> ClipKeyframeMap? {
        guard let raw = properties[propertyKey]?.asString else { return nil }
        return decode(from: raw)
    }

    public static func from(clip: TimelineClip) -> ClipKeyframeMap? {
        from(properties: clip.properties)
    }
}

