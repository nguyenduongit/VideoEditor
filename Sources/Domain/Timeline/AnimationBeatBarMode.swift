import Foundation

/// Beat-locked musical loop cycle duration modes for both Text and Sticker animations.
public enum AnimationBeatBarMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case auto
    case oneBeat
    case twoBeats
    case oneBar
    case twoBars

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .auto: return "Auto Bar"
        case .oneBeat: return "1 Beat"
        case .twoBeats: return "1/2 Bar"
        case .oneBar: return "1 Bar"
        case .twoBars: return "2 Bars"
        }
    }
}
