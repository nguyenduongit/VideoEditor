import Foundation

public enum ClipKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case video
    case audio
    case image
    case text
    case adjustment

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .image:
            return "Image"
        case .text:
            return "Text"
        case .adjustment:
            return "Adjustment"
        }
    }

    public var hasFixedSourceDuration: Bool {
        switch self {
        case .video, .audio:
            return true
        case .image, .text, .adjustment:
            return false
        }
    }

    public var canHaveAudio: Bool {
        switch self {
        case .video, .audio:
            return true
        case .image, .text, .adjustment:
            return false
        }
    }

    public var isMediaSized: Bool {
        switch self {
        case .video, .audio, .image:
            return true
        case .text, .adjustment:
            return false
        }
    }

    public var defaultTier: Int {
        switch self {
        case .text:
            return 0
        case .adjustment:
            return 1
        case .image:
            return 2
        case .video:
            return 3
        case .audio:
            return 4
        }
    }
}
