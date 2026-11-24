import Foundation

extension TransitionLibraryItem {
    /// 11 Mẫu Glitch & Distortion, 10 Mẫu Light Effects và 12 Mẫu 3D / Split / Mask.
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogEffects: [TransitionLibraryItem] = [
        // MARK: - 6. Glitch / Distortion (11 presets)
        TransitionLibraryItem(
            id: "trans_glitch_basic", name: "Glitch", description: "Digital glitch interference",
            category: .glitch, tags: ["glitch", "digital"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "waveform.path.badge.plus",
            parameterValues: ["sliceIntensity": 90.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_rgb", name: "RGB Glitch", description: "RGB chromatic offset",
            category: .glitch, tags: ["glitch", "rgb"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "square.stack.3d.forward.dottedline",
            parameterValues: ["sliceIntensity": 110.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_digital", name: "Digital Glitch", description: "Digital interference slices",
            category: .glitch, tags: ["glitch", "digital"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "cpu.fill",
            parameterValues: ["sliceIntensity": 95.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_tv_static", name: "TV Static", description: "Analog TV static interference",
            category: .glitch, tags: ["glitch", "tv", "static"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "tv.fill",
            parameterValues: ["sliceIntensity": 100.0, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_pixel", name: "Pixel Glitch", description: "Blocky pixel shatter",
            category: .glitch, tags: ["glitch", "pixel"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "squareshape.split.3x3",
            parameterValues: ["sliceIntensity": 80.0, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_distortion", name: "Distortion", description: "Visual warp distortion",
            category: .glitch, tags: ["distortion", "warp"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "scribble.variable",
            parameterValues: ["warpStrength": 64.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_warp", name: "Warp", description: "Organic image warp",
            category: .glitch, tags: ["warp", "bend"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "perspective",
            parameterValues: ["warpStrength": 52.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_stretch", name: "Stretch", description: "Elastic frame stretch",
            category: .glitch, tags: ["stretch", "warp"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "arrow.left.and.line.vertical.and.arrow.right",
            parameterValues: ["warpStrength": 60.0, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_ripple", name: "Ripple", description: "Water ripple distortion",
            category: .glitch, tags: ["ripple", "water"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "dot.radiowaves.left.and.right",
            parameterValues: ["warpStrength": 44.0, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_wave", name: "Wave", description: "Wave distortion sweep",
            category: .glitch, tags: ["wave", "distortion"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "water.waves",
            parameterValues: ["warpStrength": 50.0, "mode": 5.0]
        ),
        TransitionLibraryItem(
            id: "trans_glitch_chromatic", name: "Chromatic Aberration", description: "Lens chromatic color fringe",
            category: .glitch, tags: ["chromatic", "aberration"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "Rainbow",
            parameterValues: ["sliceIntensity": 85.0, "mode": 5.0]
        ),

        // MARK: - 7. Light Effects (10 presets)
        TransitionLibraryItem(
            id: "trans_light_flash", name: "Flash", description: "Bright camera flash",
            category: .light, tags: ["light", "flash"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "bolt.circle.fill",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.15, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_white_flash", name: "White Flash", description: "Pure white light flash",
            category: .light, tags: ["light", "white flash"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.max.circle.fill",
            parameterValues: ["flareIntensity": 1.4, "warmth": 0.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_leak", name: "Light Leak", description: "Warm organic film light leak",
            category: .light, tags: ["light", "leak"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.max.fill",
            parameterValues: ["flareIntensity": 1.15, "warmth": 0.85, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_lens_flare", name: "Lens Flare", description: "Optical lens flare sweep",
            category: .light, tags: ["light", "lens flare"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "camera.aperture",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.35, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_glow", name: "Glow", description: "Radiant light glow",
            category: .light, tags: ["light", "glow"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "rays",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.25, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_rays", name: "Light Rays", description: "Golden directional sun rays",
            category: .light, tags: ["light", "rays"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.haze.fill",
            parameterValues: ["flareIntensity": 1.3, "warmth": 0.65, "mode": 5.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_film_burn", name: "Film Burn", description: "Analog celluloid film burn",
            category: .light, tags: ["light", "film burn"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "flame.fill",
            parameterValues: ["flareIntensity": 1.35, "warmth": 0.95, "mode": 6.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_strobe", name: "Strobe", description: "Rhythmic strobe flash",
            category: .light, tags: ["light", "strobe"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "flashlight.on.fill",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.0, "mode": 7.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_sparkle", name: "Sparkle", description: "Shining highlight sparkles",
            category: .light, tags: ["light", "sparkle"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sparkles",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.4, "mode": 8.0]
        ),
        TransitionLibraryItem(
            id: "trans_light_twinkle", name: "Twinkle", description: "Soft twinkling highlight shimmer",
            category: .light, tags: ["light", "twinkle"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "wand.and.stars",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.55, "mode": 9.0]
        ),

        // MARK: - 8. 3D / Split / Mask (12 presets)
        TransitionLibraryItem(
            id: "trans_3d_cube", name: "3D Cube", description: "3D rotating cube",
            category: .advanced3D, tags: ["3d", "cube"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "cube.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.02, "mode": 7.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_cube_rotate", name: "Cube Rotate", description: "3D cube spin",
            category: .advanced3D, tags: ["3d", "cube", "rotate"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "cube.transparent.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.02, "mode": 8.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_page_turn", name: "Page Turn", description: "3D page curl turn",
            category: .advanced3D, tags: ["3d", "page turn"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "doc.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.03, "mode": 9.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_fold", name: "Fold", description: "3D accordion fold",
            category: .advanced3D, tags: ["3d", "fold"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "map.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.02, "mode": 10.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_flip", name: "Flip 3D", description: "3D plane flip",
            category: .advanced3D, tags: ["3d", "flip"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.portrait.rotate",
            parameterValues: ["shapeMode": 2.0, "feather": 0.02, "mode": 11.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_split", name: "Split", description: "Split screen reveal",
            category: .advanced3D, tags: ["split", "screen"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.2x1.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_two_screen", name: "2-Screen", description: "Dual split screens",
            category: .advanced3D, tags: ["split", "2-screen"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.1x2.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 5.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_multi_screen", name: "Multi-Screen", description: "Multi-panel grid split",
            category: .advanced3D, tags: ["split", "multi-screen"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.2x2.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 6.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_circle_wipe", name: "Circle Wipe", description: "Circular iris wipe",
            category: .advanced3D, tags: ["mask", "circle wipe"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "circle.dashed.inset.filled",
            parameterValues: ["shapeMode": 0.0, "feather": 0.04, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_heart_wipe", name: "Heart Wipe", description: "Heart shape mask wipe",
            category: .advanced3D, tags: ["mask", "heart wipe"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "heart.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.04, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_shape_reveal", name: "Shape Reveal", description: "Geometric shape reveal",
            category: .advanced3D, tags: ["mask", "shape reveal"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "seal.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.04, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_3d_mask_reveal", name: "Mask Reveal", description: "Soft feathered mask reveal",
            category: .advanced3D, tags: ["mask", "reveal"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "theatermask.and.paintbrush.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.06, "mode": 3.0]
        )
    ]
}
