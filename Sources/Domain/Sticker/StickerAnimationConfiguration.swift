import Foundation

/// Script-Driven continuous `Intro → Loop → Outro` configuration for a Sticker clip.
/// Completely decoupled from `TextAnimationConfiguration` and APNG/GIF `playbackSpeed`.
public struct StickerAnimationConfiguration: Codable, Equatable, Hashable, Sendable {
    public var scriptId: String
    public var scriptDuration: Double
    public var scriptInDuration: Double
    public var scriptLoopDuration: Double
    public var scriptOutDuration: Double
    public var scriptSpeed: Double
    public var scriptIntensity: Double
    public var isBeatSyncEnabled: Bool
    public var beatBPM: Double
    public var beatBarMode: AnimationBeatBarMode

    public init(
        scriptId: String = "",
        scriptDuration: Double = 4.2,
        scriptInDuration: Double = 0.6,
        scriptLoopDuration: Double = 3.0,
        scriptOutDuration: Double = 0.6,
        scriptSpeed: Double = 1.0,
        scriptIntensity: Double = 1.0,
        isBeatSyncEnabled: Bool = false,
        beatBPM: Double = 120.0,
        beatBarMode: AnimationBeatBarMode = .auto
    ) {
        let resolvedId = StickerAnimationScriptRegistry.shared.canonicalScriptId(for: scriptId)
        self.scriptId = resolvedId.isEmpty ? scriptId.trimmingCharacters(in: .whitespacesAndNewlines) : resolvedId
        self.scriptSpeed = max(0.25, min(4.0, scriptSpeed))
        self.scriptIntensity = max(0.1, min(2.0, scriptIntensity))
        self.isBeatSyncEnabled = isBeatSyncEnabled
        self.beatBPM = max(40.0, min(240.0, beatBPM))
        self.beatBarMode = beatBarMode
        self.scriptInDuration = max(0.0, min(5.0, scriptInDuration))
        self.scriptLoopDuration = max(0.0, min(30.0, scriptLoopDuration))
        self.scriptOutDuration = max(0.0, min(5.0, scriptOutDuration))
        let sum = self.scriptInDuration + self.scriptLoopDuration + self.scriptOutDuration
        self.scriptDuration = max(0.2, min(40.0, sum > 0.05 ? sum : scriptDuration))
    }

    private enum CodingKeys: String, CodingKey {
        case scriptId, scriptDuration, scriptInDuration, scriptLoopDuration, scriptOutDuration
        case scriptSpeed, scriptIntensity, isBeatSyncEnabled, beatBPM, beatBarMode
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case loopType, loopSpeed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)

