import Foundation

/// Animation segmentation scope (Whole Block, Per Line, Per Word, or Per Character).
public enum TextAnimationScope: String, Codable, Sendable, CaseIterable, Identifiable {
    case wholeBlock = "Whole Block"
    case perLine = "Per Line"
    case perWord = "Per Word"
    case perCharacter = "Per Character"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wholeBlock: return "Whole Block"
        case .perLine: return "Per Line"
        case .perWord: return "Per Word"
        case .perCharacter: return "Per Character"
        }
    }
}

/// Stagger direction for per-word / per-character animation
public enum TextStaggerDirection: String, Codable, Sendable, CaseIterable, Identifiable {
    case forward = "Forward"
    case backward = "Backward"
    case centerOut = "Center Out"
    case edgesIn = "Edges In"
    case random = "Random"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .forward: return "Left → Right"
        case .backward: return "Right → Left"
        case .centerOut: return "Center Out"
        case .edgesIn: return "Edges In"
        case .random: return "Random"
        }
    }
}

/// Transform pivot / anchor point
public enum TextAnchorPoint: String, Codable, Sendable, CaseIterable, Identifiable {
    case center = "Center"
    case bottom = "Bottom"
    case top = "Top"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .center: return "Center"
        case .bottom: return "Bottom"
        case .top: return "Top"
        }
    }
}
