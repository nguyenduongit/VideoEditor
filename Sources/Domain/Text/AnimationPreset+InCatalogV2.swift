import Foundation

extension AnimationPreset {
    public static let inCatalogV2: [AnimationPreset] = [
        inSoftRise, inBlurFocus, inPopUp, inZoomPunch,
        inElasticSlide, inFlip3D, inRandomPop, inWaveRise,
        inScatterAssemble, inTrackingIn, inWipeReveal, inGlowIgnite,
        inTypewriter, inScrambleDecode
    ]

    // MARK: - 14 GÓI IN ANIMATION V2

    public static let inSoftRise = AnimationPreset(
        id: "v2_in_soft_rise", name: "Soft Rise",
        description: "Words drift smoothly upward from below with exponential ease-out",
        phase: .inAnimation, tags: ["soft", "rise", "smooth", "minimal"], previewBadge: "SMOOTH",
        manifest: CreativeAnimationManifest(
            id: "v2_in_soft_rise", name: "Soft Rise", iconName: "arrow.up.circle",
            phase: .inAnimation, defaultScope: .perWord, defaultStaggerDirection: .forward,
            offsetYExpr: "-1.0 * 24.0 * $expoInv", opacityExpr: "$expoOut"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "StudioMotion", downloadsCount: 950, isVerified: true)
    )

