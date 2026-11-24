import Foundation

/// 11 standard categories classifying system Visual Effects (`EffectLibraryItem`).
/// Complies with AGENTS.md (Pure Domain, 1 Primary Type per file, Sendable, Codable).
public enum EffectCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case basic = "Basic"
    case blur = "Blur"
    case glitch = "Glitch / Distortion"
    case light = "Light Effects"
    case retro = "Retro / Vintage / Film"
    case camera = "Camera Effects"
    case motion = "Motion Effects"
    case color = "Color Effects"
    case nature = "Particle / Nature"
    case artistic = "Artistic / Stylize"
    case overlay = "Text / Overlay"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .basic: return "Basic"
        case .blur: return "Blur"
        case .glitch: return "Glitch"
        case .light: return "Light"
        case .retro: return "Retro / Film"
        case .camera: return "Camera"
        case .motion: return "Motion"
        case .color: return "Color"
        case .nature: return "Nature"
        case .artistic: return "Artistic"
        case .overlay: return "Overlay"
        }
    }

    /// 11 assignable categories displayed in the Effects sidebar.
    public static var assignableCases: [EffectCategory] {
        [
            .basic,
            .blur,
            .glitch,
            .light,
            .retro,
            .camera,
            .motion,
            .color,
            .nature,
            .artistic,
            .overlay
        ]
    }

    // MARK: - Legacy Aliases

    public static let lightTransition: EffectCategory = .light
    public static let partyBeat: EffectCategory = .motion
    public static let cinematic: EffectCategory = .retro
    public static let motionShake: EffectCategory = .camera

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if let matched = EffectCategory(rawValue: str) {
            self = matched
            return
        }
        switch str.lowercased() {
        case "basic", "cơ bản", "basic effects": self = .basic
        case "blur", "làm mờ", "blur effects": self = .blur
        case "glitch", "glitch / distortion", "distortion", "nhiễu": self = .glitch
        case "light", "light effects", "ánh sáng", "ánh sáng & mở màn", "lighttransition": self = .light
        case "retro", "retro / vintage / film", "vintage", "film", "điện ảnh & mờ", "cinematic": self = .retro
        case "camera", "camera effects", "máy quay", "rung & chuyển động", "motionshake": self = .camera
        case "motion", "motion effects", "chuyển động", "nhịp điệu & flash", "partybeat": self = .motion
        case "color", "color effects", "màu sắc": self = .color
        case "nature", "particle / nature", "particles", "hạt & thiên nhiên", "nature effects": self = .nature
        case "artistic", "artistic / stylize", "stylize", "nghệ thuật", "artistic effects": self = .artistic
        case "overlay", "text / overlay", "lớp phủ", "overlay effects": self = .overlay
        default: self = .basic
        }
    }
}
