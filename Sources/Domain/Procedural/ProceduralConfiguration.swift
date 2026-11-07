import Foundation

/// Cấu hình chi tiết cho một clip video thuật toán (Procedural Configuration).
/// Tuân thủ AGENTS.md R2.3, R3.1 (File <= 300 dòng), R5.5 (Polymorphic Serialization).
public struct ProceduralConfiguration: Codable, Hashable, Sendable {
    public var type: ProceduralType
    public var speed: Double
    public var intensity: Double
    public var primaryColorHex: String
    public var secondaryColorHex: String
    public var accentColorHex: String
    public var blendMode: String
    public var scale: Double
    public var seed: Int
    public var customParameters: [String: Double]

    public init(
        type: ProceduralType = .meshAurora,
        speed: Double = 1.0,
        intensity: Double = 1.0,
        primaryColorHex: String? = nil,
        secondaryColorHex: String? = nil,
        accentColorHex: String? = nil,
        blendMode: String? = nil,
        scale: Double = 1.0,
        seed: Int = 42,
        customParameters: [String: Double] = [:]
    ) {
        self.type = type
        self.speed = max(0.1, min(10.0, speed))
        self.intensity = max(0.0, min(5.0, intensity))
        self.primaryColorHex = primaryColorHex ?? type.defaultPrimaryColorHex
        self.secondaryColorHex = secondaryColorHex ?? type.defaultSecondaryColorHex
        self.accentColorHex = accentColorHex ?? "#FFFFFF"
        self.blendMode = blendMode ?? type.defaultBlendMode
        self.scale = max(0.1, min(10.0, scale))
        self.seed = seed
        self.customParameters = customParameters
    }

    public func encodeToJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> ProceduralConfiguration? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ProceduralConfiguration.self, from: data)
    }
}
