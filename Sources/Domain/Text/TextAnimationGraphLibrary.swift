import Foundation

/// Dev-authored flagship library of data-driven `TextAnimationGraph` presets
/// unlocking SDF 3D PBR Bevel, GPU Particle Scatter, and Audio-Reactive Kinetic motion.
/// Complies with AGENTS.md Điều 15 (pure Dev-authored library) & Điều 5 (`import Foundation` only).
public enum TextAnimationGraphLibrary: Sendable {
    public static let allGraphs: [TextAnimationGraph] = [
        chromeBevelStudio3D,
        quantumParticleAssembly,
        audioBeatKineticPulse
    ] + extendedCatalogGraphs + sculptAnd3DCatalogGraphs + kineticAndPathCatalogGraphs

    public static func graph(for id: String) -> TextAnimationGraph? {
        allGraphs.first { $0.id == id }
    }

    public static let chromeBevelStudio3D = TextAnimationGraph(
        id: "graph_chrome_bevel_3d",
        name: "3D Bevel Sculpt",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .intro, signal: .spring(from: 0.72, to: 1.0, frequency: 1.4, damping: 0.65, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .intro, signal: .spring(from: 0.72, to: 1.0, frequency: 1.4, damping: 0.65, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 5.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.022, phase: .pi * 0.5, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.022, phase: .pi * 0.5, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress)))),
            TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(6.0)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelExtrudeDepth, signal: .constant(4.0)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelLightAngle, signal: .oscillator(waveform: .sawtooth, frequency: 1.0, amplitude: .pi, phase: 0.0, offset: .pi, pulseWidth: 0.5, time: .loopProgress))
        ]
    )

    public static let quantumParticleAssembly = TextAnimationGraph(
        id: "graph_quantum_particles",
        name: "Quantum Particle Assembly",
        scope: .perWord,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.0)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.particleFieldProgress, phase: .intro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 5.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.45),
            TextAnimationTrack(channel: TextAnimationChannel.particleFieldProgress, phase: .outro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.progress(.phaseProgress)), staggerFraction: 0.35)
        ]
    )

    public static let audioBeatKineticPulse = TextAnimationGraph(
        id: "graph_audio_beat_pulse",
        name: "Audio Beat Kinetic Pulse",
        scope: .perWord,
        layers: [
            TextAnimationLayer(
                name: "Motion Envelope",
                tracks: [
                    TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.25),
                    TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.35),
                    TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.25)
                ]
            ),
            TextAnimationLayer(
                name: "Audio Reactive Drive",
                tracks: [
                    TextAnimationTrack(
                        channel: TextAnimationChannel.scaleX,
                        signal: .remap(.externalInput(name: TextAnimationChannel.audioBass, fallback: 0.2), inputMin: 0.0, inputMax: 1.0, outputMin: 0.96, outputMax: 1.24)
                    ),
                    TextAnimationTrack(
                        channel: TextAnimationChannel.scaleY,
                        signal: .remap(.externalInput(name: TextAnimationChannel.audioRMS, fallback: 0.2), inputMin: 0.0, inputMax: 1.0, outputMin: 0.96, outputMax: 1.28)
                    ),
                    TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(4.0))
                ]
            )
        ]
    )
}