    public static let inBlurFocus = AnimationPreset(
        id: "v2_in_blur_focus", name: "Blur Focus",
        description: "Whole text block pulls into sharp focus from cinematic optical blur",
        phase: .inAnimation, tags: ["blur", "focus", "cinematic"], previewBadge: "CINEMA",
        manifest: CreativeAnimationManifest(
            id: "v2_in_blur_focus", name: "Blur Focus", iconName: "camera.filters",
            phase: .inAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 0.08 * $expoInv", scaleYExpr: "1.0 + 0.08 * $expoInv",
            opacityExpr: "$fadeFast", blurExpr: "18.0 * $expoInv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "OpticsLab", downloadsCount: 880, isVerified: true)
    )

    public static let inPopUp = AnimationPreset(
        id: "v2_in_pop_up", name: "Pop Up",
        description: "Each character overshoots upward and snaps back into place",
        phase: .inAnimation, tags: ["pop", "bounce", "back"], previewBadge: "BOUNCE",
        manifest: CreativeAnimationManifest(
            id: "v2_in_pop_up", name: "Pop Up", iconName: "arrow.up.left.and.arrow.down.right",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            scaleXExpr: "$backOut", scaleYExpr: "$backOut", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "PopStudio", downloadsCount: 920, isVerified: true)
    )

    public static let inZoomPunch = AnimationPreset(
        id: "v2_in_zoom_punch", name: "Zoom Punch",
        description: "High-impact 2.2x slam to 1.0x with directional motion blur",
        phase: .inAnimation, tags: ["punch", "zoom", "impact"], previewBadge: "IMPACT",
        manifest: CreativeAnimationManifest(
            id: "v2_in_zoom_punch", name: "Zoom Punch", iconName: "plus.magnifyingglass",
            phase: .inAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 1.2 * $expoInv", scaleYExpr: "1.0 + 1.2 * $expoInv",
            opacityExpr: "$fadeFast", blurExpr: "14.0 * $expoInv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "VFXCore", downloadsCount: 760, isVerified: true)
    )

    public static let inElasticSlide = AnimationPreset(
        id: "v2_in_elastic_slide", name: "Elastic Slide",
        description: "Horizontal spring oscillation per word into position",
        phase: .inAnimation, tags: ["elastic", "slide", "kinetic"], previewBadge: "ELASTIC",
        manifest: CreativeAnimationManifest(
            id: "v2_in_elastic_slide", name: "Elastic Slide", iconName: "arrow.right.to.line.compact",
            phase: .inAnimation, defaultScope: .perWord, defaultStaggerDirection: .forward,
            offsetXExpr: "-1.0 * 180.0 * $elasticInv", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "PhysicsMotion", downloadsCount: 670, isVerified: true)
    )

    public static let inFlip3D = AnimationPreset(
        id: "v2_in_flip_3d", name: "3D Card Flip",
        description: "Characters flip 90 degrees into alignment around the vertical axis",
        phase: .inAnimation, tags: ["flip", "3d", "card"], previewBadge: "3D FLIP",
        manifest: CreativeAnimationManifest(
            id: "v2_in_flip_3d", name: "3D Card Flip", iconName: "rotate.3d",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            scaleXExpr: "$circOut", perspectiveYExpr: "0.8 * $expoInv", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "SpatialLab", downloadsCount: 810, isVerified: true)
    )

    public static let inRandomPop = AnimationPreset(
        id: "v2_in_random_pop", name: "Random Pop",
        description: "Characters pop in unpredictably in randomized order",
        phase: .inAnimation, tags: ["random", "pop", "scatter"], previewBadge: "RANDOM",
        manifest: CreativeAnimationManifest(
            id: "v2_in_random_pop", name: "Random Pop", iconName: "dice",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .random,
            scaleXExpr: "$backOut", scaleYExpr: "$backOut", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "RandomArts", downloadsCount: 710, isVerified: true)
    )

    public static let inWaveRise = AnimationPreset(
        id: "v2_in_wave_rise", name: "Wave Rise",
        description: "Undulating left-to-right staggered vertical rise across characters",
        phase: .inAnimation, tags: ["wave", "rise", "stagger"], previewBadge: "WAVE",
        manifest: CreativeAnimationManifest(
            id: "v2_in_wave_rise", name: "Wave Rise", iconName: "water.waves.and.arrow.up",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            offsetYExpr: "-1.0 * 35.0 * $expoInv + 15.0 * $i * $expoInv", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "WaveForm", downloadsCount: 840, isVerified: true)
    )

    public static let inScatterAssemble = AnimationPreset(
        id: "v2_in_scatter_assemble", name: "Scatter Assemble",
        description: "Scattered characters converge dynamically from random directions",
        phase: .inAnimation, tags: ["scatter", "assemble", "particle"], previewBadge: "SCATTER",
        manifest: CreativeAnimationManifest(
            id: "v2_in_scatter_assemble", name: "Scatter Assemble", iconName: "bubbles.and.sparkles",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .centerOut,
            offsetXExpr: "120.0 * $rand * $expoInv", offsetYExpr: "90.0 * $alt * $expoInv",
            rotationExpr: "30.0 * $rand * $expoInv", opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "ParticleX", downloadsCount: 890, isVerified: true)
    )

    public static let inTrackingIn = AnimationPreset(
        id: "v2_in_tracking_in", name: "Tracking In",
        description: "Wide character spacing tightens smoothly while fading in",
        phase: .inAnimation, tags: ["tracking", "spacing", "cinematic"], previewBadge: "TRACKING",
        manifest: CreativeAnimationManifest(
            id: "v2_in_tracking_in", name: "Tracking In", iconName: "arrow.left.and.line.vertical.and.arrow.right",
            phase: .inAnimation, defaultScope: .wholeBlock,
            opacityExpr: "$expoOut", trackingExpr: "28.0 * $expoInv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "TypographyPro", downloadsCount: 930, isVerified: true)
    )

    public static let inWipeReveal = AnimationPreset(
        id: "v2_in_wipe_reveal", name: "Wipe Reveal",
        description: "Smooth linear mask sweeps horizontally from left to right",
        phase: .inAnimation, tags: ["wipe", "reveal", "linear"], previewBadge: "WIPE",
        manifest: CreativeAnimationManifest(
            id: "v2_in_wipe_reveal", name: "Wipe Reveal", iconName: "square.lefthalf.filled",
            phase: .inAnimation, defaultScope: .wholeBlock,
            opacityExpr: "1.0", revealExpr: "$smooth"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "WipeLab", downloadsCount: 940, isVerified: true)
    )

    public static let inGlowIgnite = AnimationPreset(
        id: "v2_in_glow_ignite", name: "Glow Ignite",
        description: "Bright neon flare ignites and settles to standard glow intensity",
        phase: .inAnimation, tags: ["glow", "ignite", "neon", "flash"], previewBadge: "NEON",
        manifest: CreativeAnimationManifest(
            id: "v2_in_glow_ignite", name: "Glow Ignite", iconName: "sun.max.fill",
            phase: .inAnimation, defaultScope: .wholeBlock,
            opacityExpr: "$fadeFast", glowExpr: "1.0 + 1.5 * $expoInv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "NeonNight", downloadsCount: 780, isVerified: true)
    )

    public static let inTypewriter = AnimationPreset(
        id: "v2_in_typewriter", name: "Typewriter",
        description: "Classic character-by-character typewriter reveal",
        phase: .inAnimation, tags: ["typewriter", "classic", "retro"], previewBadge: "TYPE",
        manifest: CreativeAnimationManifest(
            id: "v2_in_typewriter", name: "Typewriter", iconName: "keyboard",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            opacityExpr: "$p"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "RetroVibe", downloadsCount: 960, isVerified: true)
    )

    public static let inScrambleDecode = AnimationPreset(
        id: "v2_in_scramble_decode", name: "Scramble Decode",
        description: "Digital pixel grains decode and coalesce into clean typography",
        phase: .inAnimation, tags: ["scramble", "decode", "cyber", "matrix"], previewBadge: "CYBER",
        manifest: CreativeAnimationManifest(
            id: "v2_in_scramble_decode", name: "Scramble Decode", iconName: "lock.open.fill",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            opacityExpr: "$expoOut", pixelateExpr: "8.0 * $expoInv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "MatrixCode", downloadsCount: 820, isVerified: true)
    )
}
