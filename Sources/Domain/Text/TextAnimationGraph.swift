import Foundation

/// Data-driven Text Animation Graph evaluated procedurally across the continuous `Intro -> Loop -> Outro` lifecycle.
public struct TextAnimationGraph: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var scope: TextAnimationScope
    public var loopCycleDuration: Double
    public var layers: [TextAnimationLayer]
    public var staticStringChannels: [String: String]

    /// Convenience flattened view of all tracks in layer order.
    public var tracks: [TextAnimationTrack] { layers.flatMap(\.tracks) }
    public var isEmpty: Bool { tracks.isEmpty }

    public init(
        id: String,
        name: String,
        scope: TextAnimationScope = .wholeBlock,
        loopCycleDuration: Double = 1.0,
        tracks: [TextAnimationTrack] = [],
        layers: [TextAnimationLayer] = [],
        staticStringChannels: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.loopCycleDuration = max(0.05, loopCycleDuration)
        var resolvedLayers = layers
        if !tracks.isEmpty {
            resolvedLayers.insert(TextAnimationLayer(name: "Tracks", tracks: tracks), at: 0)
        }
        self.layers = resolvedLayers
        self.staticStringChannels = staticStringChannels
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case scope
        case loopCycleDuration
        case layers
        case staticStringChannels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.scope = try container.decodeIfPresent(TextAnimationScope.self, forKey: .scope) ?? .wholeBlock
        self.loopCycleDuration = max(0.05, try container.decodeIfPresent(Double.self, forKey: .loopCycleDuration) ?? 1.0)
        self.layers = try container.decodeIfPresent([TextAnimationLayer].self, forKey: .layers) ?? []
        self.staticStringChannels = try container.decodeIfPresent([String: String].self, forKey: .staticStringChannels) ?? [:]
    }

    public func evaluate(in context: TextAnimationGraphContext) -> TextAnimationParameterBag {
        var result = TextAnimationParameterBag(stringValues: staticStringChannels)
        for layer in layers where layer.isEnabled && layer.weight > 0.0 {
            let layerValues = Self.evaluateTracks(layer.tracks, in: context)
            for (channel, value) in layerValues.values {
                result.apply(value, to: channel, mode: layer.blendMode, weight: layer.weight)
            }
        }
        return result
    }

    private static func evaluateTracks(
        _ tracks: [TextAnimationTrack],
        in context: TextAnimationGraphContext
    ) -> TextAnimationParameterBag {
        var result = TextAnimationParameterBag()
        for track in tracks where track.phase == .any || track.phase == context.phase {
            let localContext = context.applyingStagger(
                fraction: track.staggerFraction,
                direction: track.staggerDirection
            )
            var value = track.signal.evaluate(in: localContext)
            for modifier in track.modifiers {
                value = modifier.apply(to: value)
            }
            result.apply(value, to: track.channel, mode: track.blendMode, weight: track.weight)
        }
        return result
    }
}
