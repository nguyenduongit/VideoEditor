import Foundation

/// 8 Danh mục chuẩn phân loại hiệu ứng Chuyển cảnh (NLE Transition Categories).
/// Tuân thủ AGENTS.md (Pure Domain, Sendable, Codable, File <= 300 dòng).
public enum TransitionCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case basic = "Basic"
    case slideWipe = "Slide & Wipe"
    case zoom = "Zoom"
    case blur = "Blur"
    case camera = "Camera & Motion"
    case glitch = "Glitch & Distortion"
    case light = "Light Effects"
    case advanced3D = "3D & Mask"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue
    }

    /// Danh sách 8 danh mục có thể gán cho mẫu chuyển cảnh trên thanh Sidebar.
    public static var assignableCases: [TransitionCategory] {
        [
            .basic,
            .slideWipe,
            .zoom,
            .blur,
            .camera,
            .glitch,
            .light,
            .advanced3D
        ]
    }

    // MARK: - Backward Compatibility Aliases

    public static let motion: TransitionCategory = .camera
    public static let geometric: TransitionCategory = .advanced3D

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if let matched = TransitionCategory(rawValue: str) {
            self = matched
            return
        }
        switch str.lowercased() {
        case "cơ bản", "basic": self = .basic
        case "chuyển động", "motion": self = .camera
        case "kỹ xảo & glitch", "glitch": self = .glitch
        case "ánh sáng & phim", "light": self = .light
        case "hình học", "geometric": self = .advanced3D
        case "slide & wipe", "slidewipe": self = .slideWipe
        case "zoom": self = .zoom
        case "blur": self = .blur
        case "3d & mask", "3dmask": self = .advanced3D
        default: self = .basic
        }
    }
}

