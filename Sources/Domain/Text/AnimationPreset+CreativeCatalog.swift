import Foundation

extension AnimationPreset {
    /// Bộ sưu tập 15 Gói Hoạt Ảnh Sáng Tạo Mở (5 In + 5 Out + 5 Loop) thế hệ mới
    public static let systemTemplates: [AnimationPreset] = inCatalog + outCatalog + loopCatalog

    public static let inCatalog: [AnimationPreset] = [
        inElasticJellyDrop, inVortexSpin3D, inGlitchTeleport, inFlipCascade3D, inHyperWhipBlur
    ]

    public static let outCatalog: [AnimationPreset] = [
        outCRTCollapse, outPixelDisintegrate, outGravityShatter, outBlackholeImplode, outSupersonicWhip
    ]

    // MARK: - 5 GÓI IN ANIMATION (XUẤT HIỆN)

    public static let inElasticJellyDrop = AnimationPreset(
        id: "creative_anim_in_jelly_drop",
        name: "Jelly Drop",
        description: "Rơi đàn hồi từng ký tự từ trên cao kèm biến dạng Squash & Stretch khi tiếp đất",
        phase: .inAnimation,
        tags: ["jelly", "drop", "bounce", "elastic"],
        previewBadge: "PHYSICS",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_in_jelly_drop", name: "Jelly Drop", iconName: "arrow.down.to.line.compact",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            customParameters: [
                CustomParameterDescriptor(id: "dropHeight", title: "Độ cao thả rơi", minValue: 40.0, maxValue: 320.0, defaultValue: 160.0, step: 10.0, unit: "px"),
                CustomParameterDescriptor(id: "squashForce", title: "Độ nảy Jelly", minValue: 0.0, maxValue: 0.8, defaultValue: 0.35, step: 0.05, unit: "x")
            ],
            offsetYExpr: "-1.0 * $param.dropHeight * $bounceInv",
            scaleXExpr: "1.0 + $param.squashForce * $jellyWave",
            scaleYExpr: "1.0 - 0.8 * $param.squashForce * $jellyWave",
            opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "PhysicsMotion", downloadsCount: 840, isVerified: true)
    )

    public static let inVortexSpin3D = AnimationPreset(
        id: "creative_anim_in_vortex_spin",
        name: "Vortex Spin",
        description: "Từng ký tự bay xoắn ốc từ xa hội tụ về tâm kèm góc xoay không gian",
        phase: .inAnimation,
        tags: ["vortex", "spin", "spiral", "3d"],
        previewBadge: "3D SPIN",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_in_vortex_spin", name: "Vortex Spin", iconName: "hurricane",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .centerOut,
            customParameters: [
                CustomParameterDescriptor(id: "spinAngle", title: "Góc xoáy vào", minValue: 45.0, maxValue: 720.0, defaultValue: 240.0, step: 15.0, unit: "deg"),
                CustomParameterDescriptor(id: "vortexOffset", title: "Bán kính xoắn", minValue: 20.0, maxValue: 260.0, defaultValue: 120.0, step: 10.0, unit: "px")
            ],
            offsetXExpr: "$param.vortexOffset * $springInv",
            offsetYExpr: "0.6 * $param.vortexOffset * $springInv",
            scaleXExpr: "0.3 + 0.7 * $smooth",
            scaleYExpr: "0.3 + 0.7 * $smooth",
            rotationExpr: "$param.spinAngle * $springInv",
            opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "VortexLab", downloadsCount: 620, isVerified: true)
    )

    public static let inGlitchTeleport = AnimationPreset(
        id: "creative_anim_in_glitch_teleport",
        name: "Glitch Teleport",
        description: "Dịch chuyển tức thời kèm tách kênh màu RGB Glitch và hội tụ hạt Pixel",
        phase: .inAnimation,
        tags: ["glitch", "teleport", "cyber", "rgb"],
        previewBadge: "SHADER",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_in_glitch_teleport", name: "Glitch Teleport", iconName: "bolt.horizontal.fill",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .random,
            customParameters: [
                CustomParameterDescriptor(id: "glitchOffset", title: "Cường độ giật RGB", minValue: 2.0, maxValue: 20.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "pixelStart", title: "Cỡ hạt Pixel đầu", minValue: 0.0, maxValue: 40.0, defaultValue: 18.0, step: 2.0, unit: "px")
            ],
            offsetXExpr: "28.0 * $glitchWave * $inv",
            opacityExpr: "$fadeFast",
            rgbSplitExpr: "$param.glitchOffset * $inv",
            pixelateExpr: "$param.pixelStart * $inv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "CyberMotion", downloadsCount: 790, isVerified: true)
    )

    public static let inFlipCascade3D = AnimationPreset(
        id: "creative_anim_in_flip_cascade",
        name: "3D Flip Cascade",
        description: "Lật nghiêng thẻ chữ 3D quanh trục ngang lan truyền từ tâm ra hai biên",
        phase: .inAnimation,
        tags: ["3d", "flip", "cascade", "cinema"],
        previewBadge: "3D FLIP",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_in_flip_cascade", name: "3D Flip Cascade", iconName: "rotate.3d.fill",
            phase: .inAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .centerOut,
            customParameters: [
                CustomParameterDescriptor(id: "flipAngle", title: "Độ nghiêng lật 3D", minValue: 0.2, maxValue: 1.5, defaultValue: 0.95, step: 0.05, unit: "rad"),
                CustomParameterDescriptor(id: "riseOffset", title: "Độ nâng chân chữ", minValue: 0.0, maxValue: 160.0, defaultValue: 65.0, step: 5.0, unit: "px")
            ],
            offsetYExpr: "$param.riseOffset * $springInv",
            scaleYExpr: "0.25 + 0.75 * $smooth",
            perspectiveXExpr: "$param.flipAngle * $springInv",
            opacityExpr: "$fadeFast"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Cinema3D", downloadsCount: 560, isVerified: true)
    )

    public static let inHyperWhipBlur = AnimationPreset(
        id: "creative_anim_in_hyper_whip",
        name: "Hyper Whip",
        description: "Lao vút tốc độ cao từ biên trái kèm nghiêng quán tính Skew và vệt mờ Motion Blur",
        phase: .inAnimation,
        tags: ["whip", "speed", "blur", "skew"],
        previewBadge: "VELOCITY",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_in_hyper_whip", name: "Hyper Whip", iconName: "wind",
            phase: .inAnimation, defaultScope: .perWord, defaultStaggerDirection: .forward,
            customParameters: [
                CustomParameterDescriptor(id: "whipDistance", title: "Quãng đường phóng", minValue: 80.0, maxValue: 480.0, defaultValue: 260.0, step: 20.0, unit: "px"),
                CustomParameterDescriptor(id: "skewAngle", title: "Độ nghiêng quán tính", minValue: 0.0, maxValue: 0.8, defaultValue: 0.38, step: 0.05, unit: "rad")
            ],
            offsetXExpr: "-1.0 * $param.whipDistance * $springInv",
            skewXExpr: "-1.0 * $param.skewAngle * $inv",
            opacityExpr: "$fadeFast",
            blurExpr: "14.0 * $inv"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "VelocityFX", downloadsCount: 680, isVerified: true)
    )

    // MARK: - 5 GÓI OUT ANIMATION (BIẾN MẤT)

    public static let outCRTCollapse = AnimationPreset(
        id: "creative_anim_out_crt_collapse",
        name: "CRT Collapse",
        description: "Thu hẹp màn hình vô tuyến CRT thành tia sáng ngang kèm chớp RGB rồi vụt tắt",
        phase: .outAnimation,
        tags: ["crt", "tv", "collapse", "retro"],
        previewBadge: "RETRO TV",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_out_crt_collapse", name: "CRT Collapse", iconName: "tv.slash",
            phase: .outAnimation, defaultScope: .wholeBlock,
            customParameters: [
                CustomParameterDescriptor(id: "rgbFlash", title: "Độ chớp RGB khi tắt", minValue: 0.0, maxValue: 20.0, defaultValue: 12.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "horizontalStretch", title: "Độ giãn vệt tia ngang", minValue: 0.0, maxValue: 1.0, defaultValue: 0.45, step: 0.05, unit: "x")
            ],
            scaleXExpr: "1.0 + $param.horizontalStretch * $exit",
            scaleYExpr: "0.02 + 0.98 * $p",
            opacityExpr: "$p",
            rgbSplitExpr: "$param.rgbFlash * $exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "AnalogTape Co.", downloadsCount: 610, isVerified: true)
    )

    public static let outPixelDisintegrate = AnimationPreset(
        id: "creative_anim_out_pixel_dissolve",
        name: "Pixel Dissolve",
        description: "Tan biến thành các hạt Pixel 8-bit bay bổng lên không trung",
        phase: .outAnimation,
        tags: ["pixel", "dissolve", "8bit", "vapor"],
        previewBadge: "8-BIT",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_out_pixel_dissolve", name: "Pixel Dissolve", iconName: "square.grid.3x3.topleft.filled",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            customParameters: [
                CustomParameterDescriptor(id: "maxPixelSize", title: "Cỡ hạt Pixel tan biến", minValue: 4.0, maxValue: 48.0, defaultValue: 24.0, step: 2.0, unit: "px"),
                CustomParameterDescriptor(id: "floatUp", title: "Độ bay bổng lên", minValue: 0.0, maxValue: 200.0, defaultValue: 85.0, step: 10.0, unit: "px")
            ],
            offsetYExpr: "-1.0 * $param.floatUp * $exitQuad",
            opacityExpr: "$p",
            pixelateExpr: "$param.maxPixelSize * $exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "RetroStudio", downloadsCount: 530, isVerified: true)
    )

    public static let outGravityShatter = AnimationPreset(
        id: "creative_anim_out_gravity_fall",
        name: "Gravity Shatter",
        description: "Từng con chữ rơi tự do theo gia tốc trọng trường kèm xoay lật",
        phase: .outAnimation,
        tags: ["gravity", "drop", "shatter", "fall"],
        previewBadge: "GRAVITY",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_out_gravity_fall", name: "Gravity Shatter", iconName: "arrow.down.right.and.arrow.up.left",
            phase: .outAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .edgesIn,
            customParameters: [
                CustomParameterDescriptor(id: "fallDistance", title: "Quãng đường rơi", minValue: 60.0, maxValue: 360.0, defaultValue: 210.0, step: 15.0, unit: "px"),
                CustomParameterDescriptor(id: "tumbleAngle", title: "Góc xoay rơi tự do", minValue: 0.0, maxValue: 180.0, defaultValue: 65.0, step: 5.0, unit: "deg")
            ],
            offsetYExpr: "$param.fallDistance * $exitQuad",
            rotationExpr: "$param.tumbleAngle * $exitQuad",
            opacityExpr: "$p",
            blurExpr: "8.0 * $exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "PhysicsMotion", downloadsCount: 580, isVerified: true)
    )

    public static let outBlackholeImplode = AnimationPreset(
        id: "creative_anim_out_blackhole",
        name: "Blackhole Implode",
        description: "Xoay xoắn ốc thu nhỏ hút toàn bộ khối chữ vào tâm hố đen",
        phase: .outAnimation,
        tags: ["blackhole", "implode", "vortex", "zoom"],
        previewBadge: "IMPLODE",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_out_blackhole", name: "Blackhole Implode", iconName: "tornado",
            phase: .outAnimation, defaultScope: .wholeBlock,
            customParameters: [
                CustomParameterDescriptor(id: "implodeSpin", title: "Góc xoáy hút vào tâm", minValue: 30.0, maxValue: 540.0, defaultValue: 180.0, step: 15.0, unit: "deg"),
                CustomParameterDescriptor(id: "outBlur", title: "Độ nhòe hướng tâm", minValue: 0.0, maxValue: 24.0, defaultValue: 10.0, step: 1.0, unit: "px")
            ],
            scaleXExpr: "$p",
            scaleYExpr: "$p",
            rotationExpr: "$param.implodeSpin * $exitQuad",
            opacityExpr: "$p",
            blurExpr: "$param.outBlur * $exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "VortexLab", downloadsCount: 490, isVerified: true)
    )

    public static let outSupersonicWhip = AnimationPreset(
        id: "creative_anim_out_supersonic_whip",
        name: "Supersonic Whip",
        description: "Phóng vút siêu thanh sang biên phải kèm nghiêng khí động học và vệt mờ",
        phase: .outAnimation,
        tags: ["whip", "supersonic", "exit", "blur"],
        previewBadge: "MACH 2",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_out_supersonic_whip", name: "Supersonic Whip", iconName: "hare.fill",
            phase: .outAnimation, defaultScope: .perWord, defaultStaggerDirection: .backward,
            customParameters: [
                CustomParameterDescriptor(id: "exitDistance", title: "Cự ly văng phải", minValue: 100.0, maxValue: 500.0, defaultValue: 300.0, step: 20.0, unit: "px"),
                CustomParameterDescriptor(id: "exitBlur", title: "Độ nhòe siêu thanh", minValue: 0.0, maxValue: 24.0, defaultValue: 14.0, step: 1.0, unit: "px")
            ],
            offsetXExpr: "$param.exitDistance * $exitQuad",
            skewXExpr: "0.42 * $exit",
            opacityExpr: "$p",
            blurExpr: "$param.exitBlur * $exit"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "VelocityFX", downloadsCount: 615, isVerified: true)
    )
}
