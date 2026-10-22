import Foundation

public enum MediaType: String, Sendable, CaseIterable, Identifiable {
    case video
    case audio
    case image

    public var id: String {
        rawValue
    }

    public static func from(fileExtension: String) -> MediaType? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "mp4", "mov", "m4v", "mkv", "avi", "webm":
            return .video
        case "mp3", "wav", "m4a", "aac", "aiff", "flac":
            return .audio
        case "png", "jpg", "jpeg", "heic", "tiff", "webp", "gif":
            return .image
        default:
            return nil
        }
    }

    public var clipKind: ClipKind {
        switch self {
        case .video:
            return .video
        case .audio:
            return .audio
        case .image:
            return .image
        }
    }
}
