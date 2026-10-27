import Foundation
import Domain

/// Bộ giải quyết phông chữ và thuộc tính hoạt ảnh văn bản cho các lệnh MCP / AI Assistant.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@MainActor
public enum MCPTextPropertyResolver {
    /// Phân giải tên font từ câu lệnh của người dùng hoặc AI sang PostScript font ID thực tế.
    public static func resolveFontName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "UVN Ke Chuyen" }

        let allFonts = CustomFontManager.shared.fonts

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
        if lower.contains("zoom") && (lower.contains("out") || lower.contains("thu")) { return .zoomOutIn }
        if lower.contains("zoom") { return .zoomIn }
        if lower.contains("slide") || lower.contains("truot") || lower.contains("fly") {
            if lower.contains("up") || lower.contains("len") || lower.contains("top") { return .slideUp }
            if lower.contains("down") || lower.contains("xuong") || lower.contains("bottom") { return .slideDown }
            if lower.contains("left") || lower.contains("trai") { return .slideLeft }
            if lower.contains("right") || lower.contains("phai") { return .slideRight }
            return .slideUp
        }
        if lower.contains("move") || lower.contains("chuyen") { return .moveIn }
        if lower.contains("wipe") || lower.contains("lau") { return .wipe }
        if lower.contains("typewriter") || lower.contains("type") || lower.contains("danh may") {
            if lower.contains("2") || lower.contains("ii") { return .typewriter2 }
            return .typewriter1
        }
        if lower.contains("hand") || lower.contains("viet tay") { return .handwriting }
        if lower.contains("ink") || lower.contains("muc") { return .inkSplash }
        if lower.contains("chalk") || lower.contains("phan") || lower.contains("crayon") { return .chalk }
        if lower.contains("drop") || lower.contains("roi") || lower.contains("fall") || lower.contains("crash") { return .drop }
        if lower.contains("bounce") || lower.contains("spring") || lower.contains("nay") || lower.contains("pop") { return .bounce }
        if lower.contains("pendulum") || lower.contains("swing") || lower.contains("lac") { return .pendulum }
        if lower.contains("wobble") || lower.contains("lao dao") { return .wobble }
        if lower.contains("flip") || lower.contains("lat") {
            if lower.contains("horiz") || lower.contains("ngang") { return .flipHorizontal }
            if lower.contains("vert") || lower.contains("doc") { return .flipVertical }
            return .flip3D
        }
        if lower.contains("spin") || lower.contains("xoay") || lower.contains("vortex") || lower.contains("rotate") { return .spinIn }
        if lower.contains("roll") || lower.contains("lan") { return .rollIn }
        if lower.contains("page") || lower.contains("trang") { return .pageTurn }
        if lower.contains("glitch") || lower.contains("nhieu") || lower.contains("noise") { return .glitch }
        if lower.contains("pixel") { return .pixelate }
        if lower.contains("blur") || lower.contains("nhoe") { return .blurIn }
        if lower.contains("light") || lower.contains("streak") || lower.contains("flash") || lower.contains("chop") || lower.contains("shock") { return .lightStreak }
        if lower.contains("unfold") || lower.contains("stretch") || lower.contains("gap") { return .unfold }
        if lower.contains("cascade") || lower.contains("wave") || lower.contains("thac") { return .cascade }
        return .fadeIn
    }

    /// Phân giải chuỗi hoạt ảnh biến mất (Out Animation).
    public static func resolveOutAnimation(_ raw: String) -> TextOutAnimationType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = TextOutAnimationType(rawValue: trimmed) { return exact }
        let lower = trimmed.lowercased()
        if lower.contains("fade") { return .fadeOut }
        if lower.contains("zoom") && (lower.contains("in") || lower.contains("phong")) { return .zoomInOut }
        if lower.contains("zoom") { return .zoomOut }
        if lower.contains("slide") || lower.contains("truot") || lower.contains("fly") {
            if lower.contains("up") || lower.contains("len") || lower.contains("top") { return .slideUp }
            if lower.contains("down") || lower.contains("xuong") || lower.contains("bottom") { return .slideDown }
            if lower.contains("left") || lower.contains("trai") { return .slideLeft }
            if lower.contains("right") || lower.contains("phai") { return .slideRight }
            return .slideDown
        }
        if lower.contains("dissolve") || lower.contains("tan") || lower.contains("pixel") { return .dissolve }
        if lower.contains("drop") || lower.contains("roi") || lower.contains("fall") { return .dropOut }
        if lower.contains("shrink") || lower.contains("co") { return .shrink }
        if lower.contains("vapor") || lower.contains("smoke") || lower.contains("khoi") { return .vaporize }
        if lower.contains("shatter") || lower.contains("explode") || lower.contains("vo") || lower.contains("no") || lower.contains("shock") { return .shatter }
        if lower.contains("spin") || lower.contains("xoay") || lower.contains("spiral") { return .spinOut }
        if lower.contains("roll") || lower.contains("lan") { return .rollOut }
        if lower.contains("flip") || lower.contains("lat") { return .flipOut }
        if lower.contains("blind") || lower.contains("rem") { return .blinds }
        if lower.contains("tv") || lower.contains("tivi") { return .tvOff }
        if lower.contains("glitch") { return .glitchOut }
        if lower.contains("scan") { return .scanOut }
        return .none
    }

    /// Phân giải chuỗi hoạt ảnh lặp lại (Loop Animation).
    public static func resolveLoopAnimation(_ raw: String) -> TextLoopAnimationType {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = TextLoopAnimationType(rawValue: trimmed) { return exact }
        let lower = trimmed.lowercased()
        if lower.contains("neon") { return .neonGlow }
        if lower.contains("heart") || lower.contains("tim") || lower.contains("pulse") { return .pulse }
        if lower.contains("breathe") || lower.contains("tho") { return .breathe }
        if lower.contains("bounce") || lower.contains("nhun") { return .bounceLoop }
        if lower.contains("wobble") || lower.contains("jitter") || lower.contains("lac") || lower.contains("rung") || lower.contains("quake") || lower.contains("wiggle") { return .wobble }
        if lower.contains("pendulum") || lower.contains("chuong") { return .pendulumLoop }
        if lower.contains("float") || lower.contains("lo lung") { return .floating }
        if lower.contains("wave") || lower.contains("song") { return .waveLoop }
        if lower.contains("spin") || lower.contains("xoay") { return .spinLoop }
        if lower.contains("flash") || lower.contains("flicker") || lower.contains("chop") { return .flash }
        if lower.contains("neon") { return .neonGlow }
        if lower.contains("shine") || lower.contains("shimmer") || lower.contains("sang") { return .shine }
        if lower.contains("rainbow") || lower.contains("color") || lower.contains("mau") { return .rainbow }
        if lower.contains("glitch") { return .glitchLoop }
        if lower.contains("ripple") { return .ripple }
        if lower.contains("none") { return .none }
        return .none
    }
}
