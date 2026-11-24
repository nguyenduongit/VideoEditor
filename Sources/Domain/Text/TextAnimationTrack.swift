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
}
