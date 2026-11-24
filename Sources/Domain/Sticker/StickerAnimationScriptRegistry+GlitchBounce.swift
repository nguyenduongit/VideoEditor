import Foundation

extension StickerAnimationScriptRegistry {
    static var glitchAndBounceScripts: [any StickerAnimationScript] {
        [
            BounceDropStickerScript(),
            RubberJellyBounceStickerScript(),
            HeartbeatBounceStickerScript(),
            SpringRiseBounceStickerScript(),
            RGBSnapGlitchStickerScript(),
            ImpactShakeGlitchStickerScript(),
            CyberDistortionGlitchStickerScript(),
            StutterStepGlitchStickerScript()
        ]
    }
}

private struct BounceDropStickerScript: StickerAnimationScript {
    let id = "bounce_drop"
    let name = "Bounce Drop"
    let category: StickerAnimationCategory = .bounce
    let description = "Drops from above with gravity rebounds and rhythmic ground hops."
    let previewSymbolName = "arrow.down.to.line.compact"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let b = StickerAnimationCurves.easeOutBounce(p)
            return StickerAnimationDelta(offsetY: -0.70 * (1.0 - b), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.5)), anchorPoint: .bottom)
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.1, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let env = StickerAnimationCurves.loopEnvelope(u)
            let hop = abs(sin(ang * 0.5)) * env
            return StickerAnimationDelta(offsetY: -0.14 * hop, scaleX: 1.0 + 0.06 * (1.0 - hop) * env, scaleY: 1.0 - 0.05 * (1.0 - hop) * env, anchorPoint: .bottom)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInBack(p, overshoot: 1.4)
            return StickerAnimationDelta(offsetY: 0.70 * max(0.0, e), opacity: 1.0 - StickerAnimationCurves.easeInCubic(p), anchorPoint: .bottom)
        }
    }
}

private struct RubberJellyBounceStickerScript: StickerAnimationScript {
    let id = "bounce_rubber"
    let name = "Rubber Jelly"
    let category: StickerAnimationCategory = .bounce
    let description = "Elastic jelly jiggle reacting with playful squash-stretch waves."
    let previewSymbolName = "waveform.path"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let u = StickerAnimationCurves.clamp01(p)
            let osc = sin(u * .pi * 3.0) * (1.0 - u) * 0.25
            let base = StickerAnimationCurves.easeOutCubic(u)
            return StickerAnimationDelta(scaleX: max(0.05, base + osc), scaleY: max(0.05, base - osc), opacity: min(1.0, u * 2.5))
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.35, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let jiggle = sin(ang) * StickerAnimationCurves.loopEnvelope(u) * 0.14
            return StickerAnimationDelta(scaleX: 1.0 + jiggle, scaleY: 1.0 - jiggle, skewX: 0.06 * cos(ang) * StickerAnimationCurves.loopEnvelope(u))
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            let jiggle = sin(p * .pi * 2.0) * (1.0 - e) * 0.16
            return StickerAnimationDelta(scaleX: max(0.01, (1.0 - e) + jiggle), scaleY: max(0.01, (1.0 - e) - jiggle), opacity: 1.0 - e)
        }
    }
}

private struct HeartbeatBounceStickerScript: StickerAnimationScript {
    let id = "bounce_heartbeat"
    let name = "Heartbeat Thump"
    let category: StickerAnimationCategory = .bounce
    let description = "Double-lub-dub pulse with radiant glow ideal for reaction stickers."
    let previewSymbolName = "heart.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let s = StickerAnimationCurves.easeOutBack(p, overshoot: 1.8)
            return StickerAnimationDelta(scaleX: max(0.05, s), scaleY: max(0.05, s), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.4)))
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, _) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.0, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let localCycle = (u * cycles).truncatingRemainder(dividingBy: 1.0)
            let lub = max(0.0, sin(localCycle * .pi * 4.0)) * (localCycle < 0.25 ? 1.0 : 0.0)
            let dub = max(0.0, sin((localCycle - 0.24) * .pi * 4.0)) * (localCycle >= 0.24 && localCycle < 0.50 ? 0.72 : 0.0)
            let pulse = max(lub, dub)
            return StickerAnimationDelta(scaleX: 1.0 + 0.16 * pulse, scaleY: 1.0 + 0.16 * pulse, glowIntensity: 0.55 * pulse)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(scaleX: max(0.01, 1.0 - e), scaleY: max(0.01, 1.0 - e), opacity: 1.0 - e)
        }
    }
}

private struct SpringRiseBounceStickerScript: StickerAnimationScript {
    let id = "bounce_spring_up"
    let name = "Spring Rise"
    let category: StickerAnimationCategory = .bounce
    let description = "Launches up from the bottom edge, overshoots, and hops playfully."
    let previewSymbolName = "arrow.up.and.line.horizontal.and.arrow.down"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutElastic(p)
            return StickerAnimationDelta(offsetY: 0.62 * (1.0 - e), opacity: StickerAnimationCurves.easeOutCubic(min(1.0, p * 2.2)))
        case .loop(let elapsed, let dur, let cyc):
            let (u, _, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.05, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let dy = -0.10 * (0.5 * (1.0 - cos(ang))) * StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(offsetY: dy)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(offsetY: 0.62 * e, opacity: 1.0 - e)
        }
    }
}

