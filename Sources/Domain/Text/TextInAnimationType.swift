import Foundation

/// Danh mục hoạt ảnh Xuất hiện (In Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public enum TextInAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case fadeIn = "Fade In"
    case zoomIn = "Zoom In"
    case slideUp = "Slide Up"
    case whipRight = "Whip Right"
    case kineticDrop = "Kinetic Drop"
    case typewriter = "Typewriter"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .fadeIn: return "sun.max"
        case .zoomIn: return "plus.magnifyingglass"
        case .slideUp: return "arrow.up"
        case .whipRight: return "arrow.right.to.line"
        case .kineticDrop: return "arrow.down.to.line"
        case .typewriter: return "keyboard"
        }
    }
}

extension TextInAnimationType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        guard let raw else {
            self = .none
            return
        }
        if let match = TextInAnimationType(rawValue: raw) {
            self = match
            return
        }
        // Backward-compatibility mapping for legacy animation names
        let lower = raw.lowercased()
        if lower.contains("fade") { self = .fadeIn }
        else if lower.contains("zoom") || lower.contains("cinema") || lower.contains("expand") { self = .zoomIn }
        else if lower.contains("slide") || lower.contains("truot") || lower.contains("fly") {
            if lower.contains("right") || lower.contains("phai") { self = .whipRight }
            else { self = .slideUp }
        }
        else if lower.contains("whip") || lower.contains("move") || lower.contains("wipe") { self = .whipRight }
        else if lower.contains("type") || lower.contains("danh may") || lower.contains("handwriting") || lower.contains("ink") || lower.contains("chalk") { self = .typewriter }
        else if lower.contains("drop") || lower.contains("bounce") || lower.contains("spring") || lower.contains("kinetic") || lower.contains("fall") || lower.contains("crash") || lower.contains("jelly") || lower.contains("pop") { self = .kineticDrop }
        else if lower.contains("flip") || lower.contains("spin") || lower.contains("roll") || lower.contains("vortex") { self = .slideUp }
        else if lower.contains("glitch") || lower.contains("pixel") || lower.contains("blur") || lower.contains("light") || lower.contains("streak") || lower.contains("unfold") || lower.contains("cascade") { self = .fadeIn }
        else { self = .none }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
