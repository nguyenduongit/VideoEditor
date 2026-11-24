import Foundation
import Domain

/// Resolves font names and unified `TextAnimationScript` identifiers for MCP / AI Assistant tools.
@MainActor
public enum MCPTextPropertyResolver {
    /// Resolves font query strings to registered PostScript font identifiers.
    public static func resolveFontName(_ raw: String, fontManager: CustomFontManager = CustomFontManager()) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "UVN Ke Chuyen" }

        let allFonts = fontManager.fonts

        if let exact = allFonts.first(where: {
            $0.id.caseInsensitiveCompare(trimmed) == .orderedSame ||
            $0.displayName.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return exact.id
        }

        let query = trimmed.lowercased()
        if let matched = allFonts.first(where: {
            $0.displayName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }) {
            return matched.id
        }

        return trimmed
    }

    /// Maps any continuous script ID, display name, or legacy keyword onto a unified `TextAnimationScript.id`.
    public static func resolveScriptId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard !lower.isEmpty, lower != "none" else { return "none" }

        if let exact = TextAnimationScriptRegistry.shared.script(for: trimmed) {
            return exact.id
        }
        if let byLowerId = TextAnimationScriptRegistry.shared.script(for: lower) {
            return byLowerId.id
        }
        if let byDisplayName = TextAnimationScriptRegistry.shared.scripts.first(where: {
            $0.displayName.lowercased() == lower || $0.id.lowercased() == lower
        }) {
            return byDisplayName.id
        }

        if lower.contains("karaoke") { return "karaoke_box_pop" }
        if lower.contains("line") && lower.contains("cascade") { return "line_cascade_rise" }
        if lower.contains("focus") || lower.contains("blur") { return "blur_focus_dissolve" }
        if lower.contains("beat") { return "beat_pulse_slam" }
        if lower.contains("tornado") || lower.contains("spiral") || lower.contains("vortex") { return "tornado_spiral_pop" }
        if lower.contains("type") || lower.contains("danh may") || lower.contains("hand") { return "typewriter_cursor" }
        if lower.contains("wave") || lower.contains("float") || lower.contains("song") { return "title_wave_float" }
        if lower.contains("kinetic") || lower.contains("drop") || lower.contains("roi") { return "kinetic_drop_glow" }
        if lower.contains("glitch") || lower.contains("rgb") || lower.contains("tv") || lower.contains("crt") { return "glitch_rgb_pop" }
        if lower.contains("neon") || lower.contains("flicker") || lower.contains("flash") { return "neon_cyber_shift" }
        if lower.contains("whip") || lower.contains("slam") { return "whip_echo_slam" }
        if lower.contains("slide") || lower.contains("glide") || lower.contains("fly") || lower.contains("truot") { return "smooth_word_glide" }
        if lower.contains("pop") || lower.contains("bounce") || lower.contains("zoom") || lower.contains("elastic") || lower.contains("nay") { return "pop_elastic_bounce" }
        if lower.contains("fade") || lower.contains("dissolve") { return "fade_soft_glow" }
        if lower.contains("breathe") || lower.contains("tho") { return "soft_breathe_cascade" }
        if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { return "liquid_wave_pulse" }
        return "smooth_word_glide"
    }
}
