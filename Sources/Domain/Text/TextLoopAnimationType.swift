import Foundation

/// Danh mục hoạt ảnh Vòng lặp (Loop Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public enum TextLoopAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case pulse = "Pulse"
    case sway = "Sway"
    case wobble = "Wobble"
    case bounce = "Bounce"
    case spin = "Spin"
    case float = "Float"
    case shake = "Shake"
    case breathe = "Breathe"
    case wave = "Wave"
    case flicker = "Flicker"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "Không có"
        case .pulse: return "Nhịp đập"
        case .sway: return "Đung đưa"
        case .wobble: return "Lắc lư"
        case .bounce: return "Nhún nhảy"
        case .spin: return "Xoay vòng"
        case .float: return "Bồng bềnh"
        case .shake: return "Rung giật"
        case .breathe: return "Thở nhẹ"
        case .wave: return "Lượn sóng"
        case .flicker: return "Chớp sáng"
        }
    }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .pulse: return "waveform.path.ecg"
        case .sway: return "water.waves"
        case .wobble: return "skew"
        case .bounce: return "arrow.up.and.down"
        case .spin: return "arrow.clockwise"
        case .float: return "wind"
        case .shake: return "bell.and.waves.left.and.right"
        case .breathe: return "lungs.fill"
        case .wave: return "waveform.path"
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
        if lower.contains("sway") || lower.contains("duadua") { self = .sway }
        else if lower.contains("wobble") || lower.contains("laclu") { self = .wobble }
        else if lower.contains("bounce") || lower.contains("nhun") { self = .bounce }
        else if lower.contains("spin") || lower.contains("xoay") { self = .spin }
        else if lower.contains("float") || lower.contains("bongbenh") { self = .float }
        else if lower.contains("breathe") || lower.contains("tho") { self = .breathe }
        else if lower.contains("wave") || lower.contains("ripple") { self = .wave }
        else if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { self = .pulse }
        else if lower.contains("shake") || lower.contains("jiggle") { self = .shake }
        else if lower.contains("flicker") || lower.contains("flash") || lower.contains("neon") || lower.contains("shine") || lower.contains("rainbow") || lower.contains("glitch") { self = .flicker }
        else { self = .none }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
