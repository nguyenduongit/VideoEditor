import Foundation

extension TransitionPreset {
    /// 11 Mẫu Glitch & Distortion, 10 Mẫu Light Effects và 12 Mẫu 3D / Split / Mask.
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogEffects: [TransitionPreset] = [
        // MARK: - 6. Glitch / Distortion (11 mẫu)
        TransitionPreset(
            id: "trans_glitch_basic", name: "Glitch", description: "Lỗi hình ảnh kỹ thuật số",
            category: .glitch, tags: ["glitch", "loi hinh anh"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "waveform.path.badge.plus",
            parameterValues: ["sliceIntensity": 90.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_rgb", name: "RGB Glitch", description: "Lệch màu RGB",
            category: .glitch, tags: ["glitch", "rgb", "lech mau"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "square.stack.3d.forward.dottedline",
            parameterValues: ["sliceIntensity": 110.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_digital", name: "Digital Glitch", description: "Nhiễu kỹ thuật số",
            category: .glitch, tags: ["glitch", "digital", "nhieu so"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "cpu.fill",
            parameterValues: ["sliceIntensity": 95.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_tv_static", name: "TV Static", description: "Nhiễu tivi",
            category: .glitch, tags: ["glitch", "tv", "static", "nhieu tivi"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "tv.fill",
            parameterValues: ["sliceIntensity": 100.0, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_pixel", name: "Pixel Glitch", description: "Vỡ điểm ảnh",
            category: .glitch, tags: ["glitch", "pixel", "vo diem anh"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "squareshape.split.3x3",
            parameterValues: ["sliceIntensity": 80.0, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_distortion", name: "Distortion", description: "Biến dạng",
            category: .glitch, tags: ["distortion", "bien dang"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "scribble.variable",
            parameterValues: ["warpStrength": 64.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_warp", name: "Warp", description: "Bẻ cong hình ảnh",
            category: .glitch, tags: ["warp", "be cong"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "perspective",
            parameterValues: ["warpStrength": 52.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_stretch", name: "Stretch", description: "Kéo giãn",
            category: .glitch, tags: ["stretch", "keo gian"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "arrow.left.and.line.vertical.and.arrow.right",
            parameterValues: ["warpStrength": 60.0, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_ripple", name: "Ripple", description: "Gợn sóng",
            category: .glitch, tags: ["ripple", "gon song"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "dot.radiowaves.left.and.right",
            parameterValues: ["warpStrength": 44.0, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_wave", name: "Wave", description: "Sóng",
            category: .glitch, tags: ["wave", "song"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "water.waves",
            parameterValues: ["warpStrength": 50.0, "mode": 5.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_glitch_chromatic", name: "Chromatic Aberration", description: "Lệch sắc sai màu",
            category: .glitch, tags: ["chromatic", "aberration", "lech sac"], defaultDuration: 2.0,
            shaderType: .glitchWipe, iconName: "Rainbow",
            parameterValues: ["sliceIntensity": 85.0, "mode": 5.0], isSystem: true
        ),

        // MARK: - 7. Light Effects (10 mẫu)
        TransitionPreset(
            id: "trans_light_flash", name: "Flash", description: "Chớp sáng",
            category: .light, tags: ["light", "flash", "chop sang"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "bolt.circle.fill",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.15, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_white_flash", name: "White Flash", description: "Chớp trắng",
            category: .light, tags: ["light", "white flash", "chop trang"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.max.circle.fill",
            parameterValues: ["flareIntensity": 1.4, "warmth": 0.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_leak", name: "Light Leak", description: "Ánh sáng lọt",
            category: .light, tags: ["light", "leak", "anh sang lot"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.max.fill",
            parameterValues: ["flareIntensity": 1.15, "warmth": 0.85, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_lens_flare", name: "Lens Flare", description: "Lóa ống kính",
            category: .light, tags: ["light", "lens flare", "loa ong kinh"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "camera.aperture",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.35, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_glow", name: "Glow", description: "Phát sáng",
            category: .light, tags: ["light", "glow", "phat sang"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "rays",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.25, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_rays", name: "Light Rays", description: "Tia sáng",
            category: .light, tags: ["light", "rays", "tia sang"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sun.haze.fill",
            parameterValues: ["flareIntensity": 1.3, "warmth": 0.65, "mode": 5.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_film_burn", name: "Film Burn", description: "Cháy phim",
            category: .light, tags: ["light", "film burn", "chay phim"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "flame.fill",
            parameterValues: ["flareIntensity": 1.35, "warmth": 0.95, "mode": 6.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_strobe", name: "Strobe", description: "Nhấp nháy",
            category: .light, tags: ["light", "strobe", "nhap nhay"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "flashlight.on.fill",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.0, "mode": 7.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_sparkle", name: "Sparkle", description: "Lấp lánh",
            category: .light, tags: ["light", "sparkle", "lap lanh"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "sparkles",
            parameterValues: ["flareIntensity": 1.25, "warmth": 0.4, "mode": 8.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_light_twinkle", name: "Twinkle", description: "Lung linh",
            category: .light, tags: ["light", "twinkle", "lung linh"], defaultDuration: 2.0,
            shaderType: .lightLeak, iconName: "wand.and.stars",
            parameterValues: ["flareIntensity": 1.2, "warmth": 0.55, "mode": 9.0], isSystem: true
        ),

        // MARK: - 8. 3D / Split / Mask (12 mẫu)
        TransitionPreset(
            id: "trans_3d_cube", name: "3D Cube", description: "Khối lập phương 3D",
            category: .advanced3D, tags: ["3d", "cube", "lap phuong"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "cube.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.02, "mode": 7.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_cube_rotate", name: "Cube Rotate", description: "Xoay khối lập phương",
            category: .advanced3D, tags: ["3d", "cube", "rotate", "xoay khoi"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "cube.transparent.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.02, "mode": 8.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_page_turn", name: "Page Turn", description: "Lật trang",
            category: .advanced3D, tags: ["3d", "page turn", "lat trang"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "doc.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.03, "mode": 9.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_fold", name: "Fold", description: "Gấp hình",
            category: .advanced3D, tags: ["3d", "fold", "gap hinh"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "map.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.02, "mode": 10.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_flip", name: "Flip 3D", description: "Lật 3D",
            category: .advanced3D, tags: ["3d", "flip", "lat 3d"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.portrait.rotate",
            parameterValues: ["shapeMode": 2.0, "feather": 0.02, "mode": 11.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_split", name: "Split", description: "Chia khung hình",
            category: .advanced3D, tags: ["split", "chia khung"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.2x1.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_two_screen", name: "2-Screen", description: "Hai màn hình",
            category: .advanced3D, tags: ["split", "2-screen", "hai man hinh"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.1x2.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 5.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_multi_screen", name: "Multi-Screen", description: "Nhiều màn hình",
            category: .advanced3D, tags: ["split", "multi-screen", "nhieu man hinh"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "rectangle.split.2x2.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.01, "mode": 6.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_circle_wipe", name: "Circle Wipe", description: "Quét hình tròn",
            category: .advanced3D, tags: ["mask", "circle wipe", "hinh tron"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "circle.dashed.inset.filled",
            parameterValues: ["shapeMode": 0.0, "feather": 0.04, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_heart_wipe", name: "Heart Wipe", description: "Quét hình trái tim",
            category: .advanced3D, tags: ["mask", "heart wipe", "trai tim"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "heart.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.04, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_shape_reveal", name: "Shape Reveal", description: "Hiện hình theo hình dạng",
            category: .advanced3D, tags: ["mask", "shape reveal", "hinh dang"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "seal.fill",
            parameterValues: ["shapeMode": 1.0, "feather": 0.04, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_3d_mask_reveal", name: "Mask Reveal", description: "Hiện hình bằng mặt nạ",
            category: .advanced3D, tags: ["mask", "reveal", "mat na"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "theatermask.and.paintbrush.fill",
            parameterValues: ["shapeMode": 2.0, "feather": 0.06, "mode": 3.0], isSystem: true
        )
    ]
}
