import Foundation

// MARK: - Wave 3: Ripple Drop Wave (Sóng tâm chấn giọt nước lan tỏa từ giữa dòng)
public struct RippleDropWaveScript: TextAnimationScript {
    public let id = "ripple_drop_wave"
    public let displayName = "Ripple Drop"
    public let description = "Concentric ripple expands outward from center like a drop hitting water"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let centerIdx = Double(max(1, unitTotal - 1)) * 0.5
        let distFromCenter = abs(Double(unitIndex) - centerIdx)
        let maxDist = max(1.0, centerIdx)
        let normDist = distFromCenter / maxDist
        let signDir = Double(unitIndex) >= centerIdx ? 1.0 : -1.0

        let loopAt: (Double) -> (y: Double, sx: Double, sy: Double, rot: Double, track: Double) = { prog in
            let phaseArg = prog * .pi * 2.0 - distFromCenter * 0.72, w = sin(phaseArg)
            return (-w * (0.30 * em), 1.0 - w * 0.08, 1.0 + w * 0.14, cos(phaseArg) * 7.5 * signDir, max(0.0, w) * 0.06)
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - normDist * 0.44) / 0.56))
            guard p > 0.0 else { return TextUnitDelta(offsetY: -0.75 * em, scaleX: 0.2, scaleY: 0.2, opacity: 0.0) }
            let decay = exp(-p * 3.8) * (1.0 - p), ripple = decay * sin(p * .pi * 3.5), l = loopAt(progress)
            return TextUnitDelta(
                offsetY: -ripple * (0.52 * em) + p * l.y,
                scaleX: (1.0 - ripple * 0.18) * (1.0 - p) + p * l.sx, scaleY: (1.0 + ripple * 0.28) * (1.0 - p) + p * l.sy,
                rotation: ripple * 12.0 * signDir + p * l.rot, opacity: min(1.0, p * 4.0),
                trackingEmDelta: max(0.0, ripple) * 0.12 + p * l.track
            )
        case .loop(_, let cycleProgress):
            let l = loopAt(cycleProgress)
            return TextUnitDelta(offsetY: l.y, scaleX: l.sx, scaleY: l.sy, rotation: l.rot, opacity: 1.0, trackingEmDelta: l.track)
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - (1.0 - normDist) * 0.36) / 0.64))
            let ease = p * p, stay = 1.0 - ease, l = loopAt(progress)
            return TextUnitDelta(
                offsetY: stay * l.y + ease * (0.65 * em), scaleX: max(0.1, stay * l.sx + ease * 0.25),
                scaleY: max(0.1, stay * l.sy + ease * 0.25), rotation: stay * l.rot, opacity: stay, trackingEmDelta: stay * l.track
            )
        }
    }
}

// MARK: - Wave 4: DNA Helix Twist (Sóng xoắn kép 3D ngược pha đan xen)
public struct DNAHelixTwistScript: TextAnimationScript {
    public let id = "dna_helix_twist"
    public let displayName = "DNA Helix Wave"
    public let description = "Counter-phase double sine helix weaving in 3D space with depth scaling"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let strandSign = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        let total = max(1, unitTotal)
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let theta = prog * .pi * 2.0 - Double(unitIndex) * 0.58
            let waveY = sin(theta) * strandSign * (0.32 * em), depthZ = cos(theta) * strandSign
            return TextUnitDelta(
                offsetY: waveY, scaleX: 1.0 + depthZ * 0.18, scaleY: 1.0 + depthZ * 0.18,
                rotation: depthZ * 8.5, opacity: 0.82 + 0.18 * ((depthZ + 1.0) * 0.5)
            )
        }
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(scaleX: 0.1, scaleY: 0.1, opacity: 0.0)
            } else {
                let ease = 1.0 - pow(1.0 - p, 3.0), theta = (1.0 - ease) * .pi * 1.5 + Double(unitIndex) * 0.55
                let depth = cos(theta) * strandSign, sc = max(0.25, ease * (1.0 + depth * 0.22 * (1.0 - ease * 0.5)))
                raw = TextUnitDelta(
                    offsetY: sin(theta) * strandSign * (0.48 * em) * (1.0 - ease * 0.35),
                    scaleX: sc, scaleY: sc, rotation: cos(theta) * strandSign * 14.0 * (1.0 - ease * 0.4),
                    opacity: min(1.0, p * 3.5)
                )
            }
            guard progress > 0.72 else { return raw }
            let t = (progress - 0.72) / 0.28
            return TextUnitDelta.lerp(raw, loopAt(progress), t: t * t * (3.0 - 2.0 * t))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress)), ease = p * p
            let theta = ease * .pi * 1.5 + Double(unitIndex) * 0.55
            let outDelta = TextUnitDelta(
                offsetY: sin(theta) * strandSign * (0.60 * em) * ease,
                scaleX: max(0.08, 1.0 - ease * 0.90), scaleY: max(0.08, 1.0 - ease * 0.90),
                rotation: strandSign * ease * 35.0, opacity: 1.0 - ease
            )
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: min(1.0, progress / 0.25))
        }
    }
}

// MARK: - Wave 5: Jelly Trampoline Wave (Sóng nhún bạt lò xo neo đáy Squash & Stretch)
public struct JellyTrampolineWaveScript: TextAnimationScript {
    public let id = "jelly_trampoline_wave"
    public let displayName = "Jelly Trampoline"
    public let description = "Bottom-anchored spring bounce stretching tall at peaks and squashing low"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let centerIdx = Double(max(1, unitTotal - 1)) * 0.5
        let charEmX = (Double(unitIndex) - centerIdx) * 0.62
        let k = 0.88, amp = 0.34
        let loopAt: (Double) -> TextUnitDelta = { prog in
            let phaseRad = prog * .pi * 2.0, theta = -charEmX * k + phaseRad
            let wave = sin(theta), stretch = wave * 0.22
            return TextUnitDelta(
                offsetY: -amp * em * wave, scaleX: 1.0 - stretch * 0.55, scaleY: 1.0 + stretch,
                rotation: atan(amp * k * cos(theta)) * 180.0 / .pi, opacity: 1.0,
                waveAmplitudeEm: amp, waveFrequencyEm: -k, wavePhaseRadians: phaseRad, anchorOverride: .bottom
            )
        }
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.42 / Double(total))) / 0.58))
            let raw: TextUnitDelta
            if p <= 0.0 {
                raw = TextUnitDelta(scaleX: 1.35, scaleY: 0.08, opacity: 0.0, anchorOverride: .bottom)
            } else {
                let decay = exp(-p * 3.8), bounce = decay * sin(p * .pi * 3.2)
                raw = TextUnitDelta(
                    offsetY: -max(0.0, bounce) * (0.48 * em), scaleX: max(0.4, 1.0 - bounce * 0.22),
                    scaleY: max(0.1, 1.0 + bounce * 0.36), opacity: min(1.0, p * 4.2), anchorOverride: .bottom
                )
            }
            guard progress > 0.72 else { return raw }
            let t = (progress - 0.72) / 0.28
            return TextUnitDelta.lerp(raw, loopAt(progress), t: t * t * (3.0 - 2.0 * t))
        case .loop(_, let cycleProgress):
            return loopAt(cycleProgress)
        case .outro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            let ease = p * p
            let outDelta = TextUnitDelta(scaleX: 1.0 + ease * 0.35, scaleY: max(0.06, 1.0 - ease * 0.94), opacity: 1.0 - ease, anchorOverride: .bottom)
            return TextUnitDelta.lerp(loopAt(progress), outDelta, t: min(1.0, progress / 0.25))
        }
    }
}

