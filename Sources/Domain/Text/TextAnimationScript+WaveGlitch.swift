import Foundation

// MARK: - Wave 3: Ripple Drop Wave (Sóng tâm chấn giọt nước lan tỏa từ giữa dòng)
public struct RippleDropWaveScript: TextAnimationScript {
    public let id = "ripple_drop_wave"
    public let displayName = "Ripple Drop"
    public let description = "Sóng đồng tâm lan tỏa từ ký tự chính giữa ra hai biên như giọt nước chạm mặt hồ"
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

        switch phase {
        case .intro(let progress):
            let delay = normDist * 0.44
            let p = min(1.0, max(0.0, (progress - delay) / 0.56))
            guard p > 0.0 else { return TextUnitDelta(offsetY: -0.75 * em, scaleX: 0.2, scaleY: 0.2, opacity: 0.0) }
            let decay = exp(-p * 3.8)
            let ripple = decay * sin(p * .pi * 3.5)
            return TextUnitDelta(
                offsetY: -ripple * (0.52 * em),
                scaleX: 1.0 - ripple * 0.18,
                scaleY: 1.0 + ripple * 0.28,
                rotation: ripple * 12.0 * signDir,
                opacity: min(1.0, p * 4.0),
                trackingEmDelta: max(0.0, ripple) * 0.12
            )
        case .loop(_, let cycleProgress):
            let phaseArg = cycleProgress * .pi * 2.0 - distFromCenter * 0.72
            let wave = sin(phaseArg)
            let crest = max(0.0, wave)
            return TextUnitDelta(
                offsetY: -wave * (0.30 * em),
                scaleX: 1.0 - wave * 0.08,
                scaleY: 1.0 + wave * 0.14,
                rotation: cos(phaseArg) * 7.5 * signDir,
                opacity: 1.0,
                trackingEmDelta: crest * 0.06
            )
        case .outro(let progress):
            let delay = (1.0 - normDist) * 0.36
            let p = min(1.0, max(0.0, (progress - delay) / 0.64))
            let ease = p * p
            return TextUnitDelta(
                offsetY: ease * (0.65 * em),
                scaleX: max(0.1, 1.0 - ease * 0.75),
                scaleY: max(0.1, 1.0 - ease * 0.75),
                opacity: 1.0 - ease
            )
        }
    }
}

// MARK: - Wave 4: DNA Helix Twist (Sóng xoắn kép 3D ngược pha đan xen)
public struct DNAHelixTwistScript: TextAnimationScript {
    public let id = "dna_helix_twist"
    public let displayName = "DNA Helix Wave"
    public let description = "Hai chuỗi sóng sin ngược pha đan xoắn không gian 3D kèm phóng to chiều sâu"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let strandSign = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.40 / Double(total))) / 0.60))
            guard p > 0.0 else { return TextUnitDelta(scaleX: 0.1, scaleY: 0.1, opacity: 0.0) }
            let ease = 1.0 - pow(1.0 - p, 3.0)
            let theta = (1.0 - ease) * .pi * 1.5 + Double(unitIndex) * 0.55
            let depth = cos(theta) * strandSign
            return TextUnitDelta(
                offsetY: sin(theta) * strandSign * (0.48 * em) * (1.0 - ease * 0.35),
                scaleX: max(0.25, ease * (1.0 + depth * 0.22 * (1.0 - ease * 0.5))),
                scaleY: max(0.25, ease * (1.0 + depth * 0.22 * (1.0 - ease * 0.5))),
                rotation: cos(theta) * strandSign * 14.0 * (1.0 - ease * 0.4),
                opacity: min(1.0, p * 3.5)
            )
        case .loop(_, let cycleProgress):
            let theta = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.58
            let waveY = sin(theta) * strandSign * (0.32 * em)
            let depthZ = cos(theta) * strandSign
            let depthScale = 1.0 + depthZ * 0.18
            return TextUnitDelta(
                offsetY: waveY,
                scaleX: depthScale,
                scaleY: depthScale,
                rotation: depthZ * 8.5,
                opacity: 0.82 + 0.18 * ((depthZ + 1.0) * 0.5)
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let ease = p * p
            let theta = ease * .pi * 1.5 + Double(unitIndex) * 0.55
            return TextUnitDelta(
                offsetY: sin(theta) * strandSign * (0.60 * em) * ease,
                scaleX: max(0.08, 1.0 - ease * 0.90),
                scaleY: max(0.08, 1.0 - ease * 0.90),
                rotation: strandSign * ease * 35.0,
                opacity: 1.0 - ease
            )
        }
    }
}

