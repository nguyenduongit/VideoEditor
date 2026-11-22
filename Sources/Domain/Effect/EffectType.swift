import Foundation

/// Định danh các loại hiệu ứng thị giác toàn khung hình (Video Effects).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation).
public enum EffectType: String, Codable, Sendable, CaseIterable, Identifiable {
    case fadeIn = "fadeIn"
    case fadeOut = "fadeOut"
    case whiteFlash = "whiteFlash"
    case cinematicBlur = "cinematicBlur"
    case cameraShake = "cameraShake"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fadeIn: return "Fade In"
        case .fadeOut: return "Fade Out"
        case .whiteFlash: return "White Flash"
        case .cinematicBlur: return "Cinematic Blur"
        case .cameraShake: return "Camera Shake"
        }
    }

    public var iconName: String {
        switch self {
        case .fadeIn: return "sun.max.fill"
        case .fadeOut: return "moon.fill"
        case .whiteFlash: return "bolt.fill"
        case .cinematicBlur: return "circle.dotted"
        case .cameraShake: return "water.waves"
        }
    }

    public var description: String {
        switch self {
        case .fadeIn: return "Opens smoothly from black into full brightness"
        case .fadeOut: return "Fades smoothly from video to black at the end"
        case .whiteFlash: return "Sharp white flash accent for dramatic beats"
        case .cinematicBlur: return "Soft full-frame blur to highlight subjects or text"
        case .cameraShake: return "Dynamic frame shake synced to energetic motion"
        }
    }
}