        let rawScriptId = ((try? c.decodeIfPresent(String.self, forKey: .scriptId)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSpeed = (try? c.decodeIfPresent(Double.self, forKey: .scriptSpeed)) ?? 1.0
        let rawIntensity = (try? c.decodeIfPresent(Double.self, forKey: .scriptIntensity)) ?? 1.0
        let rawBeatSync = (try? c.decodeIfPresent(Bool.self, forKey: .isBeatSyncEnabled)) ?? false
        let rawBPM = (try? c.decodeIfPresent(Double.self, forKey: .beatBPM)) ?? 120.0
        let rawBarMode = (try? c.decodeIfPresent(AnimationBeatBarMode.self, forKey: .beatBarMode)) ?? .auto

        if !rawScriptId.isEmpty {
            let inDur = max(0.0, min(5.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptInDuration)) ?? 0.6))
            let loopDur = max(0.0, min(30.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptLoopDuration)) ?? 3.0))
            let outDur = max(0.0, min(5.0, (try? c.decodeIfPresent(Double.self, forKey: .scriptOutDuration)) ?? 0.6))
            let total = (try? c.decodeIfPresent(Double.self, forKey: .scriptDuration)) ?? (inDur + loopDur + outDur)
            self.init(
                scriptId: rawScriptId,
                scriptDuration: total,
                scriptInDuration: inDur,
                scriptLoopDuration: loopDur,
                scriptOutDuration: outDur,
                scriptSpeed: rawSpeed,
                scriptIntensity: rawIntensity,
                isBeatSyncEnabled: rawBeatSync,
                beatBPM: rawBPM,
                beatBarMode: rawBarMode
            )
            return
        }

        let legacyLoop = (try? legacy.decodeIfPresent(String.self, forKey: .loopType)) ?? ""
        let legacySpeed = (try? legacy.decodeIfPresent(Double.self, forKey: .loopSpeed)) ?? 1.0
        let mappedId = StickerAnimationScriptRegistry.shared.canonicalScriptId(for: legacyLoop)
        self.init(scriptId: mappedId)
        if !mappedId.isEmpty {
            applyUnifiedScriptTiming(baseLoopSeconds: 3.0, speed: legacySpeed)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scriptId, forKey: .scriptId)
        try c.encode(scriptDuration, forKey: .scriptDuration)
        try c.encode(scriptInDuration, forKey: .scriptInDuration)
        try c.encode(scriptLoopDuration, forKey: .scriptLoopDuration)
        try c.encode(scriptOutDuration, forKey: .scriptOutDuration)
        try c.encode(scriptSpeed, forKey: .scriptSpeed)
        try c.encode(scriptIntensity, forKey: .scriptIntensity)
        try c.encode(isBeatSyncEnabled, forKey: .isBeatSyncEnabled)
        try c.encode(beatBPM, forKey: .beatBPM)
        try c.encode(beatBarMode, forKey: .beatBarMode)
    }

    public var hasScriptAnimation: Bool {
        !scriptId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isDefault: Bool {
        !hasScriptAnimation
    }

    public var scriptBaseLoopSeconds: Double {
        let raw = scriptLoopDuration * max(0.25, scriptSpeed)
        return (raw * 100.0).rounded() / 100.0
    }

    public mutating func applyUnifiedScriptTiming(
        baseLoopSeconds: Double,
        speed: Double,
        defaultIn: Double = 0.6,
        defaultOut: Double = 0.6
    ) {
        let clampedSpeed = max(0.25, min(4.0, speed))
        let clampedBaseLoop = max(0.5, min(30.0, baseLoopSeconds))
        let effIn = ((max(0.1, defaultIn) / clampedSpeed) * 100.0).rounded() / 100.0
        let effOut = ((max(0.1, defaultOut) / clampedSpeed) * 100.0).rounded() / 100.0
        let effLoop = ((max(0.3, clampedBaseLoop / clampedSpeed)) * 100.0).rounded() / 100.0
        self.scriptSpeed = clampedSpeed
        self.scriptInDuration = effIn
        self.scriptLoopDuration = effLoop
        self.scriptOutDuration = effOut
        self.scriptDuration = ((effIn + effLoop + effOut) * 100.0).rounded() / 100.0
    }

    /// Resolves integer-cycle `Loop` and symmetric remainder `In = Out` directly from actual Timeline clip duration.
    public func resolvedPhases(
        forClipDuration clipDuration: Double,
        baseCycleSeconds: Double = 1.0
    ) -> ResolvedAnimationPhases {
        AnimationPhaseTimingCalculator.calculate(
            clipDuration: clipDuration,
            baseCycleSeconds: baseCycleSeconds,
            speed: scriptSpeed,
            preferredMinEdge: 0.4,
            isBeatSyncEnabled: isBeatSyncEnabled,
            beatBPM: beatBPM,
            beatBarMode: beatBarMode
        )
    }

    /// Backwards-compatible tuple helper forwarding from `resolvedPhases(forClipDuration:)`.
    public func resolvedPhaseDurations(
        forClipDuration clipDuration: Double,
        defaultIn: Double = 0.6,
        defaultOut: Double = 0.6
    ) -> (inDuration: Double, loopDuration: Double, outDuration: Double, totalDuration: Double) {
        let p = resolvedPhases(forClipDuration: clipDuration)
        return (p.inDuration, p.loopDuration, p.outDuration, p.totalDuration)
    }

    /// Updates `scriptSpeed` and synchronizes stored metadata timings to match `clipDuration`.
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
}
