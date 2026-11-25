import Foundation

extension TextAnimationGraphLibrary {
    public static let extendedCatalogGraphs: [TextAnimationGraph] = [
        doorHingeSwing3D,
        orbitCarousel3D,
        bezierRibbonFly,
        flagMeshFlutter,
        arcBendBounce,
        trackedGravityExpand
    ]

    public static func category(for graphId: String) -> TextAnimationCategory {
        catalogMetadata[graphId]?.category ?? .threeD
    }

    public static func description(for graphId: String) -> String {
        catalogMetadata[graphId]?.description ?? "Data-driven procedural text animation graph"
    }

    private static let catalogMetadata: [String: (category: TextAnimationCategory, description: String)] = [
        "graph_chrome_bevel_3d": (.threeD, "3D metallic bevel sculpt with sweep highlight across typography depth"),
        "graph_quantum_particles": (.fade, "Contour particle assembly and scatter powered by Metal SDF shaders"),
        "graph_audio_beat_pulse": (.pop, "Beat-synced kinetic punch and 3D bevel relief reactive to audio bass"),
        "graph_door_hinge_3d": (.threeD, "Swings smoothly on the left hinge edge with true 3D perspective"),
        "graph_orbit_carousel_3d": (.threeD, "Characters orbit in 3D space with true Z-depth back-to-front sorting"),
        "graph_bezier_ribbon_fly": (.slide, "Words glide along a curved Bezier flight path with dynamic tilt"),
        "graph_flag_mesh_flutter": (.wave, "Continuous GPU ribbon mesh wave keeping original typography colors"),
        "graph_arc_bend_bounce": (.pop, "Elastic bend warp snap into crisp straight typography"),
        "graph_tracked_expand": (.fade, "Characters expand outward from center with crisp tracking & 3D tilt"),
        "graph_origami_corner_unfold": (.threeD, "Diagonal 3D origami unfold anchored at the top-left corner"),
        "graph_spiral_vortex_orbit": (.threeD, "Characters spiral in from 3D depth along an orbital vortex"),
        "graph_ribbon_twist_snap": (.threeD, "3D beveled letters untwist from a helical ribbon into place"),
        "graph_lens_bubble_pop": (.pop, "Spherical lens bulge inflation with elastic spring snap"),
        "graph_domino_bottom_cascade": (.pop, "Characters tip upright like domino tiles from bottom-left anchor"),
        "graph_audio_eq_bounce": (.pop, "Baseline-anchored characters stretch like a multi-band audio equalizer"),
        "graph_slalom_spline_glide": (.slide, "Words weave along a Catmull-Rom S-spline with banked tilt & motion blur"),
        "graph_right_hinge_trapdoor": (.slide, "Lines swing shut from the right hinge edge with dynamic shear"),
        "graph_jelly_mercury_wave": (.wave, "Continuous fluid jelly ripple preserving original typography colors"),
        "graph_pendulum_top_corner": (.wave, "Words swing from the top-right hook with damped pendulum physics"),
        "graph_iris_laser_carve": (.fade, "Vector stroke outline carve paired with an expanding circular iris"),
        "graph_cipher_scramble_draw": (.typewriter, "Matrix glyph decode behind a diagonal slash wipe and cursor")
    ]

