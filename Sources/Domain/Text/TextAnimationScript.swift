import Foundation

/// Nhóm chuyển động của kịch bản hoạt ảnh chữ theo cơ chế động lực học (Motion Mechanics).
public enum TextAnimationCategory: String, CaseIterable, Codable, Sendable, Equatable {
    case fade = "Fade"
    case slide = "Slide"
    case pop = "Pop"
    case wave = "Wave"
    case glitch = "Glitch"
    case typewriter = "Typewriter"
    case threeD = "3D"
    case lightFX = "Light FX"

    // Legacy static aliases preserving backward compatibility
    public static let title: Self = .wave, sub: Self = .slide, music: Self = .wave
    public static let kinetic: Self = .pop, cinematic: Self = .slide, editorial: Self = .typewriter

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .fade: "sun.max"; case .slide: "arrow.right.to.line"; case .pop: "bolt.circle.fill"
        case .wave: "water.waves"; case .glitch: "sparkles.tv"; case .typewriter: "character.cursor.ibeam"
        case .threeD: "cube.transparent"; case .lightFX: "sparkles"
        }
    }
}

public typealias TextAnimationTag = TextAnimationCategory

/// Trạng thái vi phân (Delta) của một đơn vị văn bản (Ký tự, Từ, hoặc Toàn dòng) tại một khung hình.
/// Cho phép kịch bản hoạt ảnh can thiệp sâu vào Transform, Wave, Clip Mask, Hinge Pivot, Echo và Optical Effects.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public struct TextUnitDelta: Sendable, Equatable {
    // MARK: - 1. Transform & Cursor Delta (Pure Kinematics)
    public var offsetX: Double
    public var offsetY: Double
    public var canvasOffsetXRatio: Double
    public var canvasOffsetYRatio: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotation: Double
    public var skewX: Double
    public var skewY: Double
    public var opacity: Double
    public var trailingCursorOpacity: Double

    // MARK: - 1b. Continuous Spatial Wave Path (Evaluated at exact CTLine glyph X)
    public var waveAmplitudeEm: Double
    public var waveFrequencyEm: Double
    public var wavePhaseRadians: Double

    // MARK: - 1c. Advanced Rendering Primitives (Clip Mask, Tracking, Hinge Pivot, Echo Trail)
    public var clipRevealX: Double
    public var clipRevealY: Double
    public var trackingEmDelta: Double
    public var anchorOverride: TextAnchorPoint?
    public var echoCount: Int
    public var echoOffsetXEm: Double
    public var echoOffsetYEm: Double

    // MARK: - 2. Relative Optical Effects Delta (Preserves User Fill & Stroke 100%)
    public var glowIntensityDelta: Double
    public var shadowDistanceDelta: Double
    public var blurRadius: Double
    public var glitchIntensity: Double
    public var noiseIntensity: Double

    // MARK: - 3. GPU Shader Channels (TextShaderFilterEngine)
    public var perspectiveX: Double
    public var perspectiveY: Double
    public var motionBlurRadius: Double
    public var motionBlurAngle: Double
    public var lightSweepPhase: Double
    public var liquidWavePhase: Double
    public var glitchSliceIntensity: Double
    public var pixelateScale: Double
    public var hueAngle: Double

    public init(
        offsetX: Double = 0.0, offsetY: Double = 0.0,
        canvasOffsetXRatio: Double = 0.0, canvasOffsetYRatio: Double = 0.0,
        scaleX: Double = 1.0, scaleY: Double = 1.0,
        rotation: Double = 0.0, skewX: Double = 0.0, skewY: Double = 0.0,
        opacity: Double = 1.0, trailingCursorOpacity: Double = 0.0,
        waveAmplitudeEm: Double = 0.0, waveFrequencyEm: Double = 0.0, wavePhaseRadians: Double = 0.0,
        clipRevealX: Double = 1.0, clipRevealY: Double = 1.0,
        trackingEmDelta: Double = 0.0, anchorOverride: TextAnchorPoint? = nil,
        echoCount: Int = 0, echoOffsetXEm: Double = 0.0, echoOffsetYEm: Double = 0.0,
        glowIntensityDelta: Double = 0.0, shadowDistanceDelta: Double = 0.0,
        blurRadius: Double = 0.0, glitchIntensity: Double = 0.0, noiseIntensity: Double = 0.0,
        perspectiveX: Double = 0.0, perspectiveY: Double = 0.0,
        motionBlurRadius: Double = 0.0, motionBlurAngle: Double = 0.0,
        lightSweepPhase: Double = -1.0, liquidWavePhase: Double = -1.0,
        glitchSliceIntensity: Double = 0.0, pixelateScale: Double = 0.0, hueAngle: Double = 0.0
    ) {
        self.offsetX = offsetX; self.offsetY = offsetY
        self.canvasOffsetXRatio = canvasOffsetXRatio; self.canvasOffsetYRatio = canvasOffsetYRatio
        self.scaleX = scaleX; self.scaleY = scaleY
        self.rotation = rotation; self.skewX = skewX; self.skewY = skewY
        self.opacity = max(0.0, min(1.0, opacity))
        self.trailingCursorOpacity = max(0.0, min(1.0, trailingCursorOpacity))
        self.waveAmplitudeEm = waveAmplitudeEm; self.waveFrequencyEm = waveFrequencyEm; self.wavePhaseRadians = wavePhaseRadians
        self.clipRevealX = max(0.0, min(1.0, clipRevealX)); self.clipRevealY = max(0.0, min(1.0, clipRevealY))
        self.trackingEmDelta = trackingEmDelta; self.anchorOverride = anchorOverride
        self.echoCount = max(0, min(3, echoCount)); self.echoOffsetXEm = echoOffsetXEm; self.echoOffsetYEm = echoOffsetYEm
        self.glowIntensityDelta = glowIntensityDelta; self.shadowDistanceDelta = shadowDistanceDelta
        self.blurRadius = max(0.0, blurRadius)
        self.glitchIntensity = max(0.0, min(100.0, glitchIntensity)); self.noiseIntensity = max(0.0, min(100.0, noiseIntensity))
        self.perspectiveX = max(-0.85, min(0.85, perspectiveX)); self.perspectiveY = max(-0.85, min(0.85, perspectiveY))
        self.motionBlurRadius = max(0.0, min(45.0, motionBlurRadius)); self.motionBlurAngle = motionBlurAngle
        self.lightSweepPhase = lightSweepPhase; self.liquidWavePhase = liquidWavePhase
        self.glitchSliceIntensity = max(0.0, glitchSliceIntensity)
        self.pixelateScale = max(0.0, pixelateScale); self.hueAngle = hueAngle
    }

    public static let identity = TextUnitDelta()

    /// Smooth linear interpolation between two deltas to guarantee exact phase-boundary continuity.
    public static func lerp(_ a: TextUnitDelta, _ b: TextUnitDelta, t: Double) -> TextUnitDelta {
        let k = max(0.0, min(1.0, t))
        let inv = 1.0 - k
        return TextUnitDelta(
            offsetX: inv * a.offsetX + k * b.offsetX,
            offsetY: inv * a.offsetY + k * b.offsetY,
            canvasOffsetXRatio: inv * a.canvasOffsetXRatio + k * b.canvasOffsetXRatio,
            canvasOffsetYRatio: inv * a.canvasOffsetYRatio + k * b.canvasOffsetYRatio,
            scaleX: inv * a.scaleX + k * b.scaleX,
            scaleY: inv * a.scaleY + k * b.scaleY,
            rotation: inv * a.rotation + k * b.rotation,
            skewX: inv * a.skewX + k * b.skewX,
            skewY: inv * a.skewY + k * b.skewY,
            opacity: inv * a.opacity + k * b.opacity,
            trailingCursorOpacity: inv * a.trailingCursorOpacity + k * b.trailingCursorOpacity,
            waveAmplitudeEm: inv * a.waveAmplitudeEm + k * b.waveAmplitudeEm,
            waveFrequencyEm: inv * a.waveFrequencyEm + k * b.waveFrequencyEm,
            wavePhaseRadians: inv * a.wavePhaseRadians + k * b.wavePhaseRadians,
            clipRevealX: inv * a.clipRevealX + k * b.clipRevealX,
            clipRevealY: inv * a.clipRevealY + k * b.clipRevealY,
            trackingEmDelta: inv * a.trackingEmDelta + k * b.trackingEmDelta,
            anchorOverride: k > 0.5 ? (b.anchorOverride ?? a.anchorOverride) : (a.anchorOverride ?? b.anchorOverride),
            echoCount: k > 0.5 ? b.echoCount : a.echoCount,
            echoOffsetXEm: inv * a.echoOffsetXEm + k * b.echoOffsetXEm,
            echoOffsetYEm: inv * a.echoOffsetYEm + k * b.echoOffsetYEm,
            glowIntensityDelta: inv * a.glowIntensityDelta + k * b.glowIntensityDelta,
            shadowDistanceDelta: inv * a.shadowDistanceDelta + k * b.shadowDistanceDelta,
            blurRadius: inv * a.blurRadius + k * b.blurRadius,
            glitchIntensity: inv * a.glitchIntensity + k * b.glitchIntensity,
            noiseIntensity: inv * a.noiseIntensity + k * b.noiseIntensity,
            perspectiveX: inv * a.perspectiveX + k * b.perspectiveX,
            perspectiveY: inv * a.perspectiveY + k * b.perspectiveY,
            motionBlurRadius: inv * a.motionBlurRadius + k * b.motionBlurRadius,
            motionBlurAngle: inv * a.motionBlurAngle + k * b.motionBlurAngle,
            lightSweepPhase: (a.lightSweepPhase >= 0 && b.lightSweepPhase >= 0) ? (inv * a.lightSweepPhase + k * b.lightSweepPhase) : (k > 0.5 ? b.lightSweepPhase : a.lightSweepPhase),
            liquidWavePhase: (a.liquidWavePhase >= 0 && b.liquidWavePhase >= 0) ? (inv * a.liquidWavePhase + k * b.liquidWavePhase) : (k > 0.5 ? b.liquidWavePhase : a.liquidWavePhase),
            glitchSliceIntensity: inv * a.glitchSliceIntensity + k * b.glitchSliceIntensity,
            pixelateScale: inv * a.pixelateScale + k * b.pixelateScale,
            hueAngle: inv * a.hueAngle + k * b.hueAngle
        )
    }
}

