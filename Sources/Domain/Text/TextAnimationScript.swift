import Foundation

/// Nhóm chuyển động của kịch bản hoạt ảnh chữ theo cơ chế động lực học thuần túy (Pure Motion Mechanics).
public enum TextAnimationCategory: String, CaseIterable, Codable, Sendable, Equatable {
    case fade = "Fade"
    case slide = "Slide"
    case pop = "Pop"
    case wave = "Wave"
    case typewriter = "Typewriter"
    case threeD = "3D"

    // Legacy static aliases preserving backward compatibility for motion categories
    public static let title: Self = .wave, sub: Self = .slide, music: Self = .wave
    public static let kinetic: Self = .pop, cinematic: Self = .slide, editorial: Self = .typewriter

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .fade: "sun.max"; case .slide: "arrow.right.to.line"; case .pop: "bolt.circle.fill"
        case .wave: "water.waves"; case .typewriter: "character.cursor.ibeam"; case .threeD: "cube.transparent"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        if let exact = Self(rawValue: raw) {
            self = exact
        } else {
            self = .fade
        }
    }
}

public typealias TextAnimationTag = TextAnimationCategory

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
            return TextUnitDelta(offsetY: w.y, scaleX: w.sx, scaleY: w.sy, rotation: w.rot, opacity: 1.0)
        case .outro(let progress):
            return evaluateOutro(progress: progress, em: em, unitIndex: unitIndex, unitTotal: unitTotal)
        }
    }

    private func waveState(cycleProgress: Double, em: Double, unitIndex: Int) -> (y: Double, sx: Double, sy: Double, rot: Double) {
        let angle = cycleProgress * .pi * 2.0 - Double(unitIndex) * 0.55
        let s = sin(angle)
        let c = cos(angle)
        return (-s * (0.20 * em), 1.0 - s * 0.05, 1.0 + s * 0.06, c * 3.5)
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
            blurRadius: rem * (0.08 * em)
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
            blurRadius: outEase * (0.08 * em)
        )
    }
}

/// Kho kịch bản diễn hoạt thuần chuyển động chia theo 6 nhóm Motion Mechanics: Fade, Slide, Pop, Wave, Typewriter, 3D.
public final class TextAnimationScriptRegistry: Sendable {
    public static let shared = TextAnimationScriptRegistry()

    public let scripts: [any TextAnimationScript]
    private let scriptMap: [String: any TextAnimationScript]

    public init() {
        var activeList: [any TextAnimationScript] = [
            // Fade (7)
            SoftGlowFadeScript(), CinematicDissolveScript(), BlurFocusDissolveScript(),
            CurtainBaselineRiseScript(), DiagonalSlashRevealScript(), PixelizeDissolveScript(),
            CenterSplitRevealScript()
        ]
        // Slide (8 directional variants)
        activeList.append(contentsOf: DirectionalSlideScript.allEightVariants)
        let remainingScripts: [any TextAnimationScript] = [
            // Pop (5)
            ElasticBouncePopScript(), KineticDropGlowScript(), TornadoSpiralPopScript(),
            BeatPulseSlamScript(), KineticCollisionSlamScript(),
            // Wave (5)
            TitleWaveFloatScript(), RippleDropWaveScript(), DNAHelixTwistScript(),
            PendulumHingeSwingScript(), LiquidMeltRippleScript(),
            // Typewriter & Karaoke (5)
            TypewriterCursorScript(), FlipCounterRollScript(), KaraokeGlowFlowScript(),
            CipherMatrixDecodeScript(), NeonStrokeDrawScript(),
            // 3D (4)
            ThreeDTumbleDropScript(), PopUpHinge3DScript(), ElasticFlip3DScript(),
            ThreeDCardCarouselScript()
        ]
        activeList.append(contentsOf: remainingScripts)
        self.scripts = activeList

        var map: [String: any TextAnimationScript] = [:]
        for item in activeList { map[item.id] = item }
        self.scriptMap = map
    }

    public func script(for id: String) -> (any TextAnimationScript)? { scriptMap[id] }

    public func scripts(in category: TextAnimationCategory?) -> [any TextAnimationScript] {
        guard let category else { return scripts }
        return scripts.filter { $0.tags.contains(category) || $0.category == category }
    }
}
