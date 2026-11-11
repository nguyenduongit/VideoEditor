import Foundation

public enum ClipKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case video
    case audio
    case image
    case text
    case effect
    case adjustment
    case sticker

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
        case .effect:
            return "Effect"
        case .adjustment:
            return "Adjustment"
        case .sticker:
            return "Sticker"
        }
    }

    public var hasFixedSourceDuration: Bool {
        switch self {
        case .video, .audio:
            return true
        case .image, .text, .adjustment, .effect, .sticker:
            return false
        }
    }

    public var canHaveAudio: Bool {
        switch self {
        case .video, .audio:
            return true
        case .image, .text, .adjustment, .effect, .sticker:
            return false
        }
    }

    public var isMediaSized: Bool {
        switch self {
        case .video, .audio, .image:
            return true
        case .text, .adjustment, .effect, .sticker:
            return false
        }
    }

    public var defaultTier: Int {
        switch self {
        case .sticker:
            return 0
        case .text:
            return 0
        case .effect:
            return 1
        case .adjustment:
            return 2
        case .image:
            return 3
        case .video:
            return 4
        case .audio:
            return 5
        }
    }

    public var isAuxiliary: Bool {
        switch self {
        case .video, .audio, .image:
            return false
        case .text, .adjustment, .effect, .sticker:
            return true
        }
    }

    public var iconName: String {
        switch self {
        case .video:
            return "video.fill"
        case .audio:
            return "waveform"
        case .image:
            return "photo"
        case .text:
            return "textformat"
        case .effect:
            return "wand.and.stars"
        case .adjustment:
            return "slider.horizontal.3"
        case .sticker:
            return "face.smiling"
        }
    }
}