/// Ba pha diễn hoạt chuyển động toàn vẹn trong 1 Script: Xuất hiện (In) -> Tuần hoàn (Loop) -> Biến mất (Out).
public enum TextScriptPhase: Sendable, Equatable {
    case intro(progress: Double)
    case loop(time: Double, cycleProgress: Double)
    case outro(progress: Double)
}

/// Giao thức kịch bản hoạt ảnh chạy xuyên suốt thời lượng, do Dev lập trình sẵn các phong cách độc lập.
public protocol TextAnimationScript: Sendable {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var category: TextAnimationCategory { get }
    var tag: TextAnimationTag { get }
    var tags: [TextAnimationTag] { get }
    var defaultDuration: Double { get }
    var defaultInDuration: Double { get }
    var defaultLoopDuration: Double { get }
    var defaultOutDuration: Double { get }
    /// Chu kỳ cơ sở của 1 vòng lặp trong pha Loop (luôn là ước số của 1.0s: ví dụ 1.0s, 0.5s, 0.25s).
    var loopCycleDuration: Double { get }
    var scope: TextAnimationScope { get }

    func evaluatePhase(
        base: TextConfiguration,
        phase: TextScriptPhase,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta

    func evaluate(
        base: TextConfiguration,
        localTime: Double,
        duration: Double,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta
}

extension TextAnimationScript {
    public var category: TextAnimationCategory { .title }
    public var tag: TextAnimationTag { category }
    public var tags: [TextAnimationTag] { [tag] }
    public var defaultDuration: Double { 5.0 }
    public var defaultInDuration: Double { 1.0 }
    public var defaultLoopDuration: Double { 3.0 }
    public var defaultOutDuration: Double { 1.0 }
    public var loopCycleDuration: Double { 1.0 }

    /// Số chu kỳ lặp nguyên vẹn trong mỗi 1.0s cơ sở (luôn là số nguyên >= 1 để không bị cắt giữa chu kỳ).
    public var cyclesPerUnitSecond: Int {
        max(1, Int((1.0 / max(0.05, loopCycleDuration)).rounded()))
    }

    public func resolvePhase(
        anim: TextAnimationConfiguration,
        localTime: Double,
        duration: Double
    ) -> TextScriptPhase {
        let phases = anim.resolvedPhases(forClipDuration: duration, baseCycleSeconds: loopCycleDuration)
        let t = max(0.0, min(phases.totalDuration, localTime))
        if phases.inDuration > 0.0001 && t < phases.inDuration {
            return .intro(progress: t / phases.inDuration)
        }
        let loopEnd = phases.inDuration + phases.loopDuration
        if phases.cycleCount > 0 && phases.loopDuration > 0.0001 && t < loopEnd {
            let loopElapsed = max(0.0, t - phases.inDuration)
            let totalCycles = Double(phases.cycleCount) * (loopElapsed / phases.loopDuration)
            let cycleProg = totalCycles - floor(totalCycles)
            return .loop(time: loopElapsed, cycleProgress: max(0.0, min(1.0, cycleProg)))
        }
        let denom = max(0.0001, phases.outDuration)
        return .outro(progress: max(0.0, min(1.0, (t - loopEnd) / denom)))
    }

    public func evaluate(
        base: TextConfiguration,
        localTime: Double,
        duration: Double,
        unitIndex: Int,
        unitTotal: Int
    ) -> TextUnitDelta {
        let phase = resolvePhase(anim: base.animation, localTime: localTime, duration: duration)
        return evaluatePhase(base: base, phase: phase, unitIndex: unitIndex, unitTotal: unitTotal)
    }
}

/// Mẫu hoạt ảnh đầu tiên theo chuẩn Kiểu 2 (Continuous Sine Wave):
/// - Base Timing: Tổng 5s = In (1s) + Loop (3s, chu kỳ 1.0s) + Out (1s).
/// - Ký tự bay từ ngoài vào giữa màn hình (In), đáp khớp 100% vị trí & vận tốc vào sóng nhấp nhô từng ký tự (Loop), rồi phóng ra ngoài (Out).
public struct TitleWaveFloatScript: TextAnimationScript {
    public let id = "title_wave_float"
    public let displayName = "Wave Float"
    public let description = "Text flies into center, ripples in a continuous character wave, then exits smoothly"
    public let category = TextAnimationCategory.wave
    public let loopCycleDuration: Double = 1.0
    public let scope = TextAnimationScope.perCharacter

    public init() {}

    public func evaluatePhase(base: TextConfiguration, phase: TextScriptPhase, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let em = max(16.0, base.fontSize)
        switch phase {
        case .intro(let progress):
            return evaluateIntro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        case .loop(_, let cycleProgress):
            let w = waveState(cycleProgress: cycleProgress, em: em, unitIndex: unitIndex)
            return TextUnitDelta(offsetY: w.y, scaleX: w.sx, scaleY: w.sy, rotation: w.rot, opacity: 1.0, glowIntensityDelta: w.glow)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func waveState(cycleProgress: Double, em: Double, unitIndex: Int) -> (y: Double, sx: Double, sy: Double, rot: Double, glow: Double) {
        let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.55
        let s = sin(angle)
        let c = cos(angle)
        return (-s * (0.20 * em), 1.0 - s * 0.05, 1.0 + s * 0.06, c * 3.5, max(0.0, s) * 18.0)
    }

    private func evaluateIntro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.32
        guard progress > startP else { return TextUnitDelta(opacity: 0.0) }
        let localP = max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let ease = 1.0 - pow(1.0 - localP, 3.0)
        let rem = 1.0 - ease
        let w = waveState(cycleProgress: progress, em: em, unitIndex: unitIndex)
        return TextUnitDelta(
            offsetX: -rem * (1.6 * em), offsetY: rem * (-1.2 * em) + ease * w.y,
            scaleX: rem * 0.55 + ease * w.sx, scaleY: rem * 0.55 + ease * w.sy,
            rotation: -rem * 16.0 + ease * w.rot, opacity: min(1.0, localP * 2.0),
            glowIntensityDelta: ease * w.glow, blurRadius: rem * (0.08 * em)
        )
    }

    private func evaluateOutro(progress: Double, em: Double, unitIndex: Int, unitTotal: Int) -> TextUnitDelta {
        let normIdx = unitTotal > 1 ? Double(unitIndex) / Double(unitTotal - 1) : 0.0
        let startP = normIdx * 0.32
        let localP = progress <= startP ? 0.0 : max(0.0, min(1.0, (progress - startP) / (1.0 - startP)))
        let outEase = pow(localP, 3.0)
        let stay = 1.0 - outEase
        let w = waveState(cycleProgress: progress, em: em, unitIndex: unitIndex)
        return TextUnitDelta(
            offsetX: outEase * (1.6 * em), offsetY: stay * w.y + outEase * (-1.2 * em),
            scaleX: stay * w.sx + outEase * 0.55, scaleY: stay * w.sy + outEase * 0.55,
            rotation: stay * w.rot + outEase * 16.0, opacity: max(0.0, 1.0 - outEase),
            glowIntensityDelta: stay * w.glow, blurRadius: outEase * (0.08 * em)
        )
    }
}

/// Kho kịch bản diễn hoạt đóng gói sẵn chia theo 6 nhóm Motion Mechanics: Fade, Slide, Pop, Wave, Glitch, Typewriter.
public final class TextAnimationScriptRegistry: Sendable {
    public static let shared = TextAnimationScriptRegistry()

    public let scripts: [any TextAnimationScript]
    private let scriptMap: [String: any TextAnimationScript]

    public init() {
        let activeList: [any TextAnimationScript] = [
            // Fade
            SoftGlowFadeScript(), CinematicDissolveScript(), SoftBreatheCascadeScript(),
            BlurFocusDissolveScript(), KaraokeGlowFlowScript(),
            // Slide
            SmoothWordGlideScript(), LineCascadeRiseScript(), TrailerTrackingExpandScript(),
            WhipEchoSlamScript(), AnamorphicSplitRevealScript(), WhipMotionSlideScript(), ZipperCrossSlideScript(),
            // Pop
            ElasticBouncePopScript(), KineticDropGlowScript(), PopUpHinge3DScript(),
            NeonCyberShiftScript(), TornadoSpiralPopScript(),
            ElasticFlip3DScript(), BeatPulseSlamScript(),
            // Wave
            TitleWaveFloatScript(), CascadeWaveFlowScript(), LiquidWavePulseScript(),
            RippleDropWaveScript(), CurvedArcRollerScript(), DNAHelixTwistScript(),
            JellyTrampolineWaveScript(), PendulumHingeSwingScript(),
            FlagFlutterWaveScript(), LiquidMeltRippleScript(),
            // Glitch
            GlitchRGBPopScript(), HologramScanBeamScript(), VHSTrackingDriftScript(),
            QuantumTeleportFlickerScript(), CyberShutterSliceScript(), CRTSliceTearScript(),
            // Typewriter & Karaoke
            TypewriterCursorScript(), WordStaccatoScript(), FlipCounterRollScript(),
            KaraokeBoxPopScript(),
            // Fade additions (Curved/Shutter masks)
            CurtainBaselineRiseScript(), ShutterBlindRevealScript(),
            // 3D & Light FX
            ThreeDTumbleDropScript(), SwingingDoor3DScript(), DepthPerspectiveZoomScript(),
            MetallicLightSweepScript(), PixelizeDissolveScript(), NeonTubeIgnitionScript(), ChromaticVaporScript()
        ]
        self.scripts = activeList

        var map: [String: any TextAnimationScript] = [:]
        for item in activeList { map[item.id] = item }
        map["neon_color_shift"] = map["neon_cyber_shift"]
        map["cyber_glitch_pop"] = map["glitch_rgb_pop"]
        map["kinetic_wave_bounce"] = map["liquid_wave_pulse"]
        map["retro_skew_drift"] = map["curved_arc_roller"]
        map["rainbow_flow"] = map["neon_cyber_shift"]
        map["elastic_drop"] = map["kinetic_drop_glow"]
        map["typewriter_glow"] = map["typewriter_cursor"]
        self.scriptMap = map
    }

    public func script(for id: String) -> (any TextAnimationScript)? { scriptMap[id] }

    public func scripts(in category: TextAnimationCategory?) -> [any TextAnimationScript] {
        guard let category else { return scripts }
        return scripts.filter { $0.tags.contains(category) || $0.category == category }
    }
}
