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
        description: "Từng từ trôi nhẹ từ dưới lên êm ái với gia tốc Exponential Ease-Out",
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
        description: "Toàn khối chữ lấy nét sắc nét từ hiệu ứng mờ nhòe điện ảnh",
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
        description: "Từng ký tự nảy vươn lên vượt ngưỡng rồi co về vị trí chuẩn cực nảy",
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
        description: "Phóng to đột ngột từ 2.2x lao về 1.0x kèm vệt mờ chuyển động mạnh mẽ",
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
        description: "Trượt ngang đàn hồi theo từng từ với đường cong dao động lò xo",
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
        description: "Từng ký tự lật 3D quanh trục dọc từ 90 độ về góc thẳng",
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
        description: "Các ký tự xuất hiện ngẫu nhiên không theo thứ tự thẳng",
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
        description: "Nhô cao lượn sóng từ trái qua phải theo pha ký tự",
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
        description: "Ký tự phân tán từ các hướng ngẫu nhiên hội tụ về vị trí chuẩn",
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
        description: "Khoảng cách ký tự từ rộng co về tiêu chuẩn kết hợp mờ dần",
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
        description: "Mặt nạ quét tuyến tính mở dòng chữ từ trái sang phải mượt mà",
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
        description: "Hào quang neon bùng cháy sáng chói rồi ổn định về độ sáng tiêu chuẩn",
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
        description: "Hiệu ứng máy đánh chữ xuất hiện từng ký tự kinh điển",
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
        description: "Giải mã ký tự số hạt pixel hội tụ về dòng chữ chuẩn",
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
