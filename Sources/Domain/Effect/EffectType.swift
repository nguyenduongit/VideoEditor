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
        case .fadeIn: return "Sáng dần (Fade In)"
        case .fadeOut: return "Tối dần (Fade Out)"
        case .whiteFlash: return "Chớp sáng (White Flash)"
        case .cinematicBlur: return "Làm mờ (Cinematic Blur)"
        case .cameraShake: return "Rung giật (Camera Shake)"
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
        case .fadeIn: return "Mở màn từ bóng đen chuyển dần sang sáng rõ"
        case .fadeOut: return "Kết màn chuyển dần từ video về màn hình tối"
        case .whiteFlash: return "Lóe sáng trắng chớp giật tạo điểm nhấn cao trào"
        case .cinematicBlur: return "Làm mờ ảo toàn cảnh để tôn chủ thể hoặc chữ"
        case .cameraShake: return "Rung lắc khung hình kịch tính theo nhịp điệu"
        }
    }
}
