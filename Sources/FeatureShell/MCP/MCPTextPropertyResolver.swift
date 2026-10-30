import Foundation
import Domain

/// Bộ giải quyết phông chữ và thuộc tính hoạt ảnh văn bản cho các lệnh MCP / AI Assistant.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@MainActor
public enum MCPTextPropertyResolver {
    /// Phân giải tên font từ câu lệnh của người dùng hoặc AI sang PostScript font ID thực tế.
    public static func resolveFontName(_ raw: String, fontManager: CustomFontManager = CustomFontManager()) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "UVN Ke Chuyen" }

        let allFonts = fontManager.fonts

        // 1. Khớp chính xác ID hoặc Display Name (không phân biệt hoa thường)
        if let exact = allFonts.first(where: {
            $0.id.caseInsensitiveCompare(trimmed) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return exact.id
        }

        // 2. Khớp chuỗi con (VD: "bay buom" -> "UVN Bay Buom", "da lat" -> "UVN Da Lat")
        let query = trimmed.lowercased()
        if let matched = allFonts.first(where: {
            $0.displayName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }) {
            return matched.id
        }

        // 3. Nếu người dùng chỉ định font quen thuộc (Helvetica, Impact, Arial...)
        return trimmed
    }

    /// Phân giải chuỗi hoạt ảnh xuất hiện (In Animation).
    public static func resolveInAnimation(_ raw: String) -> TextInAnimationType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = TextInAnimationType(rawValue: trimmed) { return exact }
        let lower = trimmed.lowercased()
        if lower.contains("fade") { return .fadeIn }
        if lower.contains("zoom") || lower.contains("expand") { return .zoomIn }
        if lower.contains("slide") || lower.contains("truot") || lower.contains("fly") || lower.contains("up") { return .slideUp }
        if lower.contains("whip") || lower.contains("move") || lower.contains("wipe") || lower.contains("right") || lower.contains("spin") || lower.contains("vortex") { return .whipRight }
        if lower.contains("type") || lower.contains("danh may") || lower.contains("hand") { return .typewriter }
        if lower.contains("drop") || lower.contains("bounce") || lower.contains("kinetic") || lower.contains("roi") || lower.contains("nay") { return .kineticDrop }
        return .fadeIn
    }

    /// Phân giải chuỗi hoạt ảnh biến mất (Out Animation).
    public static func resolveOutAnimation(_ raw: String) -> TextOutAnimationType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = TextOutAnimationType(rawValue: trimmed) { return exact }
        let lower = trimmed.lowercased()
        if lower.contains("fade") || lower.contains("dissolve") || lower.contains("pixel") { return .fadeOut }
        if lower.contains("zoom") || lower.contains("shrink") { return .zoomOut }
        if lower.contains("drop") || lower.contains("fall") || lower.contains("down") { return .dropDown }
        if lower.contains("whip") || lower.contains("slide") || lower.contains("right") { return .whipOut }
        if lower.contains("tv") || lower.contains("tivi") || lower.contains("crt") { return .tvOff }
        return .none
    }

    /// Phân giải chuỗi hoạt ảnh lặp lại (Loop Animation).
    public static func resolveLoopAnimation(_ raw: String) -> TextLoopAnimationType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = TextLoopAnimationType(rawValue: trimmed) { return exact }
        let lower = trimmed.lowercased()
        if lower.contains("flicker") || lower.contains("flash") || lower.contains("neon") || lower.contains("chop") { return .flicker }
        if lower.contains("breathe") || lower.contains("tho") { return .breathe }
        if lower.contains("wave") || lower.contains("song") || lower.contains("float") { return .wave }
        if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { return .pulse }
        if lower.contains("shake") || lower.contains("wobble") || lower.contains("jiggle") || lower.contains("rung") { return .shake }
        return .none
    }
}
