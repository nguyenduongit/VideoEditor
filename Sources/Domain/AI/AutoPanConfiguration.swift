import Foundation
import CoreMedia

/// Represents a single tracked subject position and vertical body landmarks at a specific timestamp.
/// Tuân thủ AGENTS.md R2.3 (sử dụng thời gian hữu tỉ RationalTime thay cho Double seconds đơn thuần).
public struct AutoPanKeyframe: Codable, Sendable, Equatable {
    public var time: RationalTime
    public var timeSeconds: Double {
        get { time.seconds }
        set { time = RationalTime(cmTime: CMTime(seconds: max(0.0, newValue), preferredTimescale: 600)) }
    }
    public var normalizedX: Double // 0.0 (left) to 1.0 (right)
    public var confidence: Float
    public var waistY: Double? // 0.0 (top) to 1.0 (bottom)
    public var ankleY: Double? // 0.0 (top) to 1.0 (bottom)

    public init(
        time: RationalTime,
        normalizedX: Double,
        confidence: Float = 1.0,
        waistY: Double? = nil,
        ankleY: Double? = nil
    ) {
        self.time = time
        self.normalizedX = max(0.0, min(1.0, normalizedX))
        self.confidence = confidence
        self.waistY = waistY.map { max(0.05, min(0.90, $0)) }
        self.ankleY = ankleY.map { max(0.10, min(0.98, $0)) }
    }

    public init(
        timeSeconds: Double,
        normalizedX: Double,
        confidence: Float = 1.0,
        waistY: Double? = nil,
        ankleY: Double? = nil
    ) {
        let cm = CMTime(seconds: max(0.0, timeSeconds), preferredTimescale: 600)
        self.init(time: RationalTime(cmTime: cm), normalizedX: normalizedX, confidence: confidence, waistY: waistY, ankleY: ankleY)
    }

    enum CodingKeys: String, CodingKey {
        case time
        case timeSeconds
        case normalizedX
        case confidence
        case waistY
        case ankleY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rational = try container.decodeIfPresent(RationalTime.self, forKey: .time) {
            self.time = rational
        } else {
            let sec = try container.decodeIfPresent(Double.self, forKey: .timeSeconds) ?? 0.0
            self.time = RationalTime(cmTime: CMTime(seconds: max(0.0, sec), preferredTimescale: 600))
        }
        self.normalizedX = max(0.0, min(1.0, try container.decodeIfPresent(Double.self, forKey: .normalizedX) ?? 0.0))
        self.confidence = try container.decodeIfPresent(Float.self, forKey: .confidence) ?? 1.0
        self.waistY = try container.decodeIfPresent(Double.self, forKey: .waistY).map { max(0.05, min(0.90, $0)) }
        self.ankleY = try container.decodeIfPresent(Double.self, forKey: .ankleY).map { max(0.10, min(0.98, $0)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(timeSeconds, forKey: .timeSeconds)
        try container.encode(normalizedX, forKey: .normalizedX)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(waistY, forKey: .waistY)
        try container.encodeIfPresent(ankleY, forKey: .ankleY)
    }
}

/// Configuration settings and tracked keyframes for the Auto Pan feature.
/// Complies with R2.3, R4.3, and R5.5 of AGENTS.md.
public struct AutoPanConfiguration: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var zoom: Double // Backward compatibility, defaults to 1.0 (Aspect Fill handled automatically)
    public var smoothness: Double // 0.0 (fast) to 1.0 (ultra-smooth), default 0.5
    public var keyframes: [AutoPanKeyframe]

    public init(
        isEnabled: Bool = false,
        zoom: Double = 1.0,
        smoothness: Double = 0.5,
        keyframes: [AutoPanKeyframe] = []
    ) {
        self.isEnabled = isEnabled
        self.zoom = max(1.0, min(2.5, zoom))
        self.smoothness = max(0.0, min(1.0, smoothness))
        self.keyframes = keyframes
    }

    public static let `default` = AutoPanConfiguration(isEnabled: false, zoom: 1.0, smoothness: 0.5, keyframes: [])

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case zoom
        case smoothness
        case keyframes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1.0
        self.smoothness = try container.decodeIfPresent(Double.self, forKey: .smoothness) ?? 0.5
        self.keyframes = try container.decodeIfPresent([AutoPanKeyframe].self, forKey: .keyframes) ?? []
    }

    public func encodeToString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> AutoPanConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AutoPanConfiguration.self, from: data)
    }
}
