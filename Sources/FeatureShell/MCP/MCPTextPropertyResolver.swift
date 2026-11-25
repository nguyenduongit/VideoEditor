import Foundation
import os
import Domain

/// Resolves font names and unified `TextAnimationScript` identifiers for MCP / AI Assistant tools.
@MainActor
public enum MCPTextPropertyResolver {
    private static let logger = Logger(subsystem: "com.videoeditor.mcp", category: "TextPropertyResolver")
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
        if let slideId = resolveDirectionalSlideId(from: lower) { return slideId }
        if lower.contains("whip") || lower.contains("slam") { return "slide_right_right" }
        if lower.contains("slide") || lower.contains("glide") || lower.contains("fly") || lower.contains("truot") { return "slide_right_right" }
        if lower.contains("pop") || lower.contains("bounce") || lower.contains("zoom") || lower.contains("elastic") || lower.contains("nay") { return "pop_elastic_bounce" }
        if lower.contains("fade") || lower.contains("dissolve") { return "fade_soft_glow" }
        if lower.contains("breathe") || lower.contains("tho") { return "fade_soft_glow" }
        if lower.contains("pulse") || lower.contains("heart") || lower.contains("tim") { return "beat_pulse_slam" }
        return "slide_right_right"
    }

    /// Resolves preset IDs or keywords onto built-in `TextAnimationGraphLibrary` procedural graphs.
    public static func resolveGraph(from raw: String) -> TextAnimationGraph? {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return nil }
        if let exact = TextAnimationGraphLibrary.graph(for: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return exact
        }
        if let matched = TextAnimationGraphLibrary.allGraphs.first(where: {
            $0.id.lowercased() == lower || $0.name.lowercased() == lower
        }) {
            return matched
        }
        if lower.contains("origami") || lower.contains("unfold") { return TextAnimationGraphLibrary.origamiCornerUnfold }
        if lower.contains("vortex") && lower.contains("3d") { return TextAnimationGraphLibrary.spiralVortexOrbit }
        if lower.contains("twist") { return TextAnimationGraphLibrary.ribbonTwistSnap }
        if lower.contains("bubble") || lower.contains("bulge") || lower.contains("lens") { return TextAnimationGraphLibrary.lensBubblePop }
        if lower.contains("domino") { return TextAnimationGraphLibrary.dominoBottomCascade }
        if lower.contains("eq") || lower.contains("equalizer") { return TextAnimationGraphLibrary.audioEqualizerBounce }
        if lower.contains("slalom") || lower.contains("spline") { return TextAnimationGraphLibrary.slalomSplineGlide }
        if lower.contains("trapdoor") || (lower.contains("right") && lower.contains("hinge")) { return TextAnimationGraphLibrary.rightHingeTrapdoor }
        if lower.contains("mercury") || lower.contains("jelly") { return TextAnimationGraphLibrary.jellyMercuryWave }
        if lower.contains("corner") && lower.contains("pendulum") { return TextAnimationGraphLibrary.pendulumTopCorner }
        if lower.contains("iris") || lower.contains("carve") { return TextAnimationGraphLibrary.irisLaserCarve }
        if lower.contains("cipher") && lower.contains("slash") { return TextAnimationGraphLibrary.cipherScrambleDraw }
        if lower.contains("door") || lower.contains("hinge") { return TextAnimationGraphLibrary.doorHingeSwing3D }
        if lower.contains("orbit") || lower.contains("carousel") { return TextAnimationGraphLibrary.orbitCarousel3D }
        if lower.contains("bezier") || lower.contains("flight") { return TextAnimationGraphLibrary.bezierRibbonFly }
        if lower.contains("ribbon") || lower.contains("flag") || lower.contains("mesh") { return TextAnimationGraphLibrary.flagMeshFlutter }
        if lower.contains("bend") { return TextAnimationGraphLibrary.arcBendBounce }
        if lower.contains("expand") || lower.contains("gravity") { return TextAnimationGraphLibrary.trackedGravityExpand }
        if lower.contains("bevel") || lower.contains("chrome") { return TextAnimationGraphLibrary.chromeBevelStudio3D }
        if lower.contains("particle") || lower.contains("quantum") { return TextAnimationGraphLibrary.quantumParticleAssembly }
        if lower.contains("audio") && lower.contains("beat") { return TextAnimationGraphLibrary.audioBeatKineticPulse }
        return nil
    }

    /// Applies MCP animation script ID, preset graph, or inline `animationGraph` JSON dictionary onto `TextConfiguration`.
    public static func applyAnimationOverrides(from dict: [String: Any], to cfg: inout TextConfiguration) {
        if let graphDict = dict["animationGraph"] as? [String: Any] {
            do {
                let data = try JSONSerialization.data(withJSONObject: graphDict)
                let decoded = try JSONDecoder().decode(TextAnimationGraph.self, from: data)
                cfg.animation.graph = decoded
                cfg.animation.scriptId = decoded.id
                let speed = (dict["animationSpeed"] as? Double) ?? cfg.animation.scriptSpeed
                let baseSteps = max(1, Int((decoded.loopCycleDuration * 3.0).rounded()))
                cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: baseSteps, speed: speed)
                return
            } catch {
                logger.error("Failed to decode inline animationGraph JSON: \(error.localizedDescription, privacy: .public)")
            }
        }

        let rawScript = (dict["animationGraph"] as? String)
            ?? (dict["animationScript"] as? String)
            ?? (dict["scriptId"] as? String)
            ?? (dict["inAnimation"] as? String)
            ?? (dict["loopAnimation"] as? String)
            ?? (dict["outAnimation"] as? String)
        if let rawScript {
            if let graph = resolveGraph(from: rawScript) {
                cfg.animation.graph = graph
                cfg.animation.scriptId = graph.id
                let speed = (dict["animationSpeed"] as? Double) ?? cfg.animation.scriptSpeed
                let baseSteps = max(1, Int((graph.loopCycleDuration * 3.0).rounded()))
                cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: baseSteps, speed: speed)
            } else {
                let resolvedId = resolveScriptId(rawScript)
                cfg.animation.graph = nil
                cfg.animation.scriptId = resolvedId
                if let script = TextAnimationScriptRegistry.shared.script(for: resolvedId) {
                    let speed = (dict["animationSpeed"] as? Double) ?? cfg.animation.scriptSpeed
                    let baseSteps = max(1, Int(script.defaultLoopDuration.rounded()))
                    cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: baseSteps, speed: speed)
                }
            }
        } else if let speed = dict["animationSpeed"] as? Double, cfg.animation.hasScriptAnimation {
            let steps = cfg.animation.scriptBaseLoopSeconds
            cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: steps, speed: speed)
        }
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
