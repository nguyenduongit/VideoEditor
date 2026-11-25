import Foundation
import Domain

/// Evaluates `TextAnimationGraph` using the unified `Intro -> Loop -> Outro` clock and maps channels to `TextUnitDelta`.
enum TextAnimationGraphMapper {
    struct MappedResult {
        let delta: TextUnitDelta
        let parameters: TextAnimationParameterBag
        let linearRevealProgress: Double
    }

    static func evaluate(
        graph: TextAnimationGraph,
        baseConfig: TextConfiguration,
        t: Double,
        totalDuration: Double,
        unitIndex: Int,
        unitCount: Int,
        externalInputs: [String: Double]
    ) -> MappedResult {
        let context = makeContext(
            graph: graph,
            anim: baseConfig.animation,
            t: t,
            totalDuration: totalDuration,
            unitIndex: unitIndex,
            unitCount: unitCount,
            externalInputs: externalInputs
        )
        let parameters = graph.evaluate(in: context)
        let delta = unitDelta(from: parameters)
        let reveal = parameters[TextAnimationChannel.maskRevealLinear] ?? -1.0
        return MappedResult(delta: delta, parameters: parameters, linearRevealProgress: reveal)
    }

    static func makeContext(
        graph: TextAnimationGraph,
        anim: TextAnimationConfiguration,
        t: Double,
        totalDuration: Double,
        unitIndex: Int,
        unitCount: Int,
        externalInputs: [String: Double]
    ) -> TextAnimationGraphContext {
        let phases = anim.resolvedPhases(
            forClipDuration: totalDuration,
            baseCycleSeconds: graph.loopCycleDuration
        )
        let loopEnd = phases.inDuration + phases.loopDuration
        let effectiveCycle = phases.loopDuration > 0.0001
            ? phases.loopDuration / Double(max(1, phases.cycleCount))
            : max(0.05, phases.cycleDuration)
        let rawCycles = (t - phases.inDuration) / max(0.05, effectiveCycle)
        let loopProgress = rawCycles - floor(rawCycles)
        let phase: TextAnimationGraphPhase
        let phaseProgress: Double
        let phaseDuration: Double

        if phases.inDuration > 0.0001 && t < phases.inDuration {
            phase = .intro
            phaseProgress = t / phases.inDuration
            phaseDuration = phases.inDuration
        } else if phases.loopDuration > 0.0001 && t < loopEnd {
            phase = .loop
            let loopElapsed = max(0.0, t - phases.inDuration)
            phaseProgress = loopElapsed / phases.loopDuration
            phaseDuration = phases.cycleDuration
        } else {
            phase = .outro
            phaseDuration = max(0.0001, phases.outDuration)
            phaseProgress = max(0.0, min(1.0, (t - loopEnd) / phaseDuration))
        }

        let seed = graph.id.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        let overrideDir = anim.staggerDirection == .forward ? nil : anim.staggerDirection
        return TextAnimationGraphContext(
            phase: phase,
            globalProgress: t / max(0.0001, totalDuration),
            phaseProgress: phaseProgress,
            loopProgress: loopProgress,
            elapsedSeconds: t,
            phaseDuration: phaseDuration,
            unitIndex: unitIndex,
            unitCount: unitCount,
            randomSeed: seed,
            externalInputs: externalInputs,
            staggerDirectionOverride: overrideDir,
            isSeamlessLifecycle: true
        )
    }

    static func unitDelta(from bag: TextAnimationParameterBag) -> TextUnitDelta {
        let echoX = bag[TextAnimationChannel.echoOffsetX] ?? 0.0
        let echoY = bag[TextAnimationChannel.echoOffsetY] ?? 0.0
        let resolvedEchoCount: Int = if let rawCount = bag[TextAnimationChannel.echoCount] {
            max(0, Int(rawCount.rounded()))
        } else if abs(echoX) > 0.001 || abs(echoY) > 0.001 {
            3
        } else {
            0
        }

        return buildDelta(from: bag, echoCount: resolvedEchoCount, echoX: echoX, echoY: echoY)
    }

