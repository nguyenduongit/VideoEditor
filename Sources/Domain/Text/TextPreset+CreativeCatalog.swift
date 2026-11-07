import Foundation

extension TextPreset {
    /// Toàn bộ danh mục mẫu chữ tích hợp sẵn (gồm mẫu mặc định + bộ sưu tập sáng tạo)
    public static var templates: [TextPreset] {
        [TextPreset.default] + creativeCatalog
    }

    /// Bộ sưu tập Mẫu Chữ 1-Layer Chuẩn Hóa (dùng chung 1 lõi mở cho cả User & Template)
    public static let creativeCatalog: [TextPreset] = [
        neonCyberGlow,
        vlogBadgeBanner,
        retroCurvedTitle,
        karaokeDualStroke
    ]

    public static let neonCyberGlow = TextPreset(
        id: "template_neon_cyber_glow",
        name: "Neon Cyber Glow",
        description: "Chữ phát sáng hào quang Neon kèm viền chuyển sắc Linear",
        category: .cyber,
        tags: ["neon", "cyber", "glow", "gradient"],
        defaultDuration: 4.0,
        previewBadge: "NEON",
        previewBackgroundHex: "#0F172A",
        config: TextConfiguration(
            content: "CYBER NIGHT",
            fontName: "Helvetica",
            fontSize: 58.0,
            textColorHex: "#FFFFFF",
            isBold: true,
            characterSpacing: 2.0,
            innerStroke: TextStrokeStyle(
                isEnabled: true,
                width: 3.0,
                colorHex: "#38BDF8",
                isGradient: true,
                gradientColors: ["#38BDF8", "#F472B6"],
                gradientAngle: 45.0
            ),
            glow: TextGlowStyle(isEnabled: true, colorHex: "#38BDF8", intensity: 90.0, range: 16.0),
            shadow: TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 80.0, blur: 8.0, distance: 4.0, angleDegrees: -45.0),
            animation: TextAnimationConfiguration(
                inDuration: 0.9,
                inManifest: AnimationPreset.inGlitchTeleport.manifest,
                loopManifest: AnimationPreset.loopNeonFlicker.manifest
            )
        ),
        isSystem: true
    )

    public static let vlogBadgeBanner = TextPreset(
        id: "template_vlog_badge_banner",
        name: "Vlog Gradient Pill",
        description: "Nhãn tiêu đề nền hộp chuyển sắc bo tròn ôm theo chữ",
        category: .vlog,
        tags: ["vlog", "banner", "pill", "background"],
        defaultDuration: 4.0,
        previewBadge: "BADGE",
        previewBackgroundHex: "#18181B",
        config: TextConfiguration(
            content: "TẬP MỚI HÔM NAY",
            fontName: "ArialRoundedMTBold",
            fontSize: 44.0,
            textColorHex: "#FFFFFF",
            isBold: true,
            characterSpacing: 1.0,
            shadow: TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 50.0, blur: 4.0, distance: 2.0, angleDegrees: -90.0),
            background: TextBackgroundStyle(
                isEnabled: true,
                sourceKind: .linearGradient,
                gradientColorsHex: ["#FF2A85", "#7928CA"],
                gradientAngleDegrees: 35.0,
                cornerRadius: 22.0,
                borderWidth: 2.0,
                borderColorHex: "#FFFFFFCC",
                hasShadow: true,
                shadowColorHex: "#00000080",
                shadowBlur: 10.0,
                shadowDistance: 5.0,
                fitToTextBounds: true,
                paddingX: 24.0,
                paddingY: 12.0,
                animateWithText: true
            ),
            animation: TextAnimationConfiguration(
                inDuration: 0.9,
                inManifest: AnimationPreset.inElasticJellyDrop.manifest,
                loopManifest: AnimationPreset.loopJellySquash.manifest
            )
        ),
        isSystem: true
    )

    public static let retroCurvedTitle = TextPreset(
        id: "template_retro_curved_arc",
        name: "Retro Curved Arc",
        description: "Tiêu đề uốn cung tròn cổ điển kèm viền kép nổi khối",
        category: .cinema,
        tags: ["curved", "arc", "retro", "cinema"],
        defaultDuration: 4.5,
        previewBadge: "CURVED",
        previewBackgroundHex: "#1C1917",
        config: TextConfiguration(
            content: "SUMMER VIBES",
            fontName: "Helvetica",
            fontSize: 54.0,
            textColorHex: "#FDE047",
            isBold: true,
            characterSpacing: 2.5,
            colorFillMode: .linearGradient,
            gradientColors: ["#FDE047", "#F97316"],
            gradientAngle: 90.0,
            innerStroke: TextStrokeStyle(isEnabled: true, width: 3.5, colorHex: "#18181B"),
            outerStroke: TextStrokeStyle(isEnabled: true, width: 5.0, colorHex: "#FFFFFF"),
            curve: TextCurveStyle(shape: .arc, angleDegrees: 55.0, followTangent: true),
            animation: TextAnimationConfiguration(
                inDuration: 0.9,
                inManifest: AnimationPreset.inVortexSpin3D.manifest,
                loopManifest: AnimationPreset.loopHarmonicWave.manifest
            )
        ),
        isSystem: true
    )

    public static let karaokeDualStroke = TextPreset(
        id: "template_karaoke_dual_stroke",
        name: "Phụ Đề Viền Kép",
        description: "Phụ đề nổi bật rõ nét trên mọi nền video với 2 tầng viền độc lập",
        category: .karaoke,
        tags: ["subtitle", "karaoke", "stroke", "clean"],
        defaultDuration: 4.0,
        previewBadge: "SUBTITLE",
        previewBackgroundHex: "#09090B",
        config: TextConfiguration(
            content: "Lời bài hát sắc nét",
            fontName: "ArialRoundedMTBold",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            isBold: true,
            innerStroke: TextStrokeStyle(isEnabled: true, width: 4.0, colorHex: "#0F172A"),
            outerStroke: TextStrokeStyle(isEnabled: true, width: 3.0, colorHex: "#38BDF8"),
            shadow: TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 70.0, blur: 6.0, distance: 3.0, angleDegrees: -90.0),
            positionY: 320.0,
            animation: TextAnimationConfiguration(
                inDuration: 0.85,
                inManifest: AnimationPreset.inFlipCascade3D.manifest,
                loopManifest: AnimationPreset.loopBassHeartbeat.manifest
            )
        ),
        isSystem: true
    )
}