private struct RGBSnapGlitchStickerScript: StickerAnimationScript {
    let id = "glitch_rgb_snap"
    let name = "RGB Snap"
    let category: StickerAnimationCategory = .glitch
    let description = "Snaps in with chromatic RGB separation and crisp cyber static bursts."
    let previewSymbolName = "bolt.horizontal.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let u = StickerAnimationCurves.clamp01(p)
            let jitter = (1.0 - u) * sin(u * .pi * 8.0) * 0.09
            return StickerAnimationDelta(offsetX: jitter, scaleX: 0.92 + 0.08 * u, scaleY: 0.92 + 0.08 * u, opacity: u > 0.12 ? min(1.0, u * 1.4) : 0.4, glitchIntensity: 1.15 * (1.0 - u))
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, _) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.0, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let cPhase = (u * cycles).truncatingRemainder(dividingBy: 1.0)
            let active = cPhase > 0.72 ? sin((cPhase - 0.72) / 0.28 * .pi) : 0.0
            let dx = active * 0.05 * sin(cPhase * .pi * 12.0)
            return StickerAnimationDelta(offsetX: dx, skewX: active * 0.12, glitchIntensity: active * 0.95)
        case .outro(let p):
            let u = StickerAnimationCurves.clamp01(p)
            return StickerAnimationDelta(offsetX: u * 0.10 * sin(u * .pi * 7.0), opacity: 1.0 - u, glitchIntensity: 1.15 * u)
        }
    }
}

private struct ImpactShakeGlitchStickerScript: StickerAnimationScript {
    let id = "glitch_shake_impact"
    let name = "Impact Shake"
    let category: StickerAnimationCategory = .glitch
    let description = "High-energy tremor shake with echo jitter ideal for action callouts."
    let previewSymbolName = "exclamationmark.triangle.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutCubic(p)
            let kick = sin(p * .pi * 7.0) * (1.0 - e)
            return StickerAnimationDelta(offsetX: 0.09 * kick, rotation: 8.0 * kick, opacity: min(1.0, p * 2.5), echoCount: kick.magnitude > 0.2 ? 2 : 0, echoOffsetX: 0.05 * kick)
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.25, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let cPhase = (u * cycles).truncatingRemainder(dividingBy: 1.0)
            let burst = cPhase < 0.35 ? sin(cPhase / 0.35 * .pi) : 0.0
            let shake = sin(ang * 5.0) * burst * StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(offsetX: 0.06 * shake, offsetY: 0.04 * cos(ang * 4.0) * burst, rotation: 5.5 * shake)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            let kick = sin(p * .pi * 6.0) * e
            return StickerAnimationDelta(offsetX: 0.09 * kick, scaleX: max(0.01, 1.0 - e), scaleY: max(0.01, 1.0 - e), opacity: 1.0 - e)
        }
    }
}

private struct CyberDistortionGlitchStickerScript: StickerAnimationScript {
    let id = "glitch_cyber_wave"
    let name = "Cyber Distortion"
    let category: StickerAnimationCategory = .glitch
    let description = "Digital shear warp accompanied by neon glow and chromatic edges."
    let previewSymbolName = "waveform.badge.magnifyingglass"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let e = StickerAnimationCurves.easeOutQuint(p)
            let shear = (1.0 - e) * 0.45 * cos(p * .pi * 5.0)
            return StickerAnimationDelta(skewX: shear, opacity: min(1.0, p * 2.0), glowIntensity: 0.6 * (1.0 - e), glitchIntensity: 0.85 * (1.0 - e))
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, ang) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.15, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let cPhase = (u * cycles).truncatingRemainder(dividingBy: 1.0)
            let burst = cPhase > 0.60 ? sin((cPhase - 0.60) / 0.40 * .pi) : 0.0
            return StickerAnimationDelta(skewX: 0.16 * sin(ang * 3.0) * burst, glowIntensity: 0.45 * burst, glitchIntensity: 0.70 * burst)
        case .outro(let p):
            let e = StickerAnimationCurves.easeInCubic(p)
            return StickerAnimationDelta(skewX: -0.45 * e, opacity: 1.0 - e, glowIntensity: 0.6 * e, glitchIntensity: 0.85 * e)
        }
    }
}

private struct StutterStepGlitchStickerScript: StickerAnimationScript {
    let id = "glitch_stutter_step"
    let name = "Stutter Frame"
    let category: StickerAnimationCategory = .glitch
    let description = "Retro stop-motion stepped entrance, frame-locked twitch, and exit."
    let previewSymbolName = "square.stack.3d.down.right.fill"

    func evaluatePhase(_ phase: StickerScriptPhase, speed: Double, isBeatSyncEnabled: Bool, beatBPM: Double) -> StickerAnimationDelta {
        switch phase {
        case .intro(let p):
            let s = StickerAnimationCurves.stepped(p, steps: 5.0)
            let e = StickerAnimationCurves.easeOutCubic(s)
            return StickerAnimationDelta(scaleX: max(0.08, e), scaleY: max(0.08, e), rotation: -12.0 * (1.0 - s), opacity: max(0.15, s))
        case .loop(let elapsed, let dur, let cyc):
            let (u, cycles, _) = Self.loopGeometry(elapsed: elapsed, loopDuration: dur, baseCyclesPerSecond: 1.5, speed: speed, isBeatSyncEnabled: isBeatSyncEnabled, beatBPM: beatBPM, resolvedCycles: cyc)
            let stepWave = sin(StickerAnimationCurves.stepped(u * cycles, steps: 8.0 * cycles) * 2.0 * .pi)
            let env = StickerAnimationCurves.loopEnvelope(u)
            return StickerAnimationDelta(scaleX: 1.0 + 0.05 * abs(stepWave) * env, scaleY: 1.0 + 0.05 * abs(stepWave) * env, rotation: 6.5 * stepWave * env)
        case .outro(let p):
            let s = StickerAnimationCurves.stepped(p, steps: 5.0)
            return StickerAnimationDelta(scaleX: max(0.01, 1.0 - s), scaleY: max(0.01, 1.0 - s), rotation: 12.0 * s, opacity: 1.0 - s)
        }
    }
}
