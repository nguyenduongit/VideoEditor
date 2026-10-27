import Foundation

/// Nhóm danh mục phân loại cho hoạt ảnh Vòng lặp (Loop Animation)
public enum TextLoopAnimationCategory: String, CaseIterable, Sendable, Identifiable {
    case all = "Tất cả"
    case dynamicMotion = "Chuyển động nhịp nhàng"
    case lightGlow = "Ánh sáng & Màu sắc"
    case distortion = "Biến dạng & Tín hiệu lạ"

    public var id: String { rawValue }
}

/// Danh mục đầy đủ 14 hiệu ứng vòng lặp (Loop Animation) chuyên nghiệp
public enum TextLoopAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"

    // 1. Chuyển động nhịp nhàng (Dynamic Motion)
    case pulse = "Pulse"
    case breathe = "Breathe"
    case bounceLoop = "Bounce Loop"
    case wobble = "Wobble"
    case pendulumLoop = "Pendulum Loop"
    case floating = "Floating"
    case waveLoop = "Wave Loop"
    case spinLoop = "Spin Loop"

    // 2. Ánh sáng & Màu sắc (Light & Glow)
    case flash = "Flash"
    case neonGlow = "Neon Glow"
    case shine = "Shine"
    case rainbow = "Rainbow"

    // 3. Biến dạng & Tín hiệu lạ (Distortion)
    case glitchLoop = "Glitch Loop"
    case ripple = "Ripple"

    public var id: String { rawValue }

    public var category: TextLoopAnimationCategory {
        switch self {
        case .none:
            return .all
        case .pulse, .breathe, .bounceLoop, .wobble, .pendulumLoop, .floating, .waveLoop, .spinLoop:
            return .dynamicMotion
        case .flash, .neonGlow, .shine, .rainbow:
            return .lightGlow
        case .glitchLoop, .ripple:
            return .distortion
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .pulse: return "waveform.path.ecg"
        case .breathe: return "lungs.fill"
        case .bounceLoop: return "figure.run"
        case .wobble: return "waveform.path"
        case .pendulumLoop: return "metronome"
        case .floating: return "water.waves"
        case .waveLoop: return "waveform"
        case .spinLoop: return "arrow.triangle.2.circlepath"
        case .flash: return "bolt.fill"
        case .neonGlow: return "lightbulb.fill"
        case .shine: return "wand.and.rays"
        case .rainbow: return "paintpalette"
        case .glitchLoop: return "bolt.horizontal"
        case .ripple: return "drop.degreesign.fill"
        }
    }
}

extension TextLoopAnimationType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        guard let raw else {
            self = .none
            return
        }
        if let match = TextLoopAnimationType(rawValue: raw) {
            self = match
            return
        }
        switch raw.lowercased() {
        case "light sweep", "lightsweep": self = .shine
        case "jelly wave", "jellywave": self = .bounceLoop
        case "3d pendulum", "swing3d": self = .pendulumLoop
        case "liquid wave", "liquidwave": self = .waveLoop
        case "wiggle": self = .wobble
        case "glitch": self = .glitchLoop
        case "heartbeat": self = .pulse
        case "neon pulse", "neonpulse": self = .neonGlow
        case "earthquake": self = .wobble
        default: self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
