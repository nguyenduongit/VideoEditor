import Foundation

extension AnimationPreset {
    public static let loopCatalogV2: [AnimationPreset] = [
        loopFloat, loopBreathe, loopWiggle, loopRubberBand,
        loopGlitchBurst, loopCharWave, loopRainbowHue,
        loopShimmer, loopGlowPulse, loopTilt3D
    ]

    // MARK: - 10 GÓI LOOP ANIMATION V2

    public static let loopFloat = AnimationPreset(
        id: "v2_loop_float", name: "Float",
        description: "Bồng bềnh nhẹ nhàng theo phương thẳng đứng với đường cong Sine êm ái",
        phase: .loopAnimation, tags: ["float", "ambient", "levitate"], previewBadge: "FLOAT",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_float", name: "Float", iconName: "arrow.up.and.down",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            offsetYExpr: "12.0 * $floatWave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "AmbientLab", downloadsCount: 920, isVerified: true)
    )

    public static let loopBreathe = AnimationPreset(
        id: "v2_loop_breathe", name: "Breathe",
        description: "Phóng to thu nhỏ 4% nhịp nhàng tạo cảm giác dòng chữ đang thở",
        phase: .loopAnimation, tags: ["breathe", "pulse", "organic"], previewBadge: "BREATHE",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_breathe", name: "Breathe", iconName: "lungs.fill",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 0.04 * $breathe * $blend", scaleYExpr: "1.0 + 0.04 * $breathe * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "OrganicMotion", downloadsCount: 880, isVerified: true)
    )

    public static let loopWiggle = AnimationPreset(
        id: "v2_loop_wiggle", name: "Wiggle",
        description: "Rung lắc vi mô góc nghiêng và toạ độ tạo điểm nhấn tinh nghịch",
        phase: .loopAnimation, tags: ["wiggle", "shake", "playful"], previewBadge: "WIGGLE",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_wiggle", name: "Wiggle", iconName: "waveform.path",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            offsetXExpr: "4.0 * $cosWave * $blend", rotationExpr: "3.5 * $wave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "PlayMotion", downloadsCount: 750, isVerified: true)
    )

    public static let loopRubberBand = AnimationPreset(
        id: "v2_loop_rubber_band", name: "Rubber Band",
        description: "Co giãn đàn hồi xen kẽ hai trục X và Y như dây thun nhịp nhàng",
        phase: .loopAnimation, tags: ["rubber", "elastic", "stretch"], previewBadge: "ELASTIC",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_rubber_band", name: "Rubber Band", iconName: "arrow.left.and.right",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 0.08 * $wave * $blend", scaleYExpr: "1.0 - 0.06 * $wave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "PhysicsMotion", downloadsCount: 810, isVerified: true)
    )

    public static let loopGlitchBurst = AnimationPreset(
        id: "v2_loop_glitch_burst", name: "Glitch Burst",
        description: "Tách kênh màu RGB giật ngắt quãng theo nhịp điệu Cyberpunk",
        phase: .loopAnimation, tags: ["glitch", "burst", "rgb", "cyber"], previewBadge: "GLITCH",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_glitch_burst", name: "Glitch Burst", iconName: "bolt.badge.automatic",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            rgbSplitExpr: "6.0 * $pulse * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "CyberFX", downloadsCount: 860, isVerified: true)
    )

    public static let loopCharWave = AnimationPreset(
        id: "v2_loop_char_wave", name: "Char Wave",
        description: "Sóng tuần hoàn nhấp nhô chạy dọc qua từng ký tự",
        phase: .loopAnimation, tags: ["wave", "char", "ocean", "harmonic"], previewBadge: "WAVE",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_char_wave", name: "Char Wave", iconName: "water.waves",
            phase: .loopAnimation, defaultScope: .perCharacter, defaultStaggerDirection: .forward,
            offsetYExpr: "14.0 * $wave * $blend", rotationExpr: "5.0 * $cosWave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "WaveForm", downloadsCount: 910, isVerified: true)
    )

    public static let loopRainbowHue = AnimationPreset(
        id: "v2_loop_rainbow_hue", name: "Rainbow Hue",
        description: "Chu kỳ đổi màu cầu vồng 360 độ rực rỡ và lấp lánh",
        phase: .loopAnimation, tags: ["rainbow", "hue", "color", "chromatic"], previewBadge: "RAINBOW",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_rainbow_hue", name: "Rainbow Hue", iconName: "paintpalette.fill",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            hueExpr: "360.0 * $breathe * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "ColorLab", downloadsCount: 870, isVerified: true)
    )

    public static let loopShimmer = AnimationPreset(
        id: "v2_loop_shimmer", name: "Shimmer",
        description: "Vệt sáng specular highlight quét qua bề mặt định kỳ",
        phase: .loopAnimation, tags: ["shimmer", "shine", "sweep"], previewBadge: "SHINE",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_shimmer", name: "Shimmer", iconName: "sparkle",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            scaleXExpr: "1.0 + 0.02 * $pulse * $blend", glowExpr: "0.5 + 1.2 * $pulse * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "ShineStudio", downloadsCount: 890, isVerified: true)
    )

    public static let loopGlowPulse = AnimationPreset(
        id: "v2_loop_glow_pulse", name: "Glow Pulse",
        description: "Vầng hào quang neon thở nhịp nhàng bừng sáng",
        phase: .loopAnimation, tags: ["glow", "pulse", "neon"], previewBadge: "NEON",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_glow_pulse", name: "Glow Pulse", iconName: "light.beacon.max.fill",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            glowExpr: "0.4 + 1.6 * $breathe * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "NeonNight", downloadsCount: 940, isVerified: true)
    )

    public static let loopTilt3D = AnimationPreset(
        id: "v2_loop_tilt_3d", name: "3D Tilt",
        description: "Nghiêng phối cảnh 3 chiều lượn êm ái tạo chiều sâu",
        phase: .loopAnimation, tags: ["tilt", "3d", "spatial", "depth"], previewBadge: "3D TILT",
        manifest: CreativeAnimationManifest(
            id: "v2_loop_tilt_3d", name: "3D Tilt", iconName: "view.3d",
            phase: .loopAnimation, defaultScope: .wholeBlock,
            perspectiveXExpr: "0.25 * $wave * $blend", perspectiveYExpr: "0.25 * $cosWave * $blend"
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "pro_motion", authorName: "SpatialLab", downloadsCount: 830, isVerified: true)
    )
}
