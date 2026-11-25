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
        case tracks
        case staticStringChannels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? self.id
        self.scope = try container.decodeIfPresent(TextAnimationScope.self, forKey: .scope) ?? .wholeBlock
        self.loopCycleDuration = max(0.05, try container.decodeIfPresent(Double.self, forKey: .loopCycleDuration) ?? 1.0)
        var resolvedLayers = try container.decodeIfPresent([TextAnimationLayer].self, forKey: .layers) ?? []
        let flatTracks = try container.decodeIfPresent([TextAnimationTrack].self, forKey: .tracks) ?? []
        if !flatTracks.isEmpty {
            resolvedLayers.insert(TextAnimationLayer(name: "Tracks", tracks: flatTracks), at: 0)
        }
        self.layers = resolvedLayers
        self.staticStringChannels = try container.decodeIfPresent([String: String].self, forKey: .staticStringChannels) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(scope, forKey: .scope)
        try container.encode(loopCycleDuration, forKey: .loopCycleDuration)
        try container.encode(layers, forKey: .layers)
        try container.encode(staticStringChannels, forKey: .staticStringChannels)
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
        guard context.isSeamlessLifecycle else {
            return evaluateStrictTracks(tracks, in: context)
        }
        switch context.phase {
        case .any, .loop:
            return evaluateStrictTracks(tracks, in: context)
        case .intro:
            return evaluateSeamlessIntroTracks(tracks, in: context)
        case .outro:
            return evaluateSeamlessOutroTracks(tracks, in: context)
        }
    }

    private static func evaluateStrictTracks(
        _ tracks: [TextAnimationTrack],
        in context: TextAnimationGraphContext
    ) -> TextAnimationParameterBag {
        var result = TextAnimationParameterBag()
        for track in tracks where track.phase == .any || track.phase == context.phase {
            let value = sampleTrack(track, in: context)
            result.apply(value, to: track.channel, mode: track.blendMode, weight: track.weight)
        }
        return result
    }

    private static func evaluateSeamlessIntroTracks(
        _ tracks: [TextAnimationTrack],
        in context: TextAnimationGraphContext
    ) -> TextAnimationParameterBag {
        var result = evaluateStrictTracks(tracks, in: context)
        let introGate = dominantStagger(in: tracks, for: .intro)
        for track in tracks where track.phase == .loop {
            let gateFraction = introGate.fraction > 0.0 ? introGate.fraction : track.staggerFraction
            let gateDir = introGate.fraction > 0.0 ? introGate.direction : track.staggerDirection
            let uIn = context.unitStaggerProgress(fraction: gateFraction, direction: gateDir)
            let env = smoothstep(uIn)
            guard env > 0.0 else { continue }
            let value = sampleTrack(track, in: context)
            result.apply(value, to: track.channel, mode: track.blendMode, weight: track.weight * env)
        }
        return result
    }

    private static func evaluateSeamlessOutroTracks(
        _ tracks: [TextAnimationTrack],
        in context: TextAnimationGraphContext
    ) -> TextAnimationParameterBag {
        var result = TextAnimationParameterBag()
        for track in tracks where track.phase == .any {
            result.apply(sampleTrack(track, in: context), to: track.channel, mode: track.blendMode, weight: track.weight)
        }
        let nonReplaceOutro = Set(tracks.lazy.filter { $0.phase == .outro && $0.blendMode != .replace }.map(\.channel))
        let outroGate = dominantStagger(in: tracks, for: .outro)
        var loopChannels = Set<String>()
        for track in tracks where track.phase == .loop {
            loopChannels.insert(track.channel)
            var weight = track.weight
            if nonReplaceOutro.contains(track.channel) {
                let gateFraction = outroGate.fraction > 0.0 ? outroGate.fraction : track.staggerFraction
                let gateDir = outroGate.fraction > 0.0 ? outroGate.direction : track.staggerDirection
                let uOut = context.unitStaggerProgress(fraction: gateFraction, direction: gateDir)
                weight *= (1.0 - smoothstep(uOut))
            }
            result.apply(sampleTrack(track, in: context), to: track.channel, mode: track.blendMode, weight: weight)
        }
        for track in tracks where track.phase == .outro {
            let localCtx = context.applyingStagger(fraction: track.staggerFraction, direction: track.staggerDirection)
            let value = applyModifiers(track.modifiers, to: track.signal.evaluate(in: localCtx))
            let weight = (loopChannels.contains(track.channel) && track.blendMode == .replace)
                ? track.weight * smoothstep(localCtx.phaseProgress)
                : track.weight
            result.apply(value, to: track.channel, mode: track.blendMode, weight: weight)
        }
        return result
    }

    private static func sampleTrack(_ track: TextAnimationTrack, in context: TextAnimationGraphContext) -> Double {
        let localContext = context.applyingStagger(
            fraction: track.staggerFraction,
            direction: track.staggerDirection
        )
        return applyModifiers(track.modifiers, to: track.signal.evaluate(in: localContext))
    }

    private static func applyModifiers(_ modifiers: [TextAnimationModifier], to raw: Double) -> Double {
        var value = raw
        for modifier in modifiers { value = modifier.apply(to: value) }
        return value
    }

    private static func dominantStagger(
        in tracks: [TextAnimationTrack],
        for phase: TextAnimationGraphPhase
    ) -> (fraction: Double, direction: TextStaggerDirection) {
        var best: (Double, TextStaggerDirection) = (0.0, .forward)
        for track in tracks where track.phase == phase && track.staggerFraction > best.0 {
            best = (track.staggerFraction, track.staggerDirection)
        }
        return best
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = min(1.0, max(0.0, x))
        return t * t * (3.0 - 2.0 * t)
    }
}
