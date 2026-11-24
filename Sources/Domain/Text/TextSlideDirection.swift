import Foundation

/// Cardinal travel direction for directional `Slide` text animations.
/// Uses movement-direction convention:
/// - `up`: moves upward (enters from bottom edge `+Y`, exits off top edge `-Y`)
/// - `down`: moves downward (enters from top edge `-Y`, exits off bottom edge `+Y`)
/// - `left`: moves leftward (enters from right edge `+X`, exits off left edge `-X`)
/// - `right`: moves rightward (enters from left edge `-X`, exits off right edge `+X`)
public enum TextSlideDirection: String, Codable, Sendable, CaseIterable {
    case up
    case down
    case left
    case right

    public var title: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        }
    }

    /// Off-screen starting canvas offset ratio for Intro travel along this direction.
    /// Uses `1.25` canvas span so clips placed near opposite edges or spanning wide lines still enter from fully off-screen.
    public var entryCanvasOffsetRatio: (x: Double, y: Double) {
        switch self {
        case .up: return (0.0, 1.25)
        case .down: return (0.0, -1.25)
        case .left: return (1.25, 0.0)
        case .right: return (-1.25, 0.0)
        }
    }

    /// Off-screen ending canvas offset ratio for Outro travel along this direction.
    /// Uses `1.25` canvas span so clips placed near opposite edges or spanning wide lines still exit fully off-screen.
    public var exitCanvasOffsetRatio: (x: Double, y: Double) {
        switch self {
        case .up: return (0.0, -1.25)
        case .down: return (0.0, 1.25)
        case .left: return (-1.25, 0.0)
        case .right: return (1.25, 0.0)
        }
    }

    /// Directional motion-blur angle in radians aligned with this axis of motion.
    public var motionBlurAngle: Double {
        switch self {
        case .up, .down: return .pi * 0.5
        case .left, .right: return 0.0
        }
    }

    public var entryDescriptionPhrase: String {
        switch self {
        case .up: return "upward from bottom"
        case .down: return "downward from top"
        case .left: return "leftward from right"
        case .right: return "rightward from left"
        }
    }

    public var exitDescriptionPhrase: String {
        switch self {
        case .up: return "upward off top"
        case .down: return "downward off bottom"
        case .left: return "leftward off left"
        case .right: return "rightward off right"
        }
    }
}
