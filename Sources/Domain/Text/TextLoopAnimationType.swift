import Foundation

/// Danh mục hoạt ảnh Vòng lặp (Loop Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public enum TextLoopAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case breathe = "Breathe"
    case wave = "Wave"
    case pulse = "Pulse"
    case shake = "Shake"
    case flicker = "Flicker"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .breathe: return "lungs.fill"
        case .wave: return "waveform.path"
        case .pulse: return "waveform.path.ecg"
        case .shake: return "bell.and.waves.left.and.right"
        case .flicker: return "bolt.fill"
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
        // Backward-compatibility mapping for legacy animation names
        let lower = raw.lowercased()
        if lower.contains("breathe") || lower.contains("tho") { self = .breathe }
        else if lower.contains("wave") || lower.contains("float") || lower.contains("ripple") { self = .wave }
        else if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { self = .pulse }
        else if lower.contains("shake") || lower.contains("wobble") || lower.contains("jiggle") || lower.contains("bounce") || lower.contains("pendulum") || lower.contains("spin") { self = .shake }
        else if lower.contains("flicker") || lower.contains("flash") || lower.contains("neon") || lower.contains("shine") || lower.contains("rainbow") || lower.contains("glitch") { self = .flicker }
        else { self = .none }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