    private static func buildDelta(
        from bag: TextAnimationParameterBag,
        echoCount: Int,
        echoX: Double,
        echoY: Double
    ) -> TextUnitDelta {
        let maskMode = resolveMaskShape(from: bag)
        let anchor = resolveAnchor(from: bag)
        return TextUnitDelta(
            offsetX: bag.firstValue(forKeys: [TextAnimationChannel.positionX, "transform.x"]),
            offsetY: bag.firstValue(forKeys: [TextAnimationChannel.positionY, "transform.y"]),
            offsetZEm: bag[TextAnimationChannel.positionZ] ?? 0.0,
            canvasOffsetXRatio: bag[TextAnimationChannel.canvasOffsetX] ?? 0.0,
            canvasOffsetYRatio: bag[TextAnimationChannel.canvasOffsetY] ?? 0.0,
            scaleX: bag.firstValue(forKeys: [TextAnimationChannel.scaleX, "transform.scaleX"], default: 1.0),
            scaleY: bag.firstValue(forKeys: [TextAnimationChannel.scaleY, "transform.scaleY"], default: 1.0),
            rotation: bag[TextAnimationChannel.rotation] ?? 0.0,
            rotationX: bag[TextAnimationChannel.rotationX] ?? 0.0,
            rotationY: bag[TextAnimationChannel.rotationY] ?? 0.0,
            skewX: bag.firstValue(forKeys: [TextAnimationChannel.skewX, "transform.skewX"]),
            skewY: bag.firstValue(forKeys: [TextAnimationChannel.skewY, "transform.skewY"]),
            opacity: bag.firstValue(forKeys: [TextAnimationChannel.opacity, "opacity"], default: 1.0),
            trailingCursorOpacity: bag[TextAnimationChannel.trailingCursorOpacity] ?? 0.0,
            waveAmplitudeEm: bag[TextAnimationChannel.waveAmplitude] ?? 0.0,
            waveFrequencyEm: bag[TextAnimationChannel.waveFrequency] ?? 0.0,
            wavePhaseRadians: bag[TextAnimationChannel.wavePhase] ?? 0.0,
            clipRevealX: bag[TextAnimationChannel.maskRevealX] ?? 1.0,
            clipRevealY: bag[TextAnimationChannel.maskRevealY] ?? 1.0,
            maskShapeMode: maskMode,
            strokeTrimProgress: bag[TextAnimationChannel.pathTrimProgress] ?? 1.0,
            scrambleStrength: bag[TextAnimationChannel.textScramble] ?? 0.0,
            trackingEmDelta: bag[TextAnimationChannel.textTracking] ?? 0.0,
            anchorOverride: anchor,
            echoCount: echoCount,
            echoOffsetXEm: echoX,
            echoOffsetYEm: echoY,
            shadowDistanceDelta: bag[TextAnimationChannel.shadowDistance] ?? 0.0,
            blurRadius: bag[TextAnimationChannel.blurRadius] ?? 0.0,
            noiseIntensity: bag[TextAnimationChannel.noiseIntensity] ?? 0.0,
            perspectiveX: bag[TextAnimationChannel.perspectiveX] ?? 0.0,
            perspectiveY: bag[TextAnimationChannel.perspectiveY] ?? 0.0,
            motionBlurRadius: bag[TextAnimationChannel.motionBlurRadius] ?? 0.0,
            motionBlurAngle: bag[TextAnimationChannel.motionBlurAngle] ?? 0.0,
            liquidWavePhase: bag[TextAnimationChannel.liquidPhase] ?? -1.0,
            liquidMorphIntensity: bag[TextAnimationChannel.liquidAmount] ?? 0.0,
            pixelateScale: bag[TextAnimationChannel.pixelateScale] ?? 0.0,
            dissolveProgress: bag[TextAnimationChannel.dissolveProgress] ?? 0.0,
            dissolveAngleRadians: bag[TextAnimationChannel.dissolveAngle] ?? -0.75,
            bevelDepth: bag[TextAnimationChannel.bevelDepth] ?? 0.0,
            bevelLightAngle: bag[TextAnimationChannel.bevelLightAngle] ?? 0.75,
            bevelExtrudeDepth: bag[TextAnimationChannel.bevelExtrudeDepth] ?? 0.0,
            particleFieldProgress: bag[TextAnimationChannel.particleFieldProgress] ?? 0.0,
            particleFieldAngle: bag[TextAnimationChannel.particleFieldAngle] ?? -0.60,
            meshWarpMode: resolveMeshWarpMode(from: bag),
            meshWarpAmount: bag[TextAnimationChannel.meshWarpAmount] ?? 0.0,
            meshWarpFrequency: bag[TextAnimationChannel.meshWarpFrequency] ?? 1.5,
            meshWarpPhase: bag[TextAnimationChannel.meshWarpPhase] ?? 0.0
        )
    }

    private static func resolveAnchor(from bag: TextAnimationParameterBag) -> TextAnchorPoint? {
        let named = bag.stringValue(for: TextAnimationChannel.anchor).flatMap(TextAnchorPoint.init(rawValue:))
        let ax = bag[TextAnimationChannel.anchorX]
        let ay = bag[TextAnimationChannel.anchorY]
        if ax != nil || ay != nil {
            let base = named ?? .center
            return TextAnchorPoint(x: ax ?? base.x, y: ay ?? base.y)
        }
        return named
    }

    private static func resolveMeshWarpMode(from bag: TextAnimationParameterBag) -> TextMeshWarpMode {
        if let raw = bag.stringValue(for: TextAnimationChannel.meshWarpMode),
           let mode = TextMeshWarpMode(rawValue: raw) {
            return mode
        }
        guard let numeric = bag[TextAnimationChannel.meshWarpMode] else { return .none }
        let idx = max(0, min(TextMeshWarpMode.allCases.count - 1, Int(numeric.rounded())))
        return TextMeshWarpMode.allCases[idx]
    }

    private static func resolveMaskShape(from bag: TextAnimationParameterBag) -> TextMaskShapeMode {
        if let raw = bag.stringValue(for: TextAnimationChannel.maskShape),
           let mode = TextMaskShapeMode(rawValue: raw) {
            return mode
        }
        guard let numeric = bag[TextAnimationChannel.maskShape] else { return .rect }
        let idx = max(0, min(TextMaskShapeMode.allCases.count - 1, Int(numeric.rounded())))
        return TextMaskShapeMode.allCases[idx]
    }
}
