import Foundation

/// Danh mục hoạt ảnh Biến mất (Out Animation) tinh tuyển chuẩn CapCut Pro
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, không UI) và R4.3 (đơn nhiệm).
public enum TextOutAnimationType: String, Sendable, CaseIterable, Identifiable {
    case none = "None"
    case fadeOut = "Fade Out"
    case zoomOut = "Zoom Out"
    case dropDown = "Drop Down"
    case whipOut = "Whip Out"
    case tvOff = "TV Off"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .fadeOut: return "sun.min"
        case .zoomOut: return "minus.magnifyingglass"
        case .dropDown: return "arrow.down.to.line"
        case .whipOut: return "arrow.right"
        case .tvOff: return "tv.slash"
        }
    }
}

extension TextOutAnimationType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        guard let raw else {
            self = .none
            return
        }
        if let match = TextOutAnimationType(rawValue: raw) {
            self = match
            return
        }
        // Backward-compatibility mapping for legacy animation names
        let lower = raw.lowercased()
        if lower.contains("fade") || lower.contains("dissolve") || lower.contains("pixel") { self = .fadeOut }
        else if lower.contains("zoom") || lower.contains("shrink") || lower.contains("vapor") || lower.contains("shatter") { self = .zoomOut }
        else if lower.contains("drop") || lower.contains("fall") || lower.contains("down") { self = .dropDown }
        else if lower.contains("whip") || lower.contains("slide") || lower.contains("fly") || lower.contains("right") || lower.contains("left") { self = .whipOut }
        else if lower.contains("tv") || lower.contains("blind") || lower.contains("glitch") || lower.contains("scan") || lower.contains("spin") || lower.contains("flip") || lower.contains("roll") { self = .tvOff }
        else { self = .none }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