// MARK: - Wave 5: Jelly Trampoline Wave (Sóng nhún bạt lò xo neo đáy Squash & Stretch)
public struct JellyTrampolineWaveScript: TextAnimationScript {
    public let id = "jelly_trampoline_wave"
    public let displayName = "Jelly Trampoline"
    public let description = "Sóng nhún đàn hồi neo chân chữ với hiệu ứng vươn cao ở đỉnh sóng và nén dẹt ở chân sóng"
    public let category = TextAnimationCategory.wave
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let centerIdx = Double(max(1, unitTotal - 1)) * 0.5
        let charEmX = (Double(unitIndex) - centerIdx) * 0.62
        let k = 0.88
        let amp = 0.34
        switch phase {
        case .intro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.42 / Double(total))) / 0.58))
            guard p > 0.0 else { return TextUnitDelta(scaleX: 1.35, scaleY: 0.08, opacity: 0.0, anchorOverride: .bottom) }
            let decay = exp(-p * 3.8)
            let bounce = decay * sin(p * .pi * 3.2)
            return TextUnitDelta(
                offsetY: -max(0.0, bounce) * (0.48 * em),
                scaleX: max(0.4, 1.0 - bounce * 0.22),
                scaleY: max(0.1, 1.0 + bounce * 0.36),
                opacity: min(1.0, p * 4.2),
                anchorOverride: .bottom
            )
        case .loop(_, let cycleProgress):
            let phaseRad = cycleProgress * .pi * 2.0
            let theta = -charEmX * k + phaseRad
            let wave = sin(theta)
            let stretch = wave * 0.22
            return TextUnitDelta(
                offsetY: -amp * em * wave,
                scaleX: 1.0 - stretch * 0.55,
                scaleY: 1.0 + stretch,
                rotation: atan(amp * k * cos(theta)) * 180.0 / .pi,
                opacity: 1.0,
                waveAmplitudeEm: amp,
                waveFrequencyEm: -k,
                wavePhaseRadians: phaseRad,
                anchorOverride: .bottom
            )
        case .outro(let progress):
            let total = max(1, unitTotal)
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            let ease = p * p
            return TextUnitDelta(
                scaleX: 1.0 + ease * 0.35,
                scaleY: max(0.06, 1.0 - ease * 0.94),
                opacity: 1.0 - ease,
                anchorOverride: .bottom
            )
        }
    }
}

// MARK: - Glitch 2: Hologram Scan Beam (Quét tia la-ze 3D & Bóng ma Sci-Fi)
public struct HologramScanBeamScript: TextAnimationScript {
    public let id = "hologram_scan_beam"
    public let displayName = "Hologram Scan"
    public let description = "Quét mở tia Hologram từ chân lên đỉnh kèm bóng mờ chuyển động dọc và tách màu quang học"
    public let category = TextAnimationCategory.glitch
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let total = max(1, unitTotal)
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.44 / Double(total))) / 0.56))
            guard p > 0.0 else { return TextUnitDelta(opacity: 0.0, clipRevealY: 0.0) }
            let ease = 1.0 - pow(1.0 - p, 2.4)
            let flicker = p < 0.75 ? (0.72 + 0.28 * abs(sin(p * 26.0 + Double(unitIndex)))) : 1.0
            return TextUnitDelta(
                scaleX: 0.92 + 0.08 * ease,
                scaleY: 1.12 - 0.12 * ease,
                opacity: flicker,
                clipRevealY: ease,
                echoCount: p < 0.85 ? 2 : 0,
                echoOffsetYEm: -(1.0 - ease) * 0.24,
                glitchIntensity: (1.0 - ease) * 65.0
            )
        case .loop(let time, let cycleProgress):
            let pulse = sin(cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.45)
            let microGlitch = sin(floor(time * 16.0) * 2.1 + Double(unitIndex)) > 0.84
            return TextUnitDelta(
                skewX: microGlitch ? 12.0 : 0.0,
                opacity: microGlitch ? 0.78 : 1.0,
                clipRevealY: 1.0,
                echoCount: pulse > 0.65 ? 1 : 0,
                echoOffsetYEm: -0.12,
                glitchIntensity: microGlitch ? 45.0 : 0.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, (progress - Double(unitIndex) * (0.36 / Double(total))) / 0.64))
            return TextUnitDelta(
                scaleY: 1.0 + p * 0.25,
                opacity: 1.0 - p,
                clipRevealY: max(0.0, 1.0 - p),
                echoCount: 2,
                echoOffsetYEm: -p * 0.26,
                glitchIntensity: p * 75.0
            )
        }
    }
}

// MARK: - Glitch 3: VHS Tracking Drift (Trôi băng từ VHS & Nhiễu sóng ngang)
public struct VHSTrackingDriftScript: TextAnimationScript {
    public let id = "vhs_tracking_drift"
    public let displayName = "VHS Drift"
    public let description = "Trôi lệch ngang kiểu băng từ VHS cổ điển kèm nghiêng lát cắt và bóng ma đuổi ngang"
    public let category = TextAnimationCategory.glitch
    public let scope = TextAnimationScope.perWord

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        let dir = unitIndex.isMultiple(of: 2) ? 1.0 : -1.0
        switch phase {
        case .intro(let progress):
            let p = min(1.0, max(0.0, progress))
            let stepP = floor(p * 12.0) / 12.0
            let env = pow(1.0 - p, 1.8)
            let waveDrift = sin(stepP * 22.0 + Double(unitIndex) * 1.9) * env
            return TextUnitDelta(
                offsetX: waveDrift * (0.95 * em) * dir,
                skewX: waveDrift * 32.0,
                opacity: min(1.0, p * 3.0),
                echoCount: env > 0.15 ? 2 : 0,
                echoOffsetXEm: -waveDrift * 0.28,
                glitchIntensity: env * 80.0
            )
        case .loop(let time, _):
            let stepT = floor(time * 12.0)
            let burst = sin(stepT * 1.3 + Double(unitIndex) * 2.1)
            guard burst > 0.68 else { return TextUnitDelta(opacity: 1.0) }
            let shift = cos(stepT * 2.7) * dir
            return TextUnitDelta(
                offsetX: shift * (0.22 * em),
                skewX: shift * 22.0,
                opacity: 0.90,
                echoCount: 1,
                echoOffsetXEm: -shift * 0.20,
                glitchIntensity: 55.0
            )
        case .outro(let progress):
            let p = min(1.0, max(0.0, progress))
            let stepP = floor(p * 10.0) / 10.0
            return TextUnitDelta(
                offsetX: stepP * (1.25 * em) * dir,
                skewX: dir * stepP * 34.0,
                opacity: 1.0 - p,
                echoCount: 2,
                echoOffsetXEm: -dir * stepP * 0.30,
                glitchIntensity: p * 88.0
            )
        }
    }
}

