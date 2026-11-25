import Foundation

extension TextAnimationGraphLibrary {
    public static let sculptAnd3DCatalogGraphs: [TextAnimationGraph] = [
        origamiCornerUnfold,
        spiralVortexOrbit,
        ribbonTwistSnap,
        lensBubblePop,
        dominoBottomCascade,
        audioEqualizerBounce
    ]

    /// 1. Diagonal corner-hinged 3D unfold (`Top Leading` 2D anchor + dual-axis damped spring).
    public static let origamiCornerUnfold = TextAnimationGraph(
        id: "graph_origami_corner_unfold",
        name: "Origami Unfold 3D",
        scope: .perWord,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .intro, signal: .spring(from: -78.0, to: 0.0, frequency: 1.6, damping: 0.62, time: .phaseProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .intro, signal: .spring(from: 64.0, to: 0.0, frequency: 1.6, damping: 0.62, time: .phaseProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .intro, signal: .spring(from: 0.65, to: 1.0, frequency: 1.5, damping: 0.68, time: .phaseProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 5.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(75.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-60.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.30)
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.topLeading.rawValue]
    )

    /// 2. Inward converging 3D spiral (`orbitalArc` * envelope + `positionZ` depth sorting).
    public static let spiralVortexOrbit = TextAnimationGraph(
        id: "graph_spiral_vortex_orbit",
        name: "Spiral Vortex 3D",
        scope: .perCharacter,
        loopCycleDuration: 2.0,
        tracks: [
            TextAnimationTrack(
                channel: TextAnimationChannel.positionX, phase: .intro,
                signal: .multiply(.motionPath(vortexSpiralArc, output: .positionX, time: .phaseProgress), .oneMinus(.smoothstep(.progress(.phaseProgress)))),
                staggerFraction: 0.42
            ),
            TextAnimationTrack(
                channel: TextAnimationChannel.positionY, phase: .intro,
                signal: .multiply(.motionPath(vortexSpiralArc, output: .positionY, time: .phaseProgress), .oneMinus(.smoothstep(.progress(.phaseProgress)))),
                staggerFraction: 0.42
            ),
            TextAnimationTrack(channel: TextAnimationChannel.positionZ, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(-2.4)), staggerFraction: 0.42),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(-140.0)), staggerFraction: 0.42),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(2.8)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.42),
            TextAnimationTrack(
                channel: TextAnimationChannel.positionZ, phase: .loop,
                signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.55, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress),
                staggerFraction: 0.65
            ),
            TextAnimationTrack(
                channel: TextAnimationChannel.positionY, phase: .loop,
                signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 5.0, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress),
                staggerFraction: 0.65
            ),
            TextAnimationTrack(
                channel: TextAnimationChannel.positionX, phase: .outro,
                signal: .multiply(.motionPath(vortexSpiralArc, output: .positionX, time: .phaseProgress), .smoothstep(.progress(.phaseProgress))),
                staggerFraction: 0.35
            ),
            TextAnimationTrack(channel: TextAnimationChannel.positionZ, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(1.8)), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.35)
        ]
    )

    /// 3. Helical torsion ribbon untwisting into 3D beveled typography (`MeshWarp.twist` + `bevelExtrudeDepth`).
    public static let ribbonTwistSnap = TextAnimationGraph(
        id: "graph_ribbon_twist_snap",
        name: "Ribbon Twist Sculpt",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .intro, signal: .spring(from: 1.45, to: 0.0, frequency: 1.5, damping: 0.60, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpPhase, phase: .intro, signal: .multiply(.oneMinus(.progress(.phaseProgress)), .constant(.pi))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.18, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(5.5)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelExtrudeDepth, signal: .constant(3.2)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelLightAngle, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.85, phase: 0.0, offset: 0.75, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-1.35))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))))
        ],
        staticStringChannels: [TextAnimationChannel.meshWarpMode: TextMeshWarpMode.twist.rawValue]
    )

    /// 4. Spherical fish-eye inflation with elastic settle (`MeshWarp.lensBulge` + spring squash-and-stretch).
    public static let lensBubblePop = TextAnimationGraph(
        id: "graph_lens_bubble_pop",
        name: "Lens Bubble Pop",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .intro, signal: .spring(from: 1.65, to: 0.0, frequency: 2.1, damping: 0.48, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .intro, signal: .spring(from: 0.35, to: 1.0, frequency: 1.9, damping: 0.52, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .intro, signal: .spring(from: 0.35, to: 1.0, frequency: 2.2, damping: 0.50, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(4.0)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.20, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.028, phase: 0.0, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: -0.028, phase: 0.0, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-1.4))),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .outro, signal: .oneMinus(.multiply(.smoothstep(.progress(.phaseProgress)), .constant(0.65)))),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .outro, signal: .oneMinus(.multiply(.smoothstep(.progress(.phaseProgress)), .constant(0.65)))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))))
        ],
        staticStringChannels: [TextAnimationChannel.meshWarpMode: TextMeshWarpMode.lensBulge.rawValue]
    )

    /// 5. Character domino cascade anchored at the `Bottom Leading` corner foot with kinetic echoes.
    public static let dominoBottomCascade = TextAnimationGraph(
        id: "graph_domino_bottom_cascade",
        name: "Domino Foot Cascade",
        scope: .perCharacter,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .intro, signal: .spring(from: -72.0, to: 0.0, frequency: 1.8, damping: 0.56, time: .phaseProgress), staggerFraction: 0.48),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .intro, signal: .spring(from: 55.0, to: 0.0, frequency: 1.8, damping: 0.60, time: .phaseProgress), staggerFraction: 0.48),
            TextAnimationTrack(channel: TextAnimationChannel.echoOffsetY, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(-0.14)), staggerFraction: 0.48),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.5)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.48),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.2, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.50),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 7.0, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.50),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(72.0)), staggerFraction: 0.42),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.42)
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.bottomLeading.rawValue]
    )

    /// 6. Baseline-anchored live spectrum equalizer driven by multi-band audio (`audioBass`, `audioTreble`, `audioBeat`).
    public static let audioEqualizerBounce = TextAnimationGraph(
        id: "graph_audio_eq_bounce",
        name: "Audio EQ Baseline",
        scope: .perCharacter,
        layers: [
            TextAnimationLayer(
                name: "Entry & Exit",
                tracks: [
                    TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.30, staggerDirection: .centerOut),
                    TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 2.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.50),
                    TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.30, staggerDirection: .edgesIn)
                ]
            ),
            TextAnimationLayer(
                name: "Spectrum Stretch",
                tracks: [
                    TextAnimationTrack(
                        channel: TextAnimationChannel.scaleY,
                        signal: .add(
                            .constant(0.92),
                            .add(
                                .multiply(.oneMinus(.unitCenterDistance), .multiply(.externalInput(name: TextAnimationChannel.audioBass, fallback: 0.22), .constant(0.52))),
                                .multiply(.unitCenterDistance, .multiply(.externalInput(name: TextAnimationChannel.audioTreble, fallback: 0.18), .constant(0.46)))
                            )
                        )
                    ),
                    TextAnimationTrack(
                        channel: TextAnimationChannel.scaleX,
                        signal: .remap(.externalInput(name: TextAnimationChannel.audioBeat, fallback: 0.15), inputMin: 0.0, inputMax: 1.0, outputMin: 1.0, outputMax: 0.90)
                    )
                ]
            )
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.bottom.rawValue]
    )

    private static let vortexSpiralArc = TextAnimationMotionPath.orbitalArc(
        radiusX: 118.0, radiusY: 66.0, startDegrees: -210.0, endDegrees: 0.0
    )
}
