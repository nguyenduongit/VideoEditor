import Foundation

extension EffectPreset {
    /// Bộ sưu tập 1 Gói Hiệu Ứng Sáng Tạo Demo Chuẩn Hóa
    public static let systemTemplates: [EffectPreset] = [
        rgbGlitchPackage
    ]

    public static let rgbGlitchPackage = EffectPreset(
        id: "creative_fx_rgb_glitch",
        name: "Cyber RGB Glitch",
        description: "Shader package that splits Red and Cyan color channels on a sine-wave pulse",
        category: .partyBeat,
        tags: ["glitch", "rgb", "cyber", "shader"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "rgbOffset", title: "RGB Channel Offset", minValue: 0.0, maxValue: 45.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "pulseFreq", title: "Pulse Frequency", minValue: 1.0, maxValue: 20.0, defaultValue: 6.0, step: 0.5, unit: "Hz")
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
        name: "VHS Retro Tape",
        description: "Shader package emulating 90s analog tape scanlines and chromatic color bleed",
        category: .cinematic,
        tags: ["vhs", "retro", "analog", "tape"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .cinematicBlur,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "scanlineStrength", title: "VHS Scanline Strength", minValue: 0.0, maxValue: 1.0, defaultValue: 0.55, step: 0.05, unit: "x"),
                CustomParameterDescriptor(id: "colorBleed", title: "Chromatic Color Bleed", minValue: 0.0, maxValue: 28.0, defaultValue: 9.0, step: 0.5, unit: "px")
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
        name: "Comic Halftone",
        description: "Transforms the frame into ink outlines and halftone print dots",
        category: .partyBeat,
        tags: ["comic", "halftone", "manga", "popart"],
        previewBadge: "FX",
        config: EffectConfiguration(
            type: .whiteFlash,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "comicBlend", title: "Ink Blend", minValue: 0.1, maxValue: 1.0, defaultValue: 0.9, step: 0.05, unit: "x")
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
        name: "Kaleidoscope",
        description: "Real-time rotating polygonal mirror symmetry reflection",
        category: .motionShake,
        tags: ["kaleidoscope", "mirror", "prism", "trippy"],
        previewBadge: "PRISM",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "tileCount", title: "Prism Sides", minValue: 2.0, maxValue: 16.0, defaultValue: 6.0, step: 1.0, unit: "sides"),
                CustomParameterDescriptor(id: "rotationAngle", title: "Symmetry Angle", minValue: 0.0, maxValue: 6.28, defaultValue: 0.85, step: 0.05, unit: "rad")
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
        name: "Vortex Twirl",
        description: "Warps space in a spiral around the frame center",
        category: .motionShake,
        tags: ["vortex", "twirl", "warp", "portal"],
        previewBadge: "WARP",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "twirlRadius", title: "Twirl Radius", minValue: 50.0, maxValue: 600.0, defaultValue: 260.0, step: 10.0, unit: "px"),
                CustomParameterDescriptor(id: "twirlAngle", title: "Twirl Angle", minValue: -6.28, maxValue: 6.28, defaultValue: 2.8, step: 0.1, unit: "rad")
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
        name: "Anamorphic Bloom",
        description: "Softly diffuses bright highlights for a classic anamorphic lens glow",
        category: .lightTransition,
        tags: ["bloom", "glow", "dreamy", "anamorphic"],
        previewBadge: "OPTICS",
        config: EffectConfiguration(
            type: .fadeIn,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "bloomRadius", title: "Bloom Radius", minValue: 2.0, maxValue: 50.0, defaultValue: 20.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "bloomGain", title: "Bloom Intensity", minValue: 0.1, maxValue: 2.0, defaultValue: 0.9, step: 0.05, unit: "x")
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
        name: "8-Bit Retro Arcade",
        description: "Combines 8-bit pixel grid mosaic with classic color posterization",
        category: .cinematic,
        tags: ["pixel", "8bit", "arcade", "posterize"],
        previewBadge: "8-BIT",
        config: EffectConfiguration(
            type: .cinematicBlur,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "pixelScale", title: "Pixel Size", minValue: 2.0, maxValue: 64.0, defaultValue: 14.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "colorLevels", title: "8-Bit Color Levels", minValue: 2.0, maxValue: 16.0, defaultValue: 6.0, step: 1.0, unit: "levels")
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
        name: "Thermal Vision",
        description: "Maps luminance onto an infrared purple-to-bright-yellow thermal heatmap",
        category: .lightTransition,
        tags: ["thermal", "infrared", "heat", "scifi"],
        previewBadge: "SHADER",
        config: EffectConfiguration(
            type: .whiteFlash,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "thermalSensitivity", title: "Thermal Sensitivity", minValue: 0.5, maxValue: 2.5, defaultValue: 1.25, step: 0.05, unit: "x")
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
        name: "Metal Shockwave",
        description: "Metal compute refraction shockwave expanding radially from the frame center",
        category: .motionShake,
        tags: ["shockwave", "ripple", "metal", "refraction"],
        previewBadge: "METAL",
        config: EffectConfiguration(
            type: .cameraShake,
            intensity: 1.0,
            speed: 1.0,
            customParameters: [
                CustomParameterDescriptor(id: "waveAmplitude", title: "Wave Amplitude", minValue: 5.0, maxValue: 60.0, defaultValue: 26.0, step: 1.0, unit: "px"),
                CustomParameterDescriptor(id: "waveWidth", title: "Wave Ring Width", minValue: 0.04, maxValue: 0.35, defaultValue: 0.14, step: 0.01, unit: "x")
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
