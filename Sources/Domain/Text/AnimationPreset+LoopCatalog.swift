import Foundation

extension AnimationPreset {
    public static let loopCatalog: [AnimationPreset] = [
        loopHarmonicWave, loopBassHeartbeat, loopPendulum3D, loopNeonFlicker, loopJellySquash
    ]

    // MARK: - 5 GÓI LOOP ANIMATION (VÒNG LẶP)

    public static let loopHarmonicWave = AnimationPreset(
        id: "creative_anim_loop_harmonic_wave",
        name: "Harmonic Wave",
        description: "Lượn sóng sin từng ký tự mềm mại kèm góc nghiêng theo pha",
        phase: .loopAnimation,
        tags: ["wave", "harmonic", "float", "ocean"],
        previewBadge: "SINE WAVE",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_loop_harmonic_wave", name: "Harmonic Wave", iconName: "water.waves",
            phase: .loopAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            customParameters: [
                CustomParameterDescriptor(id: "waveHeight", title: "Biên độ đỉnh sóng", minValue: 2.0, maxValue: 45.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "waveTilt", title: "Độ nghiêng lướt sóng", minValue: 0.0, maxValue: 18.0, defaultValue: 4.5, step: 0.5, unit: "deg")
            ],
            offsetYExpr: "$param.waveHeight * $wave * $blend",
            rotationExpr: "$param.waveTilt * $cosWave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "WaveForm Studio", downloadsCount: 740, isVerified: true)
    )

    public static let loopBassHeartbeat = AnimationPreset(
        id: "creative_anim_loop_bass_heartbeat",
        name: "Bass Heartbeat",
        description: "Nảy phóng to theo nhịp trống Bass EDM kèm tách kênh màu RGB",
        phase: .loopAnimation,
        tags: ["bass", "heartbeat", "edm", "pulse"],
        previewBadge: "EDM BEAT",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_loop_bass_heartbeat", name: "Bass Heartbeat", iconName: "waveform.path.ecg",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            customParameters: [
                CustomParameterDescriptor(id: "beatScale", title: "Độ nảy nhịp Bass", minValue: 0.04, maxValue: 0.45, defaultValue: 0.18, step: 0.02, unit: "x"),
                CustomParameterDescriptor(id: "beatRGB", title: "Tách màu RGB theo nhịp", minValue: 0.0, maxValue: 18.0, defaultValue: 7.0, step: 0.5, unit: "px")
            ],
            scaleXExpr: "1.0 + $param.beatScale * $pulse * $blend",
            scaleYExpr: "1.0 + $param.beatScale * $pulse * $blend",
            rgbSplitExpr: "$param.beatRGB * $pulse * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "ClubVisuals", downloadsCount: 890, isVerified: true)
    )

    public static let loopPendulum3D = AnimationPreset(
        id: "creative_anim_loop_pendulum_3d",
        name: "3D Pendulum",
        description: "Đung đưa con lắc đồng hồ kết hợp xoay nghiêng phối cảnh 3D",
        phase: .loopAnimation,
        tags: ["pendulum", "swing", "3d", "sway"],
        previewBadge: "3D SWAY",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_loop_pendulum_3d", name: "3D Pendulum", iconName: "metronome.fill",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            customParameters: [
                CustomParameterDescriptor(id: "swingAngle", title: "Biên độ góc lắc", minValue: 2.0, maxValue: 30.0, defaultValue: 9.0, step: 1.0, unit: "deg"),
                CustomParameterDescriptor(id: "swayX", title: "Độ đưa ngang", minValue: 0.0, maxValue: 60.0, defaultValue: 18.0, step: 2.0, unit: "px")
            ],
            offsetXExpr: "$param.swayX * $wave * $blend",
            rotationExpr: "$param.swingAngle * $wave * $blend",
            perspectiveYExpr: "0.35 * $cosWave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Cinema3D", downloadsCount: 510, isVerified: true)
    )

    public static let loopNeonFlicker = AnimationPreset(
        id: "creative_anim_loop_neon_flicker",
        name: "Neon Flicker",
        description: "Đèn ống Neon cao áp nhấp nháy kèm rung giật nhẹ ngang",
        phase: .loopAnimation,
        tags: ["neon", "flicker", "cyber", "strobe"],
        previewBadge: "CYBER",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_loop_neon_flicker", name: "Neon Flicker", iconName: "bolt.fill",
            phase: .loopAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .random,
            customParameters: [
                CustomParameterDescriptor(id: "flickerDepth", title: "Độ sụt áp nhấp nháy", minValue: 0.1, maxValue: 0.85, defaultValue: 0.45, step: 0.05, unit: "x"),
                CustomParameterDescriptor(id: "glitchJitter", title: "Độ rung điện từ", minValue: 0.0, maxValue: 12.0, defaultValue: 3.5, step: 0.5, unit: "px")
            ],
            offsetXExpr: "$param.glitchJitter * $glitchWave * $blend",
            opacityExpr: "1.0 - $param.flickerDepth * $pulse * $blend",
            rgbSplitExpr: "5.0 * $pulse * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "NeonType Studio", downloadsCount: 670, isVerified: true)
    )

    public static let loopJellySquash = AnimationPreset(
        id: "creative_anim_loop_jelly_bounce",
        name: "Jelly Squash",
        description: "Co giãn đối xứng trục X/Y như thạch rau câu nảy theo chu kỳ",
        phase: .loopAnimation,
        tags: ["jelly", "squash", "stretch", "cartoon"],
        previewBadge: "CARTOON",
        manifest: CreativeAnimationManifest(
            id: "creative_anim_loop_jelly_bounce", name: "Jelly Squash", iconName: "circle.hexagongrid.fill",
            phase: .loopAnimation, defaultScope: .perWord, defaultStaggerDirection: .forward,
            customParameters: [
                CustomParameterDescriptor(id: "jellyAmount", title: "Biên độ co giãn Jelly", minValue: 0.05, maxValue: 0.45, defaultValue: 0.20, step: 0.05, unit: "x"),
                CustomParameterDescriptor(id: "hopHeight", title: "Độ nảy lên xuống", minValue: 0.0, maxValue: 36.0, defaultValue: 10.0, step: 2.0, unit: "px")
            ],
            offsetYExpr: "-1.0 * $param.hopHeight * $pulse * $blend",
            scaleXExpr: "1.0 + $param.jellyAmount * $wave * $blend",
            scaleYExpr: "1.0 - 0.85 * $param.jellyAmount * $wave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "PhysicsMotion", downloadsCount: 720, isVerified: true)
    )
}

