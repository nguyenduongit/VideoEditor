import Foundation

extension EffectPreset {
    /// Bộ sưu tập 8 Gói Hiệu Ứng Sáng Tạo Mở (Open Creative Shader & Pipeline Packages) thế hệ mới
    public static let systemTemplates: [EffectPreset] = [
        rgbGlitchPackage,
        vhsRetroTapePackage,
        comicHalftonePackage,
        kaleidoscopePackage,
        vortexTwirlPackage,
        anamorphicBloomPackage,
        pixelRetroArcadePackage,
        thermalVisionPackage,
        shockwaveRipplePackage
    ]

    public static let rgbGlitchPackage = EffectPreset(
        id: "creative_fx_rgb_glitch",
        name: "Tách Màu Cyber (RGB Glitch)",
        description: "Gói Shader tách kênh màu Đỏ - Xanh Cyan theo nhịp tần số sóng sin",
        category: .partyBeat,
        tags: ["glitch", "rgb", "cyber", "shader"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "rgbOffset", title: "Độ lệch kênh màu RGB", minValue: 0.0, maxValue: 45.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "pulseFreq", title: "Tần số nhịp giật", minValue: 1.0, maxValue: 20.0, defaultValue: 6.0, step: 0.5, unit: "Hz")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "RGBSplit",
                    parameterBindings: ["offset": "$param.rgbOffset * $intensity", "frequency": "$param.pulseFreq * $speed"]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "OpenShader Lab", downloadsCount: 480, isVerified: true)
    )

    public static let vhsRetroTapePackage = EffectPreset(
        id: "creative_fx_vhs_retro",
        name: "Băng Từ Cổ Điển (VHS Retro Tape)",
        description: "Gói Shader giả lập sọc nhiễu từ tính và lem màu analog thập niên 90",
        category: .cinematic,
        tags: ["vhs", "retro", "analog", "tape"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .cinematicBlur,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "scanlineStrength", title: "Độ gắt sọc từ VHS", minValue: 0.0, maxValue: 1.0, defaultValue: 0.55, step: 0.05, unit: "x"),
                CustomParameterDescriptor(id: "colorBleed", title: "Độ lem màu Chromatic", minValue: 0.0, maxValue: 28.0, defaultValue: 9.0, step: 0.5, unit: "px")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "VHSRetro",
                    parameterBindings: ["scanlineStrength": "$param.scanlineStrength * $intensity", "colorBleed": "$param.colorBleed * $intensity"]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "AnalogTape Co.", downloadsCount: 395, isVerified: true)
    )

    public static let comicHalftonePackage = EffectPreset(
        id: "creative_fx_comic_halftone",
        name: "Truyện Tranh (Comic Halftone)",
        description: "Chuyển hóa khung hình thành nét vẽ mực in và chấm bi Halftone",
        category: .partyBeat,
        tags: ["comic", "halftone", "manga", "popart"],
        previewBadge: "FX",
        config: EffectConfiguration(
            type: .whiteFlash,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "comicBlend", title: "Độ hòa trộn nét vẽ", minValue: 0.1, maxValue: 1.0, defaultValue: 0.9, step: 0.05, unit: "x")
            ],
            filterPipeline: [
                CreativeFilterStep(filterName: "CIComicEffect", parameterBindings: ["comicBlend": "$param.comicBlend * $intensity"])
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "PopArt Studio", downloadsCount: 310, isVerified: true)
    )

    public static let kaleidoscopePackage = EffectPreset(
        id: "creative_fx_kaleidoscope",
        name: "Kính Vạn Hoa (Kaleidoscope)",
        description: "Phản chiếu đối xứng đa giác xoay theo thời gian thực",
        category: .motionShake,
        tags: ["kaleidoscope", "mirror", "prism", "trippy"],
        previewBadge: "PRISM",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "tileCount", title: "Số cạnh lăng kính", minValue: 2.0, maxValue: 16.0, defaultValue: 6.0, step: 1.0, unit: "cạnh"),
                CustomParameterDescriptor(id: "rotationAngle", title: "Góc xoay đối xứng", minValue: 0.0, maxValue: 6.28, defaultValue: 0.85, step: 0.05, unit: "rad")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "CIKaleidoscope",
                    parameterBindings: ["inputCount": "$param.tileCount", "inputAngle": "$param.rotationAngle * $intensity"]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "PrismCraft", downloadsCount: 275, isVerified: true)
    )

    public static let vortexTwirlPackage = EffectPreset(
        id: "creative_fx_vortex_twirl",
        name: "Xoáy Không Gian (Vortex Twirl)",
        description: "Bẻ cong không gian xoắn ốc quanh tâm khung hình",
        category: .motionShake,
        tags: ["vortex", "twirl", "warp", "portal"],
        previewBadge: "WARP",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "twirlRadius", title: "Bán kính vùng xoáy", minValue: 50.0, maxValue: 600.0, defaultValue: 260.0, step: 10.0, unit: "px"),
                CustomParameterDescriptor(id: "twirlAngle", title: "Cường độ góc xoắn", minValue: -6.28, maxValue: 6.28, defaultValue: 2.8, step: 0.1, unit: "rad")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "CITwirlDistortion",
                    parameterBindings: ["inputRadius": "$param.twirlRadius", "inputAngle": "$param.twirlAngle * $intensity"]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "MotionWarp", downloadsCount: 290, isVerified: true)
    )

    public static let anamorphicBloomPackage = EffectPreset(
        id: "creative_fx_anamorphic_bloom",
        name: "Hào Quang Điện Ảnh (Anamorphic Bloom)",
        description: "Khuếch tán vùng sáng highlight mềm mại chuẩn ống kính Anamorphic",
        category: .lightTransition,
        tags: ["bloom", "glow", "dreamy", "anamorphic"],
        previewBadge: "OPTICS",
        config: EffectConfiguration(
            type: .fadeIn,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "bloomRadius", title: "Bán kính tỏa sáng", minValue: 2.0, maxValue: 50.0, defaultValue: 20.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "bloomGain", title: "Độ rực hào quang", minValue: 0.1, maxValue: 2.0, defaultValue: 0.9, step: 0.05, unit: "x")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "CIBloom",
                    parameterBindings: ["inputRadius": "$param.bloomRadius", "inputIntensity": "$param.bloomGain * $intensity"]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "CinemaFX", downloadsCount: 520, isVerified: true)
    )

    public static let pixelRetroArcadePackage = EffectPreset(
        id: "creative_fx_pixel_arcade",
        name: "Pixel Hóa 8-Bit (Retro Arcade)",
        description: "Kết hợp lưới khối Pixel 8-bit và nén dải màu Posterize cổ điển",
        category: .cinematic,
        tags: ["pixel", "8bit", "arcade", "posterize"],
        previewBadge: "8-BIT",
        config: EffectConfiguration(
            type: .cinematicBlur,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "pixelScale", title: "Kích thước hạt Pixel", minValue: 2.0, maxValue: 64.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "colorLevels", title: "Số bậc dải màu 8-Bit", minValue: 2.0, maxValue: 16.0, defaultValue: 6.0, step: 1.0, unit: "bậc")
            ],
            filterPipeline: [
                CreativeFilterStep(filterName: "CIPixellate", parameterBindings: ["inputScale": "$param.pixelScale * $intensity"]),
                CreativeFilterStep(filterName: "CIColorPosterize", parameterBindings: ["inputLevels": "$param.colorLevels"])
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "RetroStudio", downloadsCount: 340, isVerified: true)
    )

    public static let thermalVisionPackage = EffectPreset(
        id: "creative_fx_thermal_vision",
        name: "Tầm Nhìn Nhiệt (Thermal Vision)",
        description: "Ánh xạ phổ nhiệt hồng ngoại xanh tím sang vàng rực theo độ sáng",
        category: .lightTransition,
        tags: ["thermal", "infrared", "heat", "scifi"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .whiteFlash,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "thermalSensitivity", title: "Độ nhạy phổ nhiệt", minValue: 0.5, maxValue: 2.5, defaultValue: 1.25, step: 0.05, unit: "x")
            ],
            filterPipeline: [
                CreativeFilterStep(filterName: "ThermalVision", parameterBindings: ["thermalSensitivity": "$param.thermalSensitivity * $intensity"])
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "SciFi Optics", downloadsCount: 260, isVerified: true)
    )

    public static let shockwaveRipplePackage = EffectPreset(
        id: "creative_fx_shockwave_ripple",
        name: "Sóng Xung Kích (Metal Shockwave)",
        description: "Gói Metal Compute bẻ cong khúc xạ sóng chấn động lan tỏa từ tâm khung hình",
        category: .motionShake,
        tags: ["shockwave", "ripple", "metal", "refraction"],
        previewBadge: "METAL",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "waveAmplitude", title: "Biên độ khúc xạ sóng", minValue: 5.0, maxValue: 60.0, defaultValue: 26.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "waveWidth", title: "Độ dày vành sóng", minValue: 0.04, maxValue: 0.35, defaultValue: 0.14, step: 0.01, unit: "x")
            ],
            filterPipeline: [
                CreativeFilterStep(
                    filterName: "MetalShockwave",
                    parameterBindings: [
                        "amplitude": "$param.waveAmplitude * $intensity",
                        "bandWidth": "$param.waveWidth"
                    ]
                )
            ]
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "MetalCompute Lab", downloadsCount: 410, isVerified: true)
    )
}
