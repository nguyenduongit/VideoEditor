import Foundation

extension AnimationPreset {
    public static let outCatalogV2: [AnimationPreset] = [
        outSoftSink, outBlurOut, outZoomAway, outShrinkPop,
        outFlipAway, outScatterExplode, outTrackingCollapse,
        outWipeOut, outGlowBurn, outBackspace
    ]

    // MARK: - 10 GÓI OUT ANIMATION V2

    public static let outSoftSink = AnimationPreset(
        id: "v2_out_soft_sink", name: "Soft Sink",
        description: "Drifts downward gently while fading out with exponential ease-in",
        phase: .outAnimation, tags: ["soft", "sink", "smooth", "minimal"], previewBadge: "SMOOTH",
        manifest: CreativeAnimationManifest(
            id: "v2_out_soft_sink", name: "Soft Sink", iconName: "arrow.down.circle",
            phase: .outAnimation, defaultScope: .perWord, defaultStaggerDirection: .forward,
            offsetYExpr: "24.0 * $expoIn", opacityExpr: "$exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "StudioMotion", downloadsCount: 910, isVerified: true)
    )

    public static let outBlurOut = AnimationPreset(
        id: "v2_out_blur_out", name: "Blur Out",
        description: "Dissolves seamlessly into deep cinematic optical blur",
        phase: .outAnimation, tags: ["blur", "fade", "cinematic"], previewBadge: "CINEMA",
        manifest: CreativeAnimationManifest(
            id: "v2_out_blur_out", name: "Blur Out", iconName: "camera.filters",
            phase: .outAnimation, defaultScope: .wholeBlock,
            opacityExpr: "$exitQuad", blurExpr: "22.0 * $exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "OpticsLab", downloadsCount: 880, isVerified: true)
    )

    public static let outZoomAway = AnimationPreset(
        id: "v2_out_zoom_away", name: "Zoom Away",
        description: "Rushes forward toward the camera with fading motion blur",
        phase: .outAnimation, tags: ["zoom", "rush", "impact"], previewBadge: "ZOOM",
        manifest: CreativeAnimationManifest(
            id: "v2_out_zoom_away", name: "Zoom Away", iconName: "plus.magnifyingglass",
            phase: .outAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 1.4 * $exitQuad", scaleYExpr: "1.0 + 1.4 * $exitQuad",
            opacityExpr: "$exitQuad", blurExpr: "12.0 * $exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "VFXCore", downloadsCount: 850, isVerified: true)
    )

    public static let outShrinkPop = AnimationPreset(
        id: "v2_out_shrink_pop", name: "Shrink Pop",
        description: "Characters shrink down and disappear with an anticipate bounce",
        phase: .outAnimation, tags: ["shrink", "pop", "back"], previewBadge: "POP",
        manifest: CreativeAnimationManifest(
            id: "v2_out_shrink_pop", name: "Shrink Pop", iconName: "arrow.down.right.and.arrow.up.left",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .backward,
            scaleXExpr: "$backIn", scaleYExpr: "$backIn", opacityExpr: "$exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "PopStudio", downloadsCount: 820, isVerified: true)
    )

    public static let outFlipAway = AnimationPreset(
        id: "v2_out_flip_away", name: "Flip Away",
        description: "Turns 90 degrees around the vertical axis and vanishes",
        phase: .outAnimation, tags: ["flip", "3d", "card"], previewBadge: "3D FLIP",
        manifest: CreativeAnimationManifest(
            id: "v2_out_flip_away", name: "Flip Away", iconName: "rotate.3d",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .backward,
            scaleXExpr: "$circInv", perspectiveYExpr: "0.9 * $exitQuad", opacityExpr: "$exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "SpatialLab", downloadsCount: 790, isVerified: true)
    )

    public static let outScatterExplode = AnimationPreset(
        id: "v2_out_scatter_explode", name: "Scatter Explode",
        description: "Characters scatter outward explosively in random trajectories",
        phase: .outAnimation, tags: ["scatter", "explode", "particle"], previewBadge: "EXPLODE",
        manifest: CreativeAnimationManifest(
            id: "v2_out_scatter_explode", name: "Scatter Explode", iconName: "sparkles",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .centerOut,
            offsetXExpr: "150.0 * $rand * $exitQuad", offsetYExpr: "110.0 * $alt * $exitQuad",
            rotationExpr: "45.0 * $rand * $exitQuad", opacityExpr: "$exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "ParticleX", downloadsCount: 940, isVerified: true)
    )

    public static let outTrackingCollapse = AnimationPreset(
        id: "v2_out_tracking_collapse", name: "Tracking Collapse",
        description: "Letter spacing collapses inward toward the center while fading",
        phase: .outAnimation, tags: ["tracking", "collapse", "spacing"], previewBadge: "TRACKING",
        manifest: CreativeAnimationManifest(
            id: "v2_out_tracking_collapse", name: "Tracking Collapse", iconName: "arrow.right.and.line.vertical.and.arrow.left",
            phase: .outAnimation, defaultScope: .wholeBlock,
            opacityExpr: "$exitQuad", trackingExpr: "-1.0 * 20.0 * $exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "TypographyPro", downloadsCount: 860, isVerified: true)
    )

    public static let outWipeOut = AnimationPreset(
        id: "v2_out_wipe_out", name: "Wipe Out",
        description: "Linear mask sweeps closed across the line from left to right",
        phase: .outAnimation, tags: ["wipe", "linear", "mask"], previewBadge: "WIPE",
        manifest: CreativeAnimationManifest(
            id: "v2_out_wipe_out", name: "Wipe Out", iconName: "square.righthalf.filled",
            phase: .outAnimation, defaultScope: .wholeBlock,
            opacityExpr: "1.0", revealExpr: "$exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "WipeLab", downloadsCount: 930, isVerified: true)
    )

    public static let outGlowBurn = AnimationPreset(
        id: "v2_out_glow_burn", name: "Glow Burn",
        description: "Neon halo flares brightly before burning out into darkness",
        phase: .outAnimation, tags: ["glow", "burn", "neon", "flare"], previewBadge: "NEON",
        manifest: CreativeAnimationManifest(
            id: "v2_out_glow_burn", name: "Glow Burn", iconName: "sun.max.fill",
            phase: .outAnimation, defaultScope: .wholeBlock,
            opacityExpr: "$exitQuad", glowExpr: "2.5 * $exitQuad"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "NeonNight", downloadsCount: 870, isVerified: true)
    )

    public static let outBackspace = AnimationPreset(
        id: "v2_out_backspace", name: "Backspace",
        description: "Deletes characters sequentially in reverse from right to left",
        phase: .outAnimation, tags: ["backspace", "delete", "retro"], previewBadge: "TYPE",
        manifest: CreativeAnimationManifest(
            id: "v2_out_backspace", name: "Backspace", iconName: "delete.left",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .backward,
            opacityExpr: "$p"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "RetroVibe", downloadsCount: 950, isVerified: true)
    )
}
