import Foundation

/// Central Dev-Only registry of all continuous Script-Driven Sticker Animations (`Intro → Loop → Outro`).
public final class StickerAnimationScriptRegistry: Sendable {
    public static let shared = StickerAnimationScriptRegistry()

    public let allScripts: [any StickerAnimationScript]
    private let scriptsById: [String: any StickerAnimationScript]
    private let legacyAliases: [String: String]

    private init() {
        let combined: [any StickerAnimationScript] =
            Self.fadeAndPopScripts + Self.swingAndMotionScripts + Self.glitchAndBounceScripts
        self.allScripts = combined
        var index: [String: any StickerAnimationScript] = [:]
        for script in combined {
            index[script.id] = script
        }
        self.scriptsById = index
        self.legacyAliases = [
            "pulse": "bounce_heartbeat",
            "nhịp tim": "bounce_heartbeat",
            "nhip tim": "bounce_heartbeat",
            "sway": "swing_sway_breeze",
            "lắc lư": "swing_sway_breeze",
            "lac lu": "swing_sway_breeze",
            "wobble": "swing_wobble",
            "rung lắc": "swing_wobble",
            "rung lac": "swing_wobble",
            "bounce": "bounce_drop",
            "nảy": "bounce_drop",
            "nay": "bounce_drop",
            "spin": "swing_spin_orbit",
            "xoay tròn": "swing_spin_orbit",
            "xoay tron": "swing_spin_orbit",
            "float": "fade_dream_float",
            "trôi nổi": "fade_dream_float",
            "troi noi": "fade_dream_float",
            "shake": "glitch_shake_impact",
            "rung mạnh": "glitch_shake_impact",
            "rung manh": "glitch_shake_impact",
            "breathe": "pop_elastic",
            "thở": "pop_elastic",
            "tho": "pop_elastic",
            "wave": "bounce_rubber",
            "lượn sóng": "bounce_rubber",
            "luon song": "bounce_rubber",
            "flicker": "fade_flicker_neon",
            "nhấp nháy": "fade_flicker_neon",
            "nhap nhay": "fade_flicker_neon"
        ]
    }

    /// Resolves canonical script ID from either a modern `scriptId` or legacy `loopType` identifier.
    public func canonicalScriptId(for rawId: String) -> String {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "none" else { return "" }
        if scriptsById[trimmed] != nil {
            return trimmed
        }
        return legacyAliases[trimmed.lowercased()] ?? ""
    }

    /// Returns the script instance for a given ID or legacy alias, if active.
    public func script(for id: String) -> (any StickerAnimationScript)? {
        let canonical = canonicalScriptId(for: id)
        guard !canonical.isEmpty else { return nil }
        return scriptsById[canonical]
    }

    /// Returns all scripts matching a UI category tab.
    public func scripts(in category: StickerAnimationCategory) -> [any StickerAnimationScript] {
        allScripts.filter { $0.category == category }
    }
}
