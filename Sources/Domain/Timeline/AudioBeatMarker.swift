import Foundation
import CoreMedia

/// Phân loại cấp độ nhịp âm thanh.
public enum AudioBeatKind: String, Codable, Sendable, Hashable, CaseIterable {
    /// Nhịp chính (Downbeat / Kick drum mạnh)
    case major
    /// Nhịp phụ (Sub-beat / Snare / Transient chi tiết)
    case minor
}

/// Chế độ tự động nhận diện nhịp.
public enum AudioBeatDetectionMode: String, Codable, Sendable, Hashable, CaseIterable {
    /// Nhịp 1: Chỉ đánh dấu các phách mạnh (thưa, dùng cho cắt cảnh chính)
    case majorOnly
    /// Nhịp 2: Đánh dấu cả phách mạnh và phách phụ (dày, dùng cho chuyển cảnh nhanh)
    case allBeats

    public var displayName: String {
        switch self {
        case .majorOnly:
            return "Nhịp 1 (Phách mạnh)"
        case .allBeats:
            return "Nhịp 2 (Chi tiết)"
        }
    }
}

/// Một điểm đánh dấu nhịp (Beat Marker) neo theo thời gian gốc của file âm thanh (`sourceTime`).
public struct AudioBeatMarker: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var sourceTime: RationalTime
    public var kind: AudioBeatKind
    public var strength: Double

    public init(
        id: UUID = UUID(),
        sourceTime: RationalTime,
        kind: AudioBeatKind = .major,
        strength: Double = 1.0
    ) {
        self.id = id
        self.sourceTime = sourceTime
        self.kind = kind
        self.strength = min(1.0, max(0.0, strength))
    }

    public init(
        id: UUID = UUID(),
        sourceTime: CMTime,
        kind: AudioBeatKind = .major,
        strength: Double = 1.0
    ) {
        let snappedSource = TimeRational.snapToFrame(time: sourceTime)
        self.init(
            id: id,
            sourceTime: RationalTime(cmTime: snappedSource),
            kind: kind,
            strength: strength
        )
    }

    public var sourceSeconds: Double {
        CMTimeGetSeconds(sourceTime.cmTime)
    }
}

/// Cấu hình danh sách điểm beat gắn liền với một `TimelineClip`.
public struct AudioBeatConfiguration: Codable, Sendable, Hashable {
    public static let propertyKey = "beatConfig"

    public var mode: AudioBeatDetectionMode
    public var markers: [AudioBeatMarker]
    public var isVisible: Bool

    public init(
        mode: AudioBeatDetectionMode = .majorOnly,
        markers: [AudioBeatMarker] = [],
        isVisible: Bool = true
    ) {
        self.mode = mode
        self.markers = markers.sorted { $0.sourceSeconds < $1.sourceSeconds }
        self.isVisible = isVisible
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decode(AudioBeatDetectionMode.self, forKey: .mode)
        self.markers = try container.decode([AudioBeatMarker].self, forKey: .markers)
        self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }

    public func encodeToJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> AudioBeatConfiguration? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AudioBeatConfiguration.self, from: data)
    }

    public static func from(clip: TimelineClip) -> AudioBeatConfiguration? {
        guard let json = clip.properties[Self.propertyKey]?.asString, !json.isEmpty else {
            return nil
        }
        return decode(from: json)
    }

    /// Tính toán các mốc thời gian trên Timeline (`CMTime`) cho các beat nằm trong vùng hiển thị của clip.
    public func timelineBeatTimes(for clip: TimelineClip) -> [CMTime] {
        guard !markers.isEmpty else { return [] }
        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let sourceStartSec = max(0.0, CMTimeGetSeconds(clip.sourceStartTime))
        let clipDurSec = max(0.0, CMTimeGetSeconds(clip.timeRange.duration))
        let clipStartSec = max(0.0, CMTimeGetSeconds(clip.timeRange.start))

        var result: [CMTime] = []
        result.reserveCapacity(markers.count)

        for marker in markers {
            let relSec = (marker.sourceSeconds - sourceStartSec) / speed
            if relSec >= 0.001 && relSec <= clipDurSec - 0.001 {
                let timelineSec = clipStartSec + relSec
                let snappedTime = TimeRational.snapToFrame(
                    time: CMTime(seconds: timelineSec, preferredTimescale: 600)
                )
                result.append(snappedTime)
            }
        }
        return result
    }

    /// Thêm mới hoặc xóa một beat marker gần vị trí `sourceTime` (dùng cho phím tắt `M`).
    @discardableResult
    public mutating func toggleMarker(
        atSourceTime sourceTime: CMTime,
        toleranceSeconds: Double = 0.06,
        kind: AudioBeatKind = .major
    ) -> Bool {
        let targetSec = max(0.0, CMTimeGetSeconds(sourceTime))
        if let existingIndex = markers.firstIndex(where: { abs($0.sourceSeconds - targetSec) <= toleranceSeconds }) {
            markers.remove(at: existingIndex)
            return false
        } else {
            let marker = AudioBeatMarker(sourceTime: sourceTime, kind: kind, strength: 1.0)
            markers.append(marker)
            markers.sort { $0.sourceSeconds < $1.sourceSeconds }
            return true
        }
    }
}

