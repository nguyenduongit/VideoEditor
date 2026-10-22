import Foundation
import CoreGraphics

/// Working canvas aspect ratio and render dimension specification for preview and export.
/// Complies with R2.3 of AGENTS.md.
public enum CanvasAspectRatio: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"

    public var title: String {
        rawValue
    }

    public var width: CGFloat {
        switch self {
        case .ratio16x9: return 1920
        case .ratio9x16: return 1080
        }
    }

    public var height: CGFloat {
        switch self {
        case .ratio16x9: return 1080
        case .ratio9x16: return 1920
        }
    }

    public var renderSize: CGSize {
        CGSize(width: width, height: height)
    }

    public var ratio: CGFloat {
        width / height
    }
}
