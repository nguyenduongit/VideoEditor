import Foundation

public enum ShellTab: String, CaseIterable, Sendable, Identifiable {
    case media
    case audio
    case text
    case adjustment

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .media:
            return "Media"
        case .audio:
            return "Audio"
        case .text:
            return "Text"
        case .adjustment:
            return "Adjustment"
        }
    }
}
