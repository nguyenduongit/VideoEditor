import Foundation

/// Continuous unified execution phase evaluated by a `StickerAnimationScript`.
public enum StickerScriptPhase: Sendable, Equatable {
    /// Entry phase with normalized progress `0.0 ... 1.0`.
    case intro(progress: Double)
    /// Continuous loop phase with elapsed loop time, full loop span in seconds, and resolved exact integer cycles.
    case loop(elapsed: Double, loopDuration: Double, cycles: Int = 0)
    /// Exit phase with normalized progress `0.0 ... 1.0`.
    case outro(progress: Double)
}
