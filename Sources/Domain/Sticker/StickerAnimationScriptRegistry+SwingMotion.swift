import Foundation

extension StickerAnimationScriptRegistry {
    static var swingAndMotionScripts: [any StickerAnimationScript] {
        [
            PendulumSwingStickerScript(),
            PlayfulWobbleStickerScript(),
            BreezeSwayStickerScript(),
            OrbitSpinStickerScript(),
            SlideUpMotionStickerScript(),
            WhipPanLeftMotionStickerScript(),
            SpeedRushMotionStickerScript(),
            CurtainWipeMotionStickerScript()
        ]
    }
}

private struct PendulumSwingStickerScript: StickerAnimationScript {
    let id = "swing_pendulum"
    let name = "Pendulum"
    let category: StickerAnimationCategory = .swing
    let description = "Hangs from the top edge and swings with smooth harmonic motion."
    let previewSymbolName = "bell.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutElastic(p)
            return StickerAnimationDelta(rotation: -32.0 * (1.0 - e), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.2)), anchorPoint: .top)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.85, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(rotation: 16.0 * sin(ang) * env, anchorPoint: .top)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(rotation: 36.0 * e, opacity: 1.0 - e, anchorPoint: .top)
        }
    }
}

private struct PlayfulWobbleStickerScript: StickerAnimationScript {
    let id = "swing_wobble"
    let name = "Playful Wobble"
    let category: StickerAnimationCategory = .swing
    let description = "Rocks cheerfully side-to-side around its base like a bobblehead."
    let previewSymbolName = "gyroscope"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutBack(p)
            return StickerAnimationDelta(scaleX: max(0.05, e), scaleY: max(0.05, e), rotation: -18.0 * (1.0 - StickerAnimationCurves.clamp01(p)), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.2)), anchorPoint: .bottom)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.15, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            let s = sin(ang) * env
            return StickerAnimationDelta(rotation: 13.0 * s, skewX: 0.08 * s, anchorPoint: .bottom)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: max(0.01, 1.0 - e), scaleY: max(0.01, 1.0 - e), rotation: 18.0 * e, opacity: 1.0 - e, anchorPoint: .bottom)
        }
    }
}

private struct BreezeSwayStickerScript: StickerAnimationScript {
    let id = "swing_sway_breeze"
    let name = "Breeze Sway"
    let category: StickerAnimationCategory = .swing
    let description = "Drifts gracefully like a leaf caught in a steady breeze."
    let previewSymbolName = "leaf.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutCubic(p)
            return StickerAnimationDelta(offsetX: -0.25 * (1.0 - e), rotation: -8.0 * (1.0 - e), skewX: -0.10 * (1.0 - e), opacity: e)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.85, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            let s = sin(ang) * env
            return StickerAnimationDelta(offsetX: 0.07 * s, offsetY: -0.04 * (0.5 * (1.0 - cos(ang))) * env, rotation: 7.5 * s, skewX: 0.09 * s)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetX: 0.25 * e, rotation: 8.0 * e, skewX: 0.10 * e, opacity: 1.0 - e)
        }
    }
}

private struct OrbitSpinStickerScript: StickerAnimationScript {
    let id = "swing_spin_orbit"
    let name = "Orbit Spin"
    let category: StickerAnimationCategory = .swing
    let description = "Spins smoothly 360° in continuous orbit with clean scale-in and exit."
    let previewSymbolName = "arrow.triangle.2.circlepath"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutBack(p, overshoot: 1.2)
            return StickerAnimationDelta(scaleX: max(0.05, e), scaleY: max(0.05, e), rotation: -180.0 * (1.0 - StickerAnimationCurves.easeOutCubic(p)), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.0)))
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.65, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            return StickerAnimationDelta(offsetY: -0.04 * sin(ang), rotation: 360.0 * cycles * u)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: max(0.01, 1.0 - e), scaleY: max(0.01, 1.0 - e), rotation: 180.0 * e, opacity: 1.0 - e)
        }
    }
}

