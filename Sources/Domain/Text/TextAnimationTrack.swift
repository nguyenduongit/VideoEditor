import Foundation

/// Single channel binding inside a `TextAnimationLayer`.
/// Channel names use open strings (`TextAnimationChannel` constants for built-ins, custom IDs for plugins).
public struct TextAnimationTrack: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var channel: String
    public var phase: TextAnimationGraphPhase
    public var signal: TextAnimationSignal
    public var blendMode: TextAnimationBlendMode
    public var weight: Double
    public var staggerFraction: Double
    public var staggerDirection: TextStaggerDirection
    public var modifiers: [TextAnimationModifier]

    public init(
        id: String = UUID().uuidString,
        channel: String,
        phase: TextAnimationGraphPhase = .any,
        signal: TextAnimationSignal,
        blendMode: TextAnimationBlendMode = .replace,
        weight: Double = 1.0,
        staggerFraction: Double = 0.0,
        staggerDirection: TextStaggerDirection = .forward,
        modifiers: [TextAnimationModifier] = []
    ) {
        self.id = id
        self.channel = channel
        self.phase = phase
        self.signal = signal
        self.blendMode = blendMode
        self.weight = min(1.0, max(0.0, weight))
        self.staggerFraction = min(0.95, max(0.0, staggerFraction))
        self.staggerDirection = staggerDirection
        self.modifiers = modifiers
    }

    private enum CodingKeys: String, CodingKey {
        case id, channel, phase, signal, blendMode, weight, staggerFraction, staggerDirection, modifiers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.channel = try c.decode(String.self, forKey: .channel)
        self.phase = try c.decodeIfPresent(TextAnimationGraphPhase.self, forKey: .phase) ?? .any
        self.signal = try c.decode(TextAnimationSignal.self, forKey: .signal)
        self.blendMode = try c.decodeIfPresent(TextAnimationBlendMode.self, forKey: .blendMode) ?? .replace
        let rawWeight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 1.0
        self.weight = min(1.0, max(0.0, rawWeight))
        let rawStagger = try c.decodeIfPresent(Double.self, forKey: .staggerFraction) ?? 0.0
        self.staggerFraction = min(0.95, max(0.0, rawStagger))
        self.staggerDirection = try c.decodeIfPresent(TextStaggerDirection.self, forKey: .staggerDirection) ?? .forward
        self.modifiers = try c.decodeIfPresent([TextAnimationModifier].self, forKey: .modifiers) ?? []
    }
}
