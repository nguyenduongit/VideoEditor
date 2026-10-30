import Foundation

/// Cấu hình tham số của một clip Hiệu ứng thị giác (Effect Layer).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng).
public struct EffectConfiguration: Codable, Sendable, Equatable {
    public var type: EffectType
    public var intensity: Double
    public var speed: Double
    public var blurRadius: Double

    public init(
        type: EffectType = .fadeIn,
        intensity: Double = 1.0,
        speed: Double = 1.0,
        blurRadius: Double = 24.0
    ) {
        self.type = type
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        self.intensity = max(0.0, min(1.0, norm))
        self.speed = max(0.1, min(3.0, speed))
        self.blurRadius = max(1.0, min(100.0, blurRadius))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(EffectType.self, forKey: .type)
        let rawIntensity = try container.decode(Double.self, forKey: .intensity)
        let norm = rawIntensity > 1.0 ? (rawIntensity / 100.0) : rawIntensity
        self.intensity = max(0.0, min(1.0, norm))
        self.speed = try container.decode(Double.self, forKey: .speed)
        self.blurRadius = try container.decode(Double.self, forKey: .blurRadius)
    }

    public func encodeToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from jsonString: String) -> EffectConfiguration? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EffectConfiguration.self, from: data)
    }
}
