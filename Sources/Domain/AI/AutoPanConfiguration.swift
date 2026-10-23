import Foundation

/// Represents a single tracked subject position at a specific timestamp.
public struct AutoPanKeyframe: Codable, Sendable, Equatable {
    public var timeSeconds: Double
    public var normalizedX: Double // 0.0 (left) to 1.0 (right)
    public var confidence: Float

    public init(timeSeconds: Double, normalizedX: Double, confidence: Float = 1.0) {
        self.timeSeconds = timeSeconds
        self.normalizedX = max(0.0, min(1.0, normalizedX))
        self.confidence = confidence
    }
}

/// Configuration settings and tracked keyframes for the Auto Pan feature.
/// Complies with R2.3, R4.3, and R5.5 of AGENTS.md.
public struct AutoPanConfiguration: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    public var smoothness: Double // 0.0 (fast) to 1.0 (ultra-smooth), default 0.5
    public var keyframes: [AutoPanKeyframe]

    public init(
        isEnabled: Bool = false,
        smoothness: Double = 0.5,
        keyframes: [AutoPanKeyframe] = []
    ) {
        self.isEnabled = isEnabled
        self.smoothness = max(0.0, min(1.0, smoothness))
        self.keyframes = keyframes
    }

    public static let `default` = AutoPanConfiguration(isEnabled: false, smoothness: 0.5, keyframes: [])

    public func encodeToString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> AutoPanConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AutoPanConfiguration.self, from: data)
    }
}
