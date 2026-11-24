import Foundation

/// Motion easing curve options available for curves & timing utilities.
public enum TextMotionEasing: String, Codable, Sendable, CaseIterable, Identifiable {
    case smooth = "Smooth"
    case spring = "Spring"
    case bounce = "Bounce"
    case elastic = "Elastic"

    public var id: String { rawValue }
}

/// Unified Script-Driven Text Animation configuration (`Intro -> Loop -> Outro` as one continuous block).
/// Enforces AGENTS.md Điều 14 (no detached In/Loop/Out enums, manifests, or mix-and-match assembly).
public struct TextAnimationConfiguration: Codable, Sendable, Equatable, Hashable {
    public var scriptId: String
    public var scriptDuration: Double
    public var scriptInDuration: Double
    public var scriptLoopDuration: Double
    public var scriptOutDuration: Double
    public var isScriptLoop: Bool
    public var scriptSpeed: Double
    public var scriptIntensity: Double
    public var scopeOverride: TextAnimationScope?
    public var isBeatSyncEnabled: Bool
    public var beatBPM: Double
    public var beatBarMode: AnimationBeatBarMode

    public var scope: TextAnimationScope
    public var staggerDirection: TextStaggerDirection
    public var staggerDelay: Double
    public var anchorPoint: TextAnchorPoint
    public var rgbSplitIntensity: Double
    public var lightSweepIntensity: Double
    public var isMaskEnabled: Bool
    public var isMotionBlurEnabled: Bool
    public var isTypewriterCursorVisible: Bool
    public var highlightColorHex: String
    public var motionEasing: TextMotionEasing
    /// Optional data-driven animation graph; takes precedence over compiled `scriptId` when set.
    public var graph: TextAnimationGraph?

    public init(
        scriptId: String = "none",
        scriptDuration: Double = 5.0,
        scriptInDuration: Double = 1.0,
        scriptLoopDuration: Double = 3.0,
        scriptOutDuration: Double = 1.0,
        isScriptLoop: Bool = false,
        scriptSpeed: Double = 1.0,
        scriptIntensity: Double = 1.0,
        scopeOverride: TextAnimationScope? = nil,
        isBeatSyncEnabled: Bool = false,
        beatBPM: Double = 120.0,
        beatBarMode: AnimationBeatBarMode = .auto,
        scope: TextAnimationScope = .wholeBlock,
        staggerDirection: TextStaggerDirection = .forward,
        staggerDelay: Double = 0.04,
        anchorPoint: TextAnchorPoint = .center,
        rgbSplitIntensity: Double = 0.0,
        lightSweepIntensity: Double = 0.0,
        isMaskEnabled: Bool = false,
        isMotionBlurEnabled: Bool = true,
        isTypewriterCursorVisible: Bool = true,
        highlightColorHex: String = "#FDE047",
        motionEasing: TextMotionEasing = .smooth,
        graph: TextAnimationGraph? = nil
    ) {
        self.scriptId = scriptId
        self.scriptInDuration = max(0.0, min(20.0, scriptInDuration))
        self.scriptLoopDuration = max(0.2, min(80.0, scriptLoopDuration))
        self.scriptOutDuration = max(0.0, min(20.0, scriptOutDuration))
        self.scriptDuration = max(0.2, min(120.0, scriptDuration))
        self.isScriptLoop = isScriptLoop
        self.scriptSpeed = max(0.2, min(4.0, scriptSpeed))
        self.scriptIntensity = max(0.2, min(2.0, scriptIntensity))
        self.scopeOverride = scopeOverride
        self.isBeatSyncEnabled = isBeatSyncEnabled
        self.beatBPM = max(40.0, min(240.0, beatBPM))
        self.beatBarMode = beatBarMode
        self.scope = scope
        self.staggerDirection = staggerDirection
        self.staggerDelay = max(0.01, min(0.2, staggerDelay))
        self.anchorPoint = anchorPoint
        self.rgbSplitIntensity = max(0.0, min(20.0, rgbSplitIntensity))
        self.lightSweepIntensity = max(0.0, min(1.0, lightSweepIntensity))
        self.isMaskEnabled = isMaskEnabled
        self.isMotionBlurEnabled = isMotionBlurEnabled
        self.isTypewriterCursorVisible = isTypewriterCursorVisible
        self.highlightColorHex = highlightColorHex
        self.motionEasing = motionEasing
        self.graph = graph
    }