private struct SlideUpMotionStickerScript: StickerAnimationScript {
    let id = "motion_slide_up"
    let name = "Slide Up"
    let category: StickerAnimationCategory = .motion
    let description = "Glides upward with trailing echoes, hovers smoothly, and exits upward."
    let previewSymbolName = "arrow.up.circle.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutQuint(p)
            let trail = (1.0 - e) * 0.14
            return StickerAnimationDelta(offsetY: 0.65 * (1.0 - e), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 1.8)), echoCount: trail > 0.01 ? 2 : 0, echoOffsetY: trail)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.85, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            return StickerAnimationDelta(offsetY: -0.06 * sin(ang) * StickerAnimationCurves.loopEnvelope(u))
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetY: -0.65 * e, opacity: 1.0 - e, echoCount: e > 0.05 ? 2 : 0, echoOffsetY: 0.14 * e)
        }
    }
}

private struct WhipPanLeftMotionStickerScript: StickerAnimationScript {
    let id = "motion_whip_left"
    let name = "Whip Pan"
    let category: StickerAnimationCategory = .motion
    let description = "Whips sideways into frame with skewed ghost trails and dynamic blur."
    let previewSymbolName = "wind"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutQuint(p)
            let vel = 1.0 - e
            return StickerAnimationDelta(offsetX: 0.90 * vel, skewX: -0.28 * vel, opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.0)), echoCount: vel > 0.03 ? 3 : 0, echoOffsetX: 0.09 * vel, blurRadius: 8.0 * vel)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.0, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(offsetX: 0.06 * sin(ang) * env, skewX: 0.04 * cos(ang) * env)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetX: -0.90 * e, skewX: 0.28 * e, opacity: 1.0 - e, echoCount: e > 0.03 ? 3 : 0, echoOffsetX: 0.09 * e, blurRadius: 8.0 * e)
        }
    }
}

private struct SpeedRushMotionStickerScript: StickerAnimationScript {
    let id = "motion_zip_zoom"
    let name = "Speed Rush"
    let category: StickerAnimationCategory = .motion
    let description = "Darts diagonally into view with trailing echoes and sporty lean."
    let previewSymbolName = "hare.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutBack(p, overshoot: 1.15)
            let remain = 1.0 - StickerAnimationCurves.easeOutQuint(p)
            return StickerAnimationDelta(offsetX: -0.75 * remain, offsetY: 0.45 * remain, scaleX: max(0.1, e), scaleY: max(0.1, e), skewX: 0.22 * remain, opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.2)), echoCount: remain > 0.03 ? 2 : 0, echoOffsetX: -0.07 * remain, echoOffsetY: 0.04 * remain)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.15, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(offsetX: 0.05 * sin(ang) * env, offsetY: -0.04 * sin(ang * 2.0) * env, scaleX: 1.0 + 0.04 * (0.5 * (1.0 - cos(ang))), scaleY: 1.0 + 0.04 * (0.5 * (1.0 - cos(ang))))
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetX: 0.75 * e, offsetY: -0.45 * e, skewX: -0.22 * e, opacity: 1.0 - e, echoCount: e > 0.03 ? 2 : 0, echoOffsetX: -0.07 * e, echoOffsetY: 0.04 * e)
        }
    }
}

private struct CurtainWipeMotionStickerScript: StickerAnimationScript {
    let id = "motion_curtain_wipe"
    let name = "Wipe Unveil"
    let category: StickerAnimationCategory = .motion
    let description = "Sweeps cleanly open via crisp mask wipe and luminous accent glow."
    let previewSymbolName = "rectangle.righthalf.inset.filled.arrow.right"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutCubic(p)
            return StickerAnimationDelta(offsetX: -0.10 * (1.0 - e), opacity: min(1.0, p * 3.0), clipRevealX: max(0.02, e), glowIntensity: 0.35 * sin(p * .pi))
        case .loop(let elapsed, let dur, let cyc):
            let (_, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 0.85, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let pulse = 0.5 * (1.0 - cos(ang))
            return StickerAnimationDelta(scaleX: 1.0 + 0.035 * pulse, scaleY: 1.0 + 0.035 * pulse, glowIntensity: 0.45 * pulse)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetX: 0.10 * e, opacity: 1.0 - e, clipRevealX: max(0.02, 1.0 - e))
        }
    }
}
