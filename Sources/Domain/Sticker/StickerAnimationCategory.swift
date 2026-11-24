import Foundation

/// Curated system categories for Script-Driven Sticker Animations (100% English UI).
public enum StickerAnimationCategory: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case fade
    case pop
    case bounce
    case swing
    case motion
    case glitch

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .fade: return "Fade"
        case .pop: return "Pop"
        case .bounce: return "Bounce"
        case .swing: return "Swing"
        case .motion: return "Motion"
        case .glitch: return "Glitch"
        }
    }

    public var iconName: String {
        switch self {
        case .fade: return "sparkles"
        case .pop: return "wand.and.stars"
        case .bounce: return "figure.jumprope"
        case .swing: return "angle"
        case .motion: return "wind"
        case .glitch: return "bolt.horizontal.fill"
        }
    }
}
