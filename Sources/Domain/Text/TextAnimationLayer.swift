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
}
