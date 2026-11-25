import Foundation

extension TextAnimationGraphLibrary {
    public static let kineticAndPathCatalogGraphs: [TextAnimationGraph] = [
        slalomSplineGlide,
        rightHingeTrapdoor,
        jellyMercuryWave,
        pendulumTopCorner,
        irisLaserCarve,
        cipherScrambleDraw
    ]

    /// 7. Multi-point S-slalom spline flight (`catmullRom`) with auto-banked `tangentDegrees` & motion blur.
    public static let slalomSplineGlide = TextAnimationGraph(
        id: "graph_slalom_spline_glide",
        name: "Slalom Spline Glide",
        scope: .perWord,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .intro, signal: .motionPath(introSlalomSpline, output: .positionX, time: .phaseProgress), staggerFraction: 0.34),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .intro, signal: .motionPath(introSlalomSpline, output: .positionY, time: .phaseProgress), staggerFraction: 0.34),
            TextAnimationTrack(
                channel: TextAnimationChannel.rotation, phase: .intro,
                signal: .multiply(.motionPath(introSlalomSpline, output: .tangentDegrees, time: .phaseProgress), .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(0.35))),
                staggerFraction: 0.34
            ),
            TextAnimationTrack(channel: TextAnimationChannel.motionBlurRadius, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(16.0)), staggerFraction: 0.34),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.34),
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 7.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 2.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .outro, signal: .motionPath(outroSlalomSpline, output: .positionX, time: .phaseProgress), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .outro, signal: .motionPath(outroSlalomSpline, output: .positionY, time: .phaseProgress), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.motionBlurRadius, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(16.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.30)
        ]
    )

    /// 8. Right-edge hinged trapdoor (`Trailing` 2D anchor + `rotationY` + dynamic `skewY`).
    public static let rightHingeTrapdoor = TextAnimationGraph(
        id: "graph_right_hinge_trapdoor",
        name: "Right Hinge Trapdoor",
        scope: .perLine,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .intro, signal: .spring(from: 80.0, to: 0.0, frequency: 1.6, damping: 0.62, time: .phaseProgress), staggerFraction: 0.32),
            TextAnimationTrack(channel: TextAnimationChannel.skewY, phase: .intro, signal: .spring(from: -18.0, to: 0.0, frequency: 1.6, damping: 0.65, time: .phaseProgress), staggerFraction: 0.32),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.32),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 5.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.skewY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 2.0, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-80.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.skewY, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(18.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.30)
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.trailing.rawValue]
    )

    /// 9. Continuous fluid ripple combining `liquidMorph` and staggered loop motion.
    public static let jellyMercuryWave = TextAnimationGraph(
        id: "graph_jelly_mercury_wave",
        name: "Jelly Mercury Ripple",
        scope: .perCharacter,
        loopCycleDuration: 1.5,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .intro, signal: .spring(from: 0.25, to: 1.0, frequency: 2.0, damping: 0.48, time: .phaseProgress), staggerFraction: 0.42),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.0)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.42),
            TextAnimationTrack(
                channel: TextAnimationChannel.positionY, phase: .loop,
                signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 10.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress),
                staggerFraction: 0.55
            ),
            TextAnimationTrack(
                channel: TextAnimationChannel.skewX, phase: .loop,
                signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.14, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress),
                staggerFraction: 0.55
            ),
            TextAnimationTrack(channel: TextAnimationChannel.liquidAmount, signal: .constant(0.45)),
            TextAnimationTrack(channel: TextAnimationChannel.liquidPhase, signal: .multiply(.progress(.loopProgress), .constant(.pi * 2.0))),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.36)
        ]
    )

    /// 10. Top-right hook pendulum swing (`Top Trailing` 2D anchor + damped spring intro + gentle loop sway).
    public static let pendulumTopCorner = TextAnimationGraph(
        id: "graph_pendulum_top_corner",
        name: "Corner Pendulum",
        scope: .perWord,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .intro, signal: .spring(from: 42.0, to: 0.0, frequency: 1.7, damping: 0.46, time: .phaseProgress), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.5)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.35),
            TextAnimationTrack(
                channel: TextAnimationChannel.rotation, phase: .loop,
                signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress),
                staggerFraction: 0.40
            ),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(95.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-28.0)), staggerFraction: 0.30),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.30)
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.topTrailing.rawValue]
    )

    /// 11. Vector outline path carving synchronized with an expanding circular iris mask (`irisCircle`).
    public static let irisLaserCarve = TextAnimationGraph(
        id: "graph_iris_laser_carve",
        name: "Iris Vector Carve",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.pathTrimProgress, phase: .intro, signal: .smoothstep(.progress(.phaseProgress))),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealX, phase: .intro, signal: .remap(.smoothstep(.progress(.phaseProgress)), inputMin: 0.0, inputMax: 1.0, outputMin: 0.12, outputMax: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealY, phase: .intro, signal: .remap(.smoothstep(.progress(.phaseProgress)), inputMin: 0.0, inputMax: 1.0, outputMin: 0.12, outputMax: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.5)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.025, phase: 0.0, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.025, phase: 0.0, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(3.5)),
            TextAnimationTrack(channel: TextAnimationChannel.bevelLightAngle, signal: .oscillator(waveform: .sawtooth, frequency: 1.0, amplitude: .pi, phase: 0.0, offset: .pi, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealX, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress)))),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealY, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress)))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))))
        ],
        staticStringChannels: [TextAnimationChannel.maskShape: TextMaskShapeMode.irisCircle.rawValue]
    )

    /// 12. Matrix glyph scramble behind a diagonal slash reveal with a blinking cursor bar.
    public static let cipherScrambleDraw = TextAnimationGraph(
        id: "graph_cipher_scramble_draw",
        name: "Cipher Slash Decode",
        scope: .perCharacter,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.textScramble, phase: .intro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealX, phase: .intro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.maskRevealY, phase: .intro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.positionZ, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(0.85)), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.trailingCursorOpacity, phase: .intro, signal: .oneMinus(.progress(.phaseProgress)), staggerFraction: 0.55),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.50),
            TextAnimationTrack(channel: TextAnimationChannel.positionZ, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.18, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.50),
            TextAnimationTrack(channel: TextAnimationChannel.textScramble, phase: .outro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.45),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.45)
        ],
        staticStringChannels: [TextAnimationChannel.maskShape: TextMaskShapeMode.diagonalSlash.rawValue]
    )

    private static let introSlalomSpline = TextAnimationMotionPath.catmullRom(
        points: [.init(x: -165.0, y: -55.0), .init(x: -105.0, y: 48.0), .init(x: -45.0, y: -28.0), .init(x: 0.0, y: 0.0)],
        isClosed: false
    )

    private static let outroSlalomSpline = TextAnimationMotionPath.catmullRom(
        points: [.init(x: 0.0, y: 0.0), .init(x: 48.0, y: 32.0), .init(x: 108.0, y: -46.0), .init(x: 168.0, y: 52.0)],
        isClosed: false
    )
}
