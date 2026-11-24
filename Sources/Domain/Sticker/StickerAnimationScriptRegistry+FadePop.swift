import Foundation

extension StickerAnimationScriptRegistry {
    static var fadeAndPopScripts: [any StickerAnimationScript] {
        [
            PureFadeStickerScript(),
            SoftFocusBlurStickerScript(),
            DreamFloatStickerScript(),
            NeonFlickerStickerScript(),
            ElasticPopStickerScript(),
            SquashStretchPopStickerScript(),
            ZoomSlamPopStickerScript(),
            CardFlipPopStickerScript()
        ]
    }
}

private struct PureFadeStickerScript: StickerAnimationScript {
    let id = "fade_pure"
    let name = "Pure Fade"
    let category: StickerAnimationCategory = .fade
    let description = "Smooth dissolve in, gentle ambient shimmer, and soft fade out."
    let previewSymbolName = "circle.lefthalf.filled"
    let baseCycleSeconds = 1.3

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutCubic(p)
            return StickerAnimationDelta(scaleX: 0.94 + 0.06 * e, scaleY: 0.94 + 0.06 * e, opacity: e)
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.75, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let breath = 0.5 * (1.0 - cos(ang))
            return StickerAnimationDelta(scaleX: 1.0 + 0.03 * breath, scaleY: 1.0 + 0.03 * breath, opacity: 1.0 - 0.14 * breath, glowIntensity: 0.25 * breath)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: 1.0 - 0.06 * e, scaleY: 1.0 - 0.06 * e, opacity: 1.0 - e)
        }
    }
}

private struct SoftFocusBlurStickerScript: StickerAnimationScript {
    let id = "fade_blur_focus"
    let name = "Soft Focus Blur"
    let category: StickerAnimationCategory = .fade
    let description = "Crystallizes from lens blur into crisp focus with subtle glow pulse."
    let previewSymbolName = "camera.aperture"
    let baseCycleSeconds = 1.4

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutQuint(p)
            return StickerAnimationDelta(scaleX: 1.18 - 0.18 * e, scaleY: 1.18 - 0.18 * e, opacity: e, blurRadius: 18.0 * (1.0 - e))
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.7, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let wave = 0.5 * (1.0 - cos(ang))
            return StickerAnimationDelta(scaleX: 1.0 + 0.025 * wave, scaleY: 1.0 + 0.025 * wave, glowIntensity: 0.35 * wave, blurRadius: 1.5 * wave)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: 1.0 + 0.16 * e, scaleY: 1.0 + 0.16 * e, opacity: 1.0 - e, blurRadius: 18.0 * e)
        }
    }
}

private struct DreamFloatStickerScript: StickerAnimationScript {
    let id = "fade_dream_float"
    let name = "Dream Float"
    let category: StickerAnimationCategory = .fade
    let description = "Floats effortlessly into view, bobs weightlessly, and drifts skyward."
    let previewSymbolName = "cloud.fill"
    let baseCycleSeconds = 1.15

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutCubic(p)
            return StickerAnimationDelta(offsetY: 0.28 * (1.0 - e), scaleX: 0.92 + 0.08 * e, scaleY: 0.92 + 0.08 * e, opacity: e)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.85, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            let dy = -0.09 * sin(ang) * env
            let rot = 3.0 * sin(ang) * env
            return StickerAnimationDelta(offsetY: dy, rotation: rot, glowIntensity: 0.2 * (0.5 * (1.0 - cos(ang))))
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetY: -0.28 * e, scaleX: 1.0 - 0.08 * e, scaleY: 1.0 - 0.08 * e, opacity: 1.0 - e)
        }
    }
}

private struct NeonFlickerStickerScript: StickerAnimationScript {
    let id = "fade_flicker_neon"
    let name = "Neon Flicker"
    let category: StickerAnimationCategory = .fade
    let description = "Electric sign ignition flicker, glowing pulse, and power-down buzz."
    let previewSymbolName = "lightbulb.max.fill"
    let baseCycleSeconds = 0.7

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let c = StickerAnimationCurves.clamp01(p)
            let pulse = c < 0.72 ? (0.35 + 0.65 * abs(sin(c * .pi * 4.5))) * c : StickerAnimationCurves.easeOutCubic((c - 0.72) / 0.28) * 0.25 + 0.75
            let op = c >= 0.98 ? 1.0 : pulse
            return StickerAnimationDelta(opacity: op, glowIntensity: 0.95 * (1.0 - c) + 0.35 * c)
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.5, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let buzz = max(0.0, sin(ang * 2.0)) * 0.22
            let glow = 0.25 + 0.55 * (0.5 * (1.0 - cos(ang)))
            return StickerAnimationDelta(opacity: 1.0 - buzz, glowIntensity: glow)
        case .outro(let p):
            let c = StickerAnimationCurves.clamp01(p)
            let flicker = c > 0.85 ? 0.0 : (1.0 - c) * (0.5 + 0.5 * cos(c * .pi * 6.0))
            return StickerAnimationDelta(opacity: flicker, glowIntensity: 0.6 * (1.0 - c))
        }
    }
}

