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
        description: "Trôi nhẹ xuống dưới êm ái kết hợp mờ dần bằng Exponential Ease-In",
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
        description: "Dòng chữ tan biến dần vào hiệu ứng nhòe mờ điện ảnh sâu lắng",
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
        description: "Phóng to vút về phía trước màn hình kèm hiệu ứng mờ tan biến",
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
        description: "Từng ký tự co nhỏ lại và biến mất với gia tốc nảy lùi",
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
        description: "Lật 3D quanh trục dọc 90 độ quay đi và tan biến",
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
        description: "Các ký tự phát nổ phân tán văng ra các hướng ngẫu nhiên",
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
        description: "Các ký tự co rút khoảng cách dồn chặt về trung tâm",
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
        description: "Mặt nạ quét tuyến tính đóng dần dòng chữ từ trái sang phải",
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
        description: "Hào quang neon lóe sáng chói lòa rồi vụt tắt vào bóng tối",
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
        description: "Xóa lùi từng ký tự từ phải sang trái theo thứ tự ngược",
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