    enum CodingKeys: String, CodingKey {
        case scriptId, scriptDuration, scriptInDuration, scriptLoopDuration, scriptOutDuration
        case isScriptLoop, scriptSpeed, scriptIntensity, scopeOverride, isBeatSyncEnabled, beatBPM, beatBarMode
        case scope, staggerDirection, staggerDelay, anchorPoint
        case rgbSplitIntensity, lightSweepIntensity, isMaskEnabled, isMotionBlurEnabled
        case isTypewriterCursorVisible, highlightColorHex, motionEasing, graph
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case inType, outType, loopType, comboType
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var resolvedScriptId = (try? c.decodeIfPresent(String.self, forKey: .scriptId)) ?? "none"
        if resolvedScriptId == "none" || resolvedScriptId.isEmpty {
            let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self)
            resolvedScriptId = Self.migrateLegacyScriptId(from: legacy)
        }
        self.scriptId = resolvedScriptId
        self.scriptInDuration = max(0.0, min(20.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptInDuration)) ?? 1.0))
        self.scriptLoopDuration = max(0.2, min(80.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptLoopDuration)) ?? 3.0))
        self.scriptOutDuration = max(0.0, min(20.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptOutDuration)) ?? 1.0))
        self.scriptDuration = max(0.2, min(120.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptDuration)) ?? 5.0))
        self.isScriptLoop = (try? c.decodeIfPresent(Bool.self, forKey: .isScriptLoop)) ?? false
        self.scriptSpeed = max(0.2, min(4.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptSpeed)) ?? 1.0))
        self.scriptIntensity = max(0.2, min(2.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptIntensity)) ?? 1.0))
        self.scopeOverride = try? c.decodeIfPresent(TextAnimationScope.self, forKey: .scopeOverride)
        self.isBeatSyncEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isBeatSyncEnabled)) ?? false
        self.beatBPM = max(40.0, min(240.0, (try? c.decodeIfPresent(Double.self, forKey: .beatBPM)) ?? 120.0))
        self.beatBarMode = (try? c.decodeIfPresent(AnimationBeatBarMode.self, forKey: .beatBarMode)) ?? .auto
        self.scope = (try? c.decodeIfPresent(TextAnimationScope.self, forKey: .scope)) ?? .wholeBlock
        self.staggerDirection = (try? c.decodeIfPresent(TextStaggerDirection.self, forKey: .staggerDirection)) ?? .forward
        self.staggerDelay = max(0.01, min(0.2, (try? c.decodeIfPresent(Double.self, forKey: .staggerDelay)) ?? 0.04))
        self.anchorPoint = (try? c.decodeIfPresent(TextAnchorPoint.self, forKey: .anchorPoint)) ?? .center
        self.rgbSplitIntensity = max(0.0, min(20.0, (try? c.decodeIfPresent(Double.self, forKey: .rgbSplitIntensity)) ?? 0.0))
        self.lightSweepIntensity = max(0.0, min(1.0, (try? c.decodeIfPresent(Double.self, forKey: .lightSweepIntensity)) ?? 0.0))
        self.isMaskEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isMaskEnabled)) ?? false
        self.isMotionBlurEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isMotionBlurEnabled)) ?? true
        self.isTypewriterCursorVisible = (try? c.decodeIfPresent(Bool.self, forKey: .isTypewriterCursorVisible)) ?? true
        self.highlightColorHex = (try? c.decodeIfPresent(String.self, forKey: .highlightColorHex)) ?? "#FDE047"
        self.motionEasing = (try? c.decodeIfPresent(TextMotionEasing.self, forKey: .motionEasing)) ?? .smooth
        self.graph = try? c.decodeIfPresent(TextAnimationGraph.self, forKey: .graph)
    }

    public var hasScriptAnimation: Bool {
        graph != nil || (scriptId != "none" && !scriptId.isEmpty)
    }

    /// Base loop seconds (integer multiple of 1s, default 3s) before multiplying by `scriptSpeed`.
    public var scriptBaseLoopSeconds: Int {
        let unit = max(0.1, scriptInDuration > 0.05 ? scriptInDuration : scriptSpeed)
        return max(1, min(30, Int((scriptLoopDuration / unit).rounded())))
    }

    /// Applies normalized continuous timing:
    /// Base In = 1s, Base Out = 1s, Base Loop = `baseLoopSeconds` * 1s, all scaled smoothly by `speed`.
    public mutating func applyUnifiedScriptTiming(baseLoopSeconds: Int, speed: Double) {
        let cleanLoop = max(1, min(30, baseLoopSeconds))
        let cleanSpeed = max(0.2, min(4.0, (speed * 100.0).rounded() / 100.0))
        self.scriptSpeed = cleanSpeed
        self.scriptInDuration = (1.0 * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptLoopDuration = (Double(cleanLoop) * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptOutDuration = (1.0 * cleanSpeed * 100.0).rounded() / 100.0
        self.scriptDuration = (Double(2 + cleanLoop) * cleanSpeed * 100.0).rounded() / 100.0
    }

    /// Resolves integer-cycle `Loop` and symmetric `In = Out = R / 2` from real Timeline clip duration.
    public func resolvedPhases(
        forClipDuration clipDuration: Double,
        baseCycleSeconds: Double = 1.0
    ) -> ResolvedAnimationPhases {
        AnimationPhaseTimingCalculator.calculate(
            clipDuration: clipDuration,
            baseCycleSeconds: baseCycleSeconds,
            speed: scriptSpeed,
            preferredMinEdge: 0.55,
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: beatBPM,
            beatBarMode: beatBarMode
        )
    }

    /// Updates `scriptSpeed` and synchronizes metadata timings against real Timeline `clipDuration`.
    public mutating func updateTimingForSpeed(
        _ speed: Double,
        clipDuration: Double,
        baseCycleSeconds: Double = 1.0
    ) {
        self.scriptSpeed = max(0.25, min(4.0, speed))
        let resolved = resolvedPhases(forClipDuration: clipDuration, baseCycleSeconds: baseCycleSeconds)
        self.scriptInDuration = (resolved.inDuration * 100.0).rounded() / 100.0
        self.scriptOutDuration = (resolved.outDuration * 100.0).rounded() / 100.0
        self.scriptLoopDuration = (resolved.loopDuration * 100.0).rounded() / 100.0
        self.scriptDuration = (resolved.totalDuration * 100.0).rounded() / 100.0
    }

    public var isDefault: Bool {
        graph == nil && !hasScriptAnimation && rgbSplitIntensity == 0.0 && lightSweepIntensity == 0.0 && !isMaskEnabled
    }

    private static func migrateLegacyScriptId(from legacy: KeyedDecodingContainer<LegacyCodingKeys>?) -> String {
        guard let legacy else { return "none" }
        let comboRaw = (try? legacy.decodeIfPresent(String.self, forKey: .comboType)) ?? ""
        if comboRaw == "Karaoke Box" || comboRaw == "Karaoke Glow" { return "typewriter_staccato" }

        let inRaw = ((try? legacy.decodeIfPresent(String.self, forKey: .inType)) ?? "").lowercased()
        let loopRaw = ((try? legacy.decodeIfPresent(String.self, forKey: .loopType)) ?? "").lowercased()
        let outRaw = ((try? legacy.decodeIfPresent(String.self, forKey: .outType)) ?? "").lowercased()

        if inRaw.contains("typewriter") { return "typewriter_cursor" }
        if inRaw.contains("kinetic") || inRaw.contains("drop") { return "kinetic_drop_glow" }
        if let legacySlide = migrateLegacySlidePair(inRaw: inRaw, outRaw: outRaw) { return legacySlide }
        if inRaw.contains("zoom") { return "pop_elastic_bounce" }
        if inRaw.contains("fade") { return "fade_soft_glow" }

        if loopRaw.contains("wave") || loopRaw.contains("float") { return "title_wave_float" }
        if loopRaw.contains("flicker") { return "neon_cyber_shift" }
        if loopRaw.contains("breathe") { return "soft_breathe_cascade" }
        if loopRaw.contains("pulse") || loopRaw.contains("bounce") { return "liquid_wave_pulse" }

        if outRaw.contains("fade") { return "fade_soft_glow" }
        if outRaw.contains("zoom") { return "pop_elastic_bounce" }
        if outRaw.contains("drop") { return "kinetic_drop_glow" }
        if outRaw.contains("tv") { return "glitch_rgb_pop" }
        return "none"
    }

    private static func migrateLegacySlidePair(inRaw: String, outRaw: String) -> String? {
        let inDir = extractLegacySlideDirection(from: inRaw)
        let outDir = extractLegacySlideDirection(from: outRaw)
        guard inDir != nil || outDir != nil else { return nil }
        let resolvedIn = inDir ?? outDir ?? .right
        let resolvedOut = outDir ?? resolvedIn
        switch (resolvedIn, resolvedOut) {
        case (.up, .up): return "slide_up_up"
        case (.down, .down): return "slide_down_down"
        case (.up, .down): return "slide_up_down"
        case (.down, .up): return "slide_down_up"
        case (.left, .left): return "slide_left_left"
        case (.left, .right): return "slide_left_right"
        case (.right, .left): return "slide_right_left"
        case (.right, .right): return "slide_right_right"
        default: return "slide_\(resolvedIn.rawValue)_\(resolvedIn.rawValue)"
        }
    }

    private static func extractLegacySlideDirection(from raw: String) -> TextSlideDirection? {
        guard raw.contains("slide") || raw.contains("whip") else { return nil }
        if raw.contains("up") { return .up }
        if raw.contains("down") { return .down }
        if raw.contains("left") { return .left }
        return .right
    }
}