private struct ElasticPopStickerScript: StickerAnimationScript {
    let id = "pop_elastic"
    let name = "Elastic Pop"
    let category: StickerAnimationCategory = .pop
    let description = "Crisp spring pop in, buoyant rhythmic breathing, and snappy exit."
    let previewSymbolName = "sparkles"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let s = StickerAnimationCurves.easeOutElastic(p)
            let op = StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.2))
            return StickerAnimationDelta(scaleX: max(0.01, s), scaleY: max(0.01, s), opacity: op)
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.0, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let s = 1.0 + 0.08 * (0.5 * (1.0 - cos(ang)))
            return StickerAnimationDelta(scaleX: s, scaleY: s)
        case .outro(let p):
            let s = max(0.01, 1.0 - StickerAnimationCurves.easeInBack(p))
            return StickerAnimationDelta(scaleX: s, scaleY: s, opacity: 1.0 - StickerAnimationCurves.easeInCubic(p))
        }
    }
}

private struct SquashStretchPopStickerScript: StickerAnimationScript {
    let id = "pop_squash"
    let name = "Squash & Stretch"
    let category: StickerAnimationCategory = .pop
    let description = "Bottom-anchored cartoon pop with volume-preserving squash & stretch."
    let previewSymbolName = "arrow.up.and.down.circle.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let u = StickerAnimationCurves.clamp01(p)
            let stretch = sin(u * .pi * 2.0) * (1.0 - u) * 0.28
            let base = StickerAnimationCurves.easeOutBack(u, overshoot: 1.4)
            return StickerAnimationDelta(scaleX: max(0.05, base - stretch), scaleY: max(0.05, base + stretch), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, u * 2.5)), anchorPoint: .bottom)
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.15, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let pulse = sin(ang) * 0.10
            return StickerAnimationDelta(scaleX: 1.0 - pulse, scaleY: 1.0 + pulse, anchorPoint: .bottom)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            let squashX = 1.0 + 0.30 * sin(p * .pi * 0.7) * (1.0 - e)
            let squashY = max(0.01, 1.0 - e)
            return StickerAnimationDelta(scaleX: max(0.01, squashX * (1.0 - e)), scaleY: squashY, opacity: 1.0 - e, anchorPoint: .bottom)
        }
    }
}

private struct ZoomSlamPopStickerScript: StickerAnimationScript {
    let id = "pop_zoom_slam"
    let name = "Zoom Slam"
    let category: StickerAnimationCategory = .pop
    let description = "Drops from foreground with lens blur impact and rhythmic bass pulse."
    let previewSymbolName = "bolt.circle.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutQuint(p)
            let impactBounce = sin(p * .pi * 2.5) * (1.0 - p) * 0.08
            return StickerAnimationDelta(scaleX: 1.85 - 0.85 * e + impactBounce, scaleY: 1.85 - 0.85 * e + impactBounce, opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.4)), blurRadius: 16.0 * (1.0 - e))
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.0, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let kick = pow(0.5 * (1.0 - cos(ang)), 2.0)
            return StickerAnimationDelta(scaleX: 1.0 + 0.09 * kick, scaleY: 1.0 + 0.09 * kick, glowIntensity: 0.45 * kick)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: 1.0 + 0.85 * e, scaleY: 1.0 + 0.85 * e, opacity: 1.0 - e, blurRadius: 14.0 * e)
        }
    }
}

private struct CardFlipPopStickerScript: StickerAnimationScript {
    let id = "pop_flip_card"
    let name = "Card Flip"
    let category: StickerAnimationCategory = .pop
    let description = "Unfolds horizontally like a 3D card with subtle tilt shimmer."
    let previewSymbolName = "rectangle.portrait.rotate"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutBack(p, overshoot: 1.2)
            let op = StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.4))
            return StickerAnimationDelta(scaleX: max(0.02, e), scaleY: 0.94 + 0.06 * StickerAnimationCurves.clamp01(e), skewY: 0.18 * (1.0 - StickerAnimationCurves.clamp01(p)), opacity: op)
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.9, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let s = sin(ang)
            return StickerAnimationDelta(scaleX: 1.0 - 0.10 * (1.0 - cos(ang)), skewY: 0.08 * s, glowIntensity: 0.25 * abs(s))
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: max(0.01, 1.0 - e), skewY: -0.18 * e, opacity: 1.0 - e)
        }
    }
}
