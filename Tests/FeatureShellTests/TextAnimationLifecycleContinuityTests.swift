import Foundation
import CoreGraphics
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("Text Animation Seamless In-Loop-Out Lifecycle")
struct TextAnimationLifecycleContinuityTests {
    private let canvasSize = CGSize(width: 640, height: 360)

    @Test("All 21 Graph presets maintain C0 seam continuity across In-Loop and Loop-Out and move continuously in Loop")
    func testAllGraphPresetsMaintainSeamContinuityAndActiveLoop() {
        let graphs = TextAnimationGraphLibrary.allGraphs
        #expect(graphs.count == 21)

        for graph in graphs {
            let config = TextConfiguration(
                content: "FLOW",
                fontSize: 56,
                animation: TextAnimationConfiguration(scriptSpeed: 1.0, graph: graph)
            )
            let phases = config.animation.resolvedPhases(
                forClipDuration: 5.0,
                baseCycleSeconds: graph.loopCycleDuration
            )
            let inSeam = phases.inDuration
            let outSeam = phases.inDuration + phases.loopDuration

            for charIdx in [0, 3] {
                let beforeInLoop = TextAnimationEvaluator.evaluate(
                    config: config, localTime: inSeam - 0.002, duration: 5.0,
                    canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                let afterInLoop = TextAnimationEvaluator.evaluate(
                    config: config, localTime: inSeam + 0.002, duration: 5.0,
                    canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                assertSeamContinuous(beforeInLoop, afterInLoop, label: "\(graph.id) In->Loop u=\(charIdx)")

                let beforeLoopOut = TextAnimationEvaluator.evaluate(
                    config: config, localTime: outSeam - 0.002, duration: 5.0,
                    canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                let afterLoopOut = TextAnimationEvaluator.evaluate(
                    config: config, localTime: outSeam + 0.002, duration: 5.0,
                    canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                assertSeamContinuous(beforeLoopOut, afterLoopOut, label: "\(graph.id) Loop->Out u=\(charIdx)")
            }

            let loopA = TextAnimationEvaluator.evaluate(
                config: config, localTime: inSeam + 0.22, duration: 5.0,
                canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            let loopB = TextAnimationEvaluator.evaluate(
                config: config, localTime: inSeam + 0.68, duration: 5.0,
                canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            #expect(stateDistance(loopA, loopB) > 0.001, "Graph \(graph.id) froze during .loop phase")
        }
    }

    @Test("Staggered Graph and Script presets hand off early Intro units and trailing Outro units without mid-phase freeze")
    func testPerUnitStaggerHandoffEliminatesMidPhaseWaitingFreeze() {
        let staggeredGraphs: [TextAnimationGraph] = [
            TextAnimationGraphLibrary.orbitCarousel3D,
            TextAnimationGraphLibrary.quantumParticleAssembly,
            TextAnimationGraphLibrary.dominoBottomCascade,
            TextAnimationGraphLibrary.pendulumTopCorner
        ]

        for graph in staggeredGraphs {
            let config = TextConfiguration(
                content: "FLOW",
                fontSize: 56,
                animation: TextAnimationConfiguration(scriptSpeed: 1.0, graph: graph)
            )
            let phases = config.animation.resolvedPhases(
                forClipDuration: 5.0,
                baseCycleSeconds: graph.loopCycleDuration
            )
            // Unit 0 finishes its Intro early; verify it keeps moving into the Loop wave during late Intro
            let lateIntroA = TextAnimationEvaluator.evaluate(
                config: config, localTime: phases.inDuration * 0.72, duration: 5.0,
                canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            let lateIntroB = TextAnimationEvaluator.evaluate(
                config: config, localTime: phases.inDuration * 0.92, duration: 5.0,
                canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            #expect(stateDistance(lateIntroA, lateIntroB) > 0.01, "Graph \(graph.id) unit 0 froze waiting for trailing Intro units")

            // Unit 3 exits last in Outro; verify it keeps riding the Loop wave during early Outro
            let outStart = phases.inDuration + phases.loopDuration
            let earlyOutroA = TextAnimationEvaluator.evaluate(
                config: config, localTime: outStart + phases.outDuration * 0.05, duration: 5.0,
                canvasSize: canvasSize, charIndex: 3, charCount: 4
            )
            let earlyOutroB = TextAnimationEvaluator.evaluate(
                config: config, localTime: outStart + phases.outDuration * 0.22, duration: 5.0,
                canvasSize: canvasSize, charIndex: 3, charCount: 4
            )
            #expect(stateDistance(earlyOutroA, earlyOutroB) > 0.01, "Graph \(graph.id) unit 3 froze waiting for staggered Outro")
        }

        let upgradedScriptIDs = [
            "kinetic_drop_glow", "elastic_flip_3d", "dna_helix_twist",
            "tornado_spiral_pop", "pendulum_hinge_swing", "three_d_card_carousel",
            "fade_diagonal_slash", "pop_collision_slam", "wave_liquid_ripple"
        ]
        for scriptId in upgradedScriptIDs {
            var cfg = TextConfiguration(content: "FLOW", fontSize: 56)
            cfg.animation.scriptId = scriptId
            cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 3, speed: 1.0)

            for charIdx in [0, 3] {
                let inBefore = TextAnimationEvaluator.evaluate(
                    config: cfg, localTime: 0.998, duration: 5.0, canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                let inAfter = TextAnimationEvaluator.evaluate(
                    config: cfg, localTime: 1.002, duration: 5.0, canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                assertSeamContinuous(inBefore, inAfter, label: "\(scriptId) In->Loop u=\(charIdx)")

                let outBefore = TextAnimationEvaluator.evaluate(
                    config: cfg, localTime: 3.998, duration: 5.0, canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                let outAfter = TextAnimationEvaluator.evaluate(
                    config: cfg, localTime: 4.002, duration: 5.0, canvasSize: canvasSize, charIndex: charIdx, charCount: 4
                )
                assertSeamContinuous(outBefore, outAfter, label: "\(scriptId) Loop->Out u=\(charIdx)")
            }

            // Unit 0 must not sit clamped between t=0.60 and t=0.70 (old guard progress > 0.72 bug)
            let midIntroA = TextAnimationEvaluator.evaluate(
                config: cfg, localTime: 0.60, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            let midIntroB = TextAnimationEvaluator.evaluate(
                config: cfg, localTime: 0.70, duration: 5.0, canvasSize: canvasSize, charIndex: 0, charCount: 4
            )
            #expect(stateDistance(midIntroA, midIntroB) > 0.001, "Script \(scriptId) unit 0 froze at t=0.60..0.70")
        }
    }

    private func assertSeamContinuous(
        _ a: TextAnimationEvaluator.EvaluationResult,
        _ b: TextAnimationEvaluator.EvaluationResult,
        label: String
    ) {
        #expect(abs(a.config.positionX - b.config.positionX) < 2.0, "\(label) positionX jump")
        #expect(abs(a.config.positionY - b.config.positionY) < 2.0, "\(label) positionY jump")
        #expect(abs(a.config.rotation - b.config.rotation) < 2.0, "\(label) rotation jump")
        #expect(abs(a.config.opacity - b.config.opacity) < 0.05, "\(label) opacity jump")
        #expect(abs(a.overlay.scaleX - b.overlay.scaleX) < 0.03, "\(label) scaleX jump")
        #expect(abs(a.overlay.scaleY - b.overlay.scaleY) < 0.03, "\(label) scaleY jump")
        #expect(abs(a.overlay.rotationX - b.overlay.rotationX) < 2.5, "\(label) rotationX jump")
        #expect(abs(a.overlay.rotationY - b.overlay.rotationY) < 2.5, "\(label) rotationY jump")
        #expect(abs(a.overlay.meshWarpAmount - b.overlay.meshWarpAmount) < 0.05, "\(label) meshWarpAmount jump")
        #expect(abs(a.overlay.liquidMorphIntensity - b.overlay.liquidMorphIntensity) < 0.05, "\(label) liquidMorphIntensity jump")
    }

    private func stateDistance(
        _ a: TextAnimationEvaluator.EvaluationResult,
        _ b: TextAnimationEvaluator.EvaluationResult
    ) -> Double {
        abs(a.config.positionX - b.config.positionX)
            + abs(a.config.positionY - b.config.positionY)
            + abs(a.config.rotation - b.config.rotation)
            + abs(a.overlay.scaleX - b.overlay.scaleX) * 50.0
            + abs(a.overlay.scaleY - b.overlay.scaleY) * 50.0
            + abs(a.overlay.rotationX - b.overlay.rotationX)
            + abs(a.overlay.rotationY - b.overlay.rotationY)
            + abs(a.overlay.offsetZEm - b.overlay.offsetZEm) * 40.0
            + abs(a.overlay.trackingEmDelta - b.overlay.trackingEmDelta) * 100.0
            + abs(a.overlay.meshWarpAmount - b.overlay.meshWarpAmount) * 40.0
            + abs(a.overlay.meshWarpPhase - b.overlay.meshWarpPhase) * 10.0
            + abs(a.overlay.bevelLightAngle - b.overlay.bevelLightAngle) * 10.0
    }
}
