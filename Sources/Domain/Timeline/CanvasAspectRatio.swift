import Foundation
import CoreGraphics

/// Working canvas aspect ratio and render dimension specification for preview and export.
/// Complies with R2.3 of AGENTS.md.
public enum CanvasAspectRatio: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case ratio16x9 = "16:9"
    case ratio9x16 = "9:16"
    case ratio1x1 = "1:1"
    case ratio4x3 = "4:3"
    case ratio3x4 = "3:4"
    case ratio5x7 = "5:7"
    case ratio7x5 = "7:5"
    case ratio21x9 = "21:9"

    public var title: String {
        rawValue
    }

    public var width: CGFloat {
        switch self {
        case .ratio16x9: return 1920
        case .ratio9x16: return 1080
        case .ratio1x1:  return 1080
        case .ratio4x3:  return 1440
        case .ratio3x4:  return 1080
        case .ratio5x7:  return 1080
        case .ratio7x5:  return 1512
        case .ratio21x9: return 2560
        }
    }

    public var height: CGFloat {
        switch self {
        case .ratio16x9: return 1080
        case .ratio9x16: return 1920
        case .ratio1x1:  return 1080
        case .ratio4x3:  return 1080
        case .ratio3x4:  return 1440
        case .ratio5x7:  return 1512
        case .ratio7x5:  return 1080
        case .ratio21x9: return 1080
        }
    }

    public var renderSize: CGSize {
        CGSize(width: width, height: height)
    }

    public var ratio: CGFloat {
        width / height
    }

    /// Finds the closest supported aspect ratio for a given pixel dimension.
    public static func closest(for size: CGSize) -> CanvasAspectRatio {
        guard size.width > 0, size.height > 0 else { return .ratio16x9 }
        let targetRatio = size.width / size.height
        return allCases.min(by: { abs($0.ratio - targetRatio) < abs($1.ratio - targetRatio) }) ?? .ratio16x9
    }
}
