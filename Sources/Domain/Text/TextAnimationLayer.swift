import Foundation

/// Ordered stack of tracks blended together as a toggleable animation layer.
public struct TextAnimationLayer: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var weight: Double
    public var blendMode: TextAnimationBlendMode
    public var tracks: [TextAnimationTrack]

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = true,
        weight: Double = 1.0,
        blendMode: TextAnimationBlendMode = .replace,
        tracks: [TextAnimationTrack]
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.weight = min(1.0, max(0.0, weight))
        self.blendMode = blendMode
        self.tracks = tracks
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, weight, blendMode, tracks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Layer"
        self.isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        let rawWeight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 1.0
        self.weight = min(1.0, max(0.0, rawWeight))
        self.blendMode = try c.decodeIfPresent(TextAnimationBlendMode.self, forKey: .blendMode) ?? .replace
        self.tracks = try c.decodeIfPresent([TextAnimationTrack].self, forKey: .tracks) ?? []
    }
}
