import Foundation
import Testing
@testable import Domain

@Suite("Data-driven Text Animation Graph (Domain)")
struct TextAnimationGraphDomainTests {
    @Test("Tracks compose through keyframes, oscillator and blend modes")
    func tracksCompose() {
        let graph = TextAnimationGraph(
            id: "composite-test",
            name: "Composite Test",
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.positionX,
                    signal: .keyframes([
                        TextAnimationKeyframe(time: 0, value: 0, interpolationToNext: .easeOut),
                        TextAnimationKeyframe(time: 1, value: 100)
                    ], time: .phaseProgress)
                ),
                TextAnimationTrack(
                    channel: TextAnimationChannel.positionX,
                    signal: .oscillator(
                        waveform: .sine, frequency: 1, amplitude: 10,
                        phase: 0, offset: 0, pulseWidth: 0.5, time: .loopProgress
                    ),
                    blendMode: .add
                )
            ]
        )
        let result = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.4, phaseProgress: 0.25,
            loopProgress: 0.25, unitIndex: 0, unitCount: 1
        ))
        #expect(abs((result[TextAnimationChannel.positionX] ?? 0) - 53.75) < 0.01)
    }

    @Test("Track phase filters and per-unit intro stagger are evaluated independently")
    func phaseAndStagger() {
        let graph = TextAnimationGraph(
            id: "stagger-test", name: "Stagger Test", scope: .perCharacter,
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.opacity, phase: .intro,
                    signal: .unitProgress, staggerFraction: 0.4
                ),
                TextAnimationTrack(
                    channel: "effects.custom.loop", phase: .loop,
                    signal: .constant(9)
                )
            ]
        )
        let intro = graph.evaluate(in: TextAnimationGraphContext(
            phase: .intro, globalProgress: 0.2, phaseProgress: 0.5,
            unitIndex: 4, unitCount: 5
        ))
        #expect(abs((intro[TextAnimationChannel.opacity] ?? 0) - (1.0 / 6.0)) < 0.01)
        #expect(intro["effects.custom.loop"] == nil)

        let globalGraph = TextAnimationGraph(
            id: "global-stagger", name: "Global Stagger", scope: .perCharacter,
            tracks: [TextAnimationTrack(
                channel: "custom.global", signal: .progress(.globalProgress),
                staggerFraction: 0.4, staggerDirection: .forward
            )]
        )
        let global = globalGraph.evaluate(in: TextAnimationGraphContext(
            phase: .intro, globalProgress: 0.5, phaseProgress: 0.5, unitIndex: 4, unitCount: 5
        ))
        #expect(abs((global["custom.global"] ?? 0) - (1.0 / 6.0)) < 0.01)

        let loop = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.6, phaseProgress: 0.3,
            loopProgress: 0.3, unitIndex: 0, unitCount: 1
        ))
        #expect(loop["effects.custom.loop"] == 9)
        #expect(loop[TextAnimationChannel.opacity] == nil)
    }

    @Test("Loop stagger wraps loopProgress cyclically so wave oscillators never stall at cycle seams")
    func loopCyclicStaggerPreventsBoundaryStall() {
        let graph = TextAnimationGraph(
            id: "wave-loop",
            name: "Wave Loop",
            scope: .perCharacter,
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.positionY,
                    phase: .loop,
                    signal: .oscillator(
                        waveform: .sine, frequency: 1.0, amplitude: 20.0,
                        phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress
                    ),
                    staggerFraction: 0.5,
                    staggerDirection: .forward
                )
            ]
        )

        let unitTailStart = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.2, phaseProgress: 0.0, loopProgress: 0.0, unitIndex: 4, unitCount: 5
        ))[TextAnimationChannel.positionY] ?? 0.0
        let unitTailJustBeforeEnd = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.79, phaseProgress: 0.9999, loopProgress: 0.9999, unitIndex: 4, unitCount: 5
        ))[TextAnimationChannel.positionY] ?? 0.0

        // Under old clamped stagger, both values froze at 0.0; wrapped phase yields sin(-pi) -> continuous wave (~0 at exact boundary, nonzero inside)
        let unitTailAtQuarter = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.25, phaseProgress: 0.25, loopProgress: 0.25, unitIndex: 4, unitCount: 5
        ))[TextAnimationChannel.positionY] ?? 0.0
        #expect(abs(unitTailAtQuarter - (-20.0)) < 0.05)
        #expect(abs(unitTailStart - unitTailJustBeforeEnd) < 0.05)
    }

    @Test("Hold keyframes preserve values up to the next keyframe boundary")
    func holdKeyframes() {
        let signal = TextAnimationSignal.keyframes([
            .init(time: 0, value: 2, interpolationToNext: .hold),
            .init(time: 0.5, value: 4, interpolationToNext: .linear),
            .init(time: 1, value: 8)
        ], time: .phaseProgress)
        let beforeBoundary = TextAnimationGraphContext(phase: .intro, globalProgress: 0.25, phaseProgress: 0.25)
        let atBoundary = TextAnimationGraphContext(phase: .intro, globalProgress: 0.5, phaseProgress: 0.5)
        let atEnd = TextAnimationGraphContext(phase: .intro, globalProgress: 1, phaseProgress: 1)
        #expect(signal.evaluate(in: beforeBoundary) == 2)
        #expect(signal.evaluate(in: atBoundary) == 4)
        #expect(signal.evaluate(in: atEnd) == 8)
    }

    @Test("Procedural noise is deterministic for a graph seed and unit")
    func deterministicNoise() {
        let signal = TextAnimationSignal.noise(seed: 42, frequency: 7, amplitude: 2, time: .globalProgress)
        let context = TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.37, phaseProgress: 0.37,
            loopProgress: 0.37, unitIndex: 2, unitCount: 5, randomSeed: 99
        )
        #expect(signal.evaluate(in: context) == signal.evaluate(in: context))
        var changed = context
        changed.unitIndex = 3
        #expect(signal.evaluate(in: context) != signal.evaluate(in: changed))
    }

    @Test("External runtime inputs drive graph channels")
    func externalInputsDriveSignals() {
        let graph = TextAnimationGraph(
            id: "audio-reactive", name: "Audio Reactive",
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.scaleY,
                    signal: .remap(.externalInput(name: TextAnimationChannel.audioRMS, fallback: 0), inputMin: 0, inputMax: 1, outputMin: 1, outputMax: 1.8)
                )
            ]
        )
        let context = TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.2, phaseProgress: 0.2,
            loopProgress: 0.2, externalInputs: [TextAnimationChannel.audioRMS: 0.5]
        )
        #expect(abs((graph.evaluate(in: context)[TextAnimationChannel.scaleY] ?? 0) - 1.4) < 0.001)
    }

    @Test("Zero-allocation stagger ranks produce unique exact permutations for even, odd, and random modes")
    func directionalStaggerRanksExact() {
        for count in [4, 5, 6] {
            for dir in TextStaggerDirection.allCases {
                let ranks = (0..<count).map {
                    TextAnimationGraphContext.staggerOrder(index: $0, count: count, direction: dir, seed: 42)
                }
                #expect(Set(ranks) == Set(0..<count))
            }
        }
        #expect(TextAnimationGraphContext.staggerOrder(index: 2, count: 5, direction: .centerOut, seed: 0) == 0)
        #expect(TextAnimationGraphContext.staggerOrder(index: 0, count: 5, direction: .edgesIn, seed: 0) == 0)
        #expect(TextAnimationGraphContext.staggerOrder(index: 2, count: 5, direction: .edgesIn, seed: 0) == 4)
    }

    @Test("Stagger direction override honors Inspector order")
    func staggerDirectionOverrideWorks() {
        let graph = TextAnimationGraph(
            id: "override-dir",
            name: "Override Dir",
            tracks: [TextAnimationTrack(channel: "custom.rank", signal: .progress(.phaseProgress), staggerFraction: 0.6, staggerDirection: .forward)]
        )
        let leftVal = graph.evaluate(in: TextAnimationGraphContext(
            phase: .intro, globalProgress: 0.5, phaseProgress: 0.5, unitIndex: 0, unitCount: 5, staggerDirectionOverride: .backward
        ))["custom.rank"] ?? 1.0
        let rightVal = graph.evaluate(in: TextAnimationGraphContext(
            phase: .intro, globalProgress: 0.5, phaseProgress: 0.5, unitIndex: 4, unitCount: 5, staggerDirectionOverride: .backward
        ))["custom.rank"] ?? 0.0
        #expect(rightVal > leftVal)
    }

    @Test("Unit-center distance supports mirrored typography layouts")
    func unitCenterDistance() {
        let signal = TextAnimationSignal.unitCenterDistance
        let center = TextAnimationGraphContext(phase: .intro, globalProgress: 0, phaseProgress: 0.5, unitIndex: 2, unitCount: 5)
        let edge = TextAnimationGraphContext(phase: .intro, globalProgress: 0, phaseProgress: 0.5, unitIndex: 0, unitCount: 5)
        #expect(signal.evaluate(in: center) == 0)
        #expect(signal.evaluate(in: edge) == 1)
    }

    @Test("Independent layers blend additively and can be disabled")
    func layerStackBlending() {
        let graph = TextAnimationGraph(
            id: "layer-stack", name: "Layer Stack",
            layers: [
                TextAnimationLayer(name: "Base motion", tracks: [
                    TextAnimationTrack(channel: TextAnimationChannel.positionX, signal: .constant(12))
                ]),
                TextAnimationLayer(name: "Secondary motion", weight: 0.5, blendMode: .add, tracks: [
                    TextAnimationTrack(channel: TextAnimationChannel.positionX, signal: .constant(5))
                ]),
                TextAnimationLayer(name: "Muted layer", isEnabled: false, blendMode: .add, tracks: [
                    TextAnimationTrack(channel: TextAnimationChannel.positionX, signal: .constant(100))
                ])
            ]
        )
        let result = graph.evaluate(in: TextAnimationGraphContext(
            phase: .loop, globalProgress: 0.5, phaseProgress: 0.5
        ))
        #expect(result[TextAnimationChannel.positionX] == 14.5)
        #expect(graph.tracks.count == 3)
    }

    @Test("Static string channels, parameter bags, and legacy JSON decode safely")
    func stringChannelsAndCodableRoundTrip() throws {
        let legacyDecoded = try JSONDecoder().decode(TextAnimationConfiguration.self, from: Data("{}".utf8))
        #expect(legacyDecoded.graph == nil)
        #expect(legacyDecoded.scriptId == "none")

        let legacyBag = try JSONDecoder().decode(TextAnimationParameterBag.self, from: Data(#"{"values":{"a":1.5}}"#.utf8))
        #expect(legacyBag["a"] == 1.5)
        #expect(legacyBag.stringValues.isEmpty)

        let graph = TextAnimationGraph(
            id: "saved-graph", name: "Saved Graph", scope: .perWord,
            tracks: [
                TextAnimationTrack(
                    channel: TextAnimationChannel.rotation,
                    signal: .spring(from: -20, to: 0, frequency: 2.4, damping: 0.72, time: .phaseProgress),
                    modifiers: [.multiply(0.8), .clamp(minimum: -45, maximum: 45)]
                )
            ],
            staticStringChannels: [
                TextAnimationChannel.anchor: "center",
                TextAnimationChannel.maskShape: "diagonalSlash"
            ]
        )
        let original = TextAnimationConfiguration(graph: graph)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextAnimationConfiguration.self, from: data)
        #expect(decoded == original)
        #expect(decoded.graph?.staticStringChannels[TextAnimationChannel.maskShape] == "diagonalSlash")
    }

    @Test("TextAnimationGraphLibrary flagship presets evaluate across phases and roundtrip via Codable")
    func flagshipLibraryGraphsRoundTrip() throws {
        #expect(TextAnimationGraphLibrary.allGraphs.count == 4)
        for graph in TextAnimationGraphLibrary.allGraphs {
            #expect(TextAnimationGraphLibrary.graph(for: graph.id) == graph)
            let data = try JSONEncoder().encode(graph)
            let decoded = try JSONDecoder().decode(TextAnimationGraph.self, from: data)
            #expect(decoded == graph)
            let loopResult = graph.evaluate(in: TextAnimationGraphContext(
                phase: .loop, globalProgress: 0.45, phaseProgress: 0.5, loopProgress: 0.5,
                externalInputs: [
                    TextAnimationChannel.audioRMS: 0.8,
                    TextAnimationChannel.audioBass: 0.7,
                    TextAnimationChannel.audioBeat: 0.9
                ]
            ))
            #expect(!loopResult.channelNames.isEmpty)
        }
    }
}
