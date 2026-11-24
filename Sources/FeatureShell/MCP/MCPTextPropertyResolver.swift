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

        if lower.contains("karaoke") { return "karaoke_glow_flow" }
        if lower.contains("line") && lower.contains("cascade") { return "slide_up_up" }
        if lower.contains("focus") || lower.contains("blur") { return "blur_focus_dissolve" }
        if lower.contains("beat") { return "beat_pulse_slam" }
        if lower.contains("tornado") || lower.contains("spiral") || lower.contains("vortex") { return "tornado_spiral_pop" }
        if lower.contains("type") || lower.contains("danh may") || lower.contains("hand") { return "typewriter_cursor" }
        if lower.contains("wave") || lower.contains("float") || lower.contains("song") { return "title_wave_float" }
        if lower.contains("kinetic") || lower.contains("drop") || lower.contains("roi") { return "kinetic_drop_glow" }
        if lower.contains("glitch") || lower.contains("rgb") || lower.contains("tv") || lower.contains("crt") { return "glitch_rgb_pop" }
        if lower.contains("neon") || lower.contains("flicker") || lower.contains("flash") { return "neon_cyber_shift" }
        if let slideId = resolveDirectionalSlideId(from: lower) { return slideId }
        if lower.contains("whip") || lower.contains("slam") { return "slide_right_right" }
        if lower.contains("slide") || lower.contains("glide") || lower.contains("fly") || lower.contains("truot") { return "slide_right_right" }
        if lower.contains("pop") || lower.contains("bounce") || lower.contains("zoom") || lower.contains("elastic") || lower.contains("nay") { return "pop_elastic_bounce" }
        if lower.contains("fade") || lower.contains("dissolve") { return "fade_soft_glow" }
        if lower.contains("breathe") || lower.contains("tho") { return "soft_breathe_cascade" }
        if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { return "liquid_wave_pulse" }
        return "slide_right_right"
    }

    private static func resolveDirectionalSlideId(from lower: String) -> String? {
        let hasSlideCue = lower.contains("slide") || lower.contains("truot") || lower.contains("trượt")
            || (containsWholeWord("ra", in: lower) && (containsWholeWord("vào", in: lower) || containsWholeWord("vao", in: lower)))
        guard hasSlideCue else { return nil }

        let tokens = extractSlideDirectionsInOrder(from: lower)
        guard let first = tokens.first else { return nil }
        let second = tokens.count > 1 ? tokens[1] : first
        switch (first, second) {
        case (.up, .up): return "slide_up_up"
        case (.down, .down): return "slide_down_down"
        case (.up, .down): return "slide_up_down"
        case (.down, .up): return "slide_down_up"
        case (.left, .left): return "slide_left_left"
        case (.left, .right): return "slide_left_right"
        case (.right, .left): return "slide_right_left"
        case (.right, .right): return "slide_right_right"
        default: return "slide_\(first.rawValue)_\(first.rawValue)"
        }
    }

    private static func extractSlideDirectionsInOrder(from lower: String) -> [TextSlideDirection] {
        let mappings: [(String, TextSlideDirection)] = [
            ("xuống", .down), ("xuong", .down), ("down", .down),
            ("trái", .left), ("trai", .left), ("left", .left),
            ("phải", .right), ("phai", .right), ("right", .right),
            ("lên", .up), ("len", .up), ("up", .up)
        ]
        var hits: [(String.Index, TextSlideDirection)] = []
        for (keyword, dir) in mappings {
            var searchStart = lower.startIndex
            while let range = lower.range(of: keyword, range: searchStart..<lower.endIndex) {
                let beforeOk = range.lowerBound == lower.startIndex || !lower[lower.index(before: range.lowerBound)].isLetter
                let afterOk = range.upperBound == lower.endIndex || !lower[range.upperBound].isLetter
                if beforeOk && afterOk {
                    hits.append((range.lowerBound, dir))
                }
                searchStart = range.upperBound
            }
        }
        hits.sort { $0.0 < $1.0 }
        var ordered: [TextSlideDirection] = []
        for (_, dir) in hits where ordered.last != dir || ordered.count < 2 {
            ordered.append(dir)
            if ordered.count == 2 { break }
        }
        return ordered
    }

    private static func containsWholeWord(_ word: String, in text: String) -> Bool {
        var searchStart = text.startIndex
        while let range = text.range(of: word, range: searchStart..<text.endIndex) {
            let beforeOk = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let afterOk = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if beforeOk && afterOk { return true }
            searchStart = range.upperBound
        }
        return false
    }
}