    public static let doorHingeSwing3D = TextAnimationGraph(
        id: "graph_door_hinge_3d",
        name: "Door Hinge 3D",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .intro, signal: .spring(from: -82.0, to: 0.0, frequency: 1.5, damping: 0.62, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.0)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.perspectiveY, phase: .intro, signal: .multiply(.oneMinus(.progress(.phaseProgress)), .constant(0.35))),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 6.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(82.0))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress)))),
            TextAnimationTrack(channel: TextAnimationChannel.perspectiveY, phase: .outro, signal: .multiply(.progress(.phaseProgress), .constant(-0.35)))
        ],
        staticStringChannels: [TextAnimationChannel.anchor: TextAnchorPoint.leading.rawValue]
    )

    public static let orbitCarousel3D = TextAnimationGraph(
        id: "graph_orbit_carousel_3d",
        name: "Orbit Carousel 3D",
        scope: .perCharacter,
        loopCycleDuration: 2.0,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 28.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.72),
            TextAnimationTrack(channel: TextAnimationChannel.positionZ, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 1.15, phase: .pi * 0.5, offset: -1.15, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.72),
            TextAnimationTrack(channel: TextAnimationChannel.rotationY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 38.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.72),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .smoothstep(.progress(.phaseProgress)), staggerFraction: 0.35),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.35)
        ]
    )

    public static let bezierRibbonFly = TextAnimationGraph(
        id: "graph_bezier_ribbon_fly",
        name: "Bezier Flight",
        scope: .perWord,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .intro, signal: .motionPath(introFlightPath, output: .positionX, time: .phaseProgress), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .intro, signal: .motionPath(introFlightPath, output: .positionY, time: .phaseProgress), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(-14.0)), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 6.0, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.rotation, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 2.2, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40),
            TextAnimationTrack(channel: TextAnimationChannel.positionX, phase: .outro, signal: .motionPath(outroFlightPath, output: .positionX, time: .phaseProgress), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .outro, signal: .motionPath(outroFlightPath, output: .positionY, time: .phaseProgress), staggerFraction: 0.36),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.36)
        ]
    )

    public static let flagMeshFlutter = TextAnimationGraph(
        id: "graph_flag_mesh_flutter",
        name: "Ribbon Mesh",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .smoothstep(.progress(.phaseProgress))),
            TextAnimationTrack(channel: TextAnimationChannel.positionY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 4.5, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress)))),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, signal: .constant(0.65)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpFrequency, signal: .constant(2.2)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpPhase, signal: .multiply(.progress(.loopProgress), .constant(.pi * 2.0))),
            TextAnimationTrack(channel: TextAnimationChannel.bevelDepth, signal: .constant(4.0))
        ],
        staticStringChannels: [TextAnimationChannel.meshWarpMode: TextMeshWarpMode.waveRibbon.rawValue]
    )

    public static let arcBendBounce = TextAnimationGraph(
        id: "graph_arc_bend_bounce",
        name: "Arc Bend Snap",
        scope: .wholeBlock,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .intro, signal: .spring(from: 1.15, to: 0.0, frequency: 1.8, damping: 0.55, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleX, phase: .intro, signal: .spring(from: 0.72, to: 1.0, frequency: 1.8, damping: 0.58, time: .phaseProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(3.2)), minimum: 0.0, maximum: 1.0)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.16, phase: 0.0, offset: 0.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.scaleY, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.025, phase: .pi * 0.5, offset: 1.0, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.meshWarpAmount, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(-1.1))),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))))
        ],
        staticStringChannels: [TextAnimationChannel.meshWarpMode: TextMeshWarpMode.bend.rawValue]
    )

    public static let trackedGravityExpand = TextAnimationGraph(
        id: "graph_tracked_expand",
        name: "Gravity Expand",
        scope: .perCharacter,
        tracks: [
            TextAnimationTrack(channel: TextAnimationChannel.textTracking, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(0.55)), staggerDirection: .centerOut),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .intro, signal: .multiply(.oneMinus(.smoothstep(.progress(.phaseProgress))), .constant(58.0)), staggerFraction: 0.35, staggerDirection: .centerOut),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .intro, signal: .clamp(.multiply(.progress(.phaseProgress), .constant(2.8)), minimum: 0.0, maximum: 1.0), staggerFraction: 0.35, staggerDirection: .centerOut),
            TextAnimationTrack(channel: TextAnimationChannel.textTracking, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 0.03, phase: 0.0, offset: 0.03, pulseWidth: 0.5, time: .loopProgress)),
            TextAnimationTrack(channel: TextAnimationChannel.rotationX, phase: .loop, signal: .oscillator(waveform: .sine, frequency: 1.0, amplitude: 7.0, phase: .pi * 0.5, offset: 0.0, pulseWidth: 0.5, time: .loopProgress), staggerFraction: 0.40, staggerDirection: .centerOut),
            TextAnimationTrack(channel: TextAnimationChannel.textTracking, phase: .outro, signal: .multiply(.smoothstep(.progress(.phaseProgress)), .constant(0.55)), staggerDirection: .edgesIn),
            TextAnimationTrack(channel: TextAnimationChannel.opacity, phase: .outro, signal: .oneMinus(.smoothstep(.progress(.phaseProgress))), staggerFraction: 0.35, staggerDirection: .edgesIn)
        ]
    )

    private static let introFlightPath = TextAnimationMotionPath.cubicBezier(
        p0: .init(x: -140.0, y: 72.0),
        c1: .init(x: -80.0, y: -58.0),
        c2: .init(x: -22.0, y: -24.0),
        p1: .init(x: 0.0, y: 0.0)
    )

    private static let outroFlightPath = TextAnimationMotionPath.cubicBezier(
        p0: .init(x: 0.0, y: 0.0),
        c1: .init(x: 24.0, y: 28.0),
        c2: .init(x: 88.0, y: -48.0),
        p1: .init(x: 150.0, y: -74.0)
    )
}
