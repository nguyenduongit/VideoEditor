import Foundation

extension AdjustmentPreset {
    /// Bộ sưu tập 6 Gói Phối Màu Điện Ảnh 5 Tầng (5-Stage Film Emulation & Color Grading Packages) thế hệ mới
    public static let creativeCatalog: [AdjustmentPreset] = [
        kodak2383FilmPrint,
        blockbusterTealOrange,
        fujiEternaSoftVintage,
        cyberpunkNeonNight,
        tokyoPastelVlog,
        silverHalideNoir
    ]

    public static let kodak2383FilmPrint = AdjustmentPreset(
        id: "creative_color_kodak_2383",
        name: "Kodak 2383 Film Print",
        description: "Giả lập nhựa phim điện ảnh Kodak Vision3 2383 với đường cong S-Curve và hạt bạc 35mm",
        category: .filmVintage,
        tags: ["kodak", "2383", "film", "cinema", "35mm"],
        previewBadge: "35MM FILM",
        previewColorsHex: ["#1B3B48", "#D98A3C"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: 8, tint: -3, saturation: -6, exposure: 8, contrast: 18, highlight: -22, shadow: 12, white: -8, black: -10, brilliance: 14),
            hsl: HSLAdjustments(
                red: HSLChannel(hue: 4, saturation: 8, luminance: -4),
                orange: HSLChannel(hue: -2, saturation: 10, luminance: 6),
                yellow: HSLChannel(hue: -12, saturation: -14, luminance: 4),
                blue: HSLChannel(hue: -8, saturation: 16, luminance: -12)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: -0.14, y: -0.06, luma: -4),
                gamma: ColorWheelOffset(x: 0.04, y: 0.03, luma: 2),
                gain: ColorWheelOffset(x: 0.16, y: 0.08, luma: -3)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.04), CurvePoint(x: 0.25, y: 0.20), CurvePoint(x: 0.75, y: 0.82), CurvePoint(x: 1.0, y: 0.96)],
                blue: [CurvePoint(x: 0.0, y: 0.06), CurvePoint(x: 0.5, y: 0.48), CurvePoint(x: 1.0, y: 0.92)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: 24, vignetteMidpoint: 46, vignetteFeather: 65, grainAmount: 22, grainSize: 42, sharpenAmount: 12)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Colorist Guild", downloadsCount: 640, isVerified: true)
    )

    public static let blockbusterTealOrange = AdjustmentPreset(
        id: "creative_color_teal_orange",
        name: "Blockbuster Teal & Orange",
        description: "Tương phản Lạnh/Ấm chuẩn phim hành động Hollywood, tách biệt hoàn toàn tông da",
        category: .cinematic,
        tags: ["teal", "orange", "hollywood", "blockbuster"],
        previewBadge: "HOLLYWOOD",
        previewColorsHex: ["#0D5C75", "#E86F2C"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: -4, tint: 0, saturation: 8, exposure: 5, contrast: 24, highlight: -18, shadow: -8, white: 10, black: -14, brilliance: 22),
            hsl: HSLAdjustments(
                orange: HSLChannel(hue: -4, saturation: 18, luminance: 8),
                yellow: HSLChannel(hue: -18, saturation: -20, luminance: 0),
                cyan: HSLChannel(hue: 12, saturation: 28, luminance: -8),
                blue: HSLChannel(hue: -14, saturation: 24, luminance: -14)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: -0.22, y: -0.08, luma: -6),
                gamma: ColorWheelOffset(x: 0.08, y: 0.04, luma: 0),
                gain: ColorWheelOffset(x: 0.14, y: 0.06, luma: 4)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.02), CurvePoint(x: 0.22, y: 0.16), CurvePoint(x: 0.78, y: 0.84), CurvePoint(x: 1.0, y: 0.99)],
                red: [CurvePoint(x: 0.0, y: 0.0), CurvePoint(x: 0.65, y: 0.70), CurvePoint(x: 1.0, y: 1.0)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: 30, vignetteMidpoint: 42, vignetteFeather: 60, grainAmount: 10, grainSize: 35, sharpenAmount: 24)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Hollywood DI", downloadsCount: 820, isVerified: true)
    )

    public static let fujiEternaSoftVintage = AdjustmentPreset(
        id: "creative_color_fuji_eterna",
        name: "Fuji Eterna Soft Vintage",
        description: "Chất màu phim Nhật Bản dịu nhẹ, nâng vùng tối mờ sương và xanh lá Ngọc Bích",
        category: .filmVintage,
        tags: ["fuji", "eterna", "vintage", "japan", "soft"],
        previewBadge: "FUJIFILM",
        previewColorsHex: ["#2E6F65", "#E2B486"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: 6, tint: -8, saturation: -12, exposure: 12, contrast: -14, highlight: -28, shadow: 32, white: -12, black: 18, brilliance: 10),
            hsl: HSLAdjustments(
                orange: HSLChannel(hue: 2, saturation: -6, luminance: 10),
                green: HSLChannel(hue: 22, saturation: -24, luminance: -6),
                cyan: HSLChannel(hue: -8, saturation: 14, luminance: 6)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: -0.06, y: 0.10, luma: 8),
                gamma: ColorWheelOffset(x: 0.04, y: 0.05, luma: 4),
                gain: ColorWheelOffset(x: 0.10, y: 0.08, luma: -6)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.09), CurvePoint(x: 0.30, y: 0.32), CurvePoint(x: 0.75, y: 0.76), CurvePoint(x: 1.0, y: 0.92)],
                green: [CurvePoint(x: 0.0, y: 0.04), CurvePoint(x: 0.5, y: 0.52), CurvePoint(x: 1.0, y: 0.96)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: 14, vignetteMidpoint: 55, vignetteFeather: 75, grainAmount: 26, grainSize: 48, sharpenAmount: 0)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Tokyo Film Lab", downloadsCount: 510, isVerified: true)
    )

    public static let cyberpunkNeonNight = AdjustmentPreset(
        id: "creative_color_cyberpunk_neon",
        name: "Cyberpunk Neon Night",
        description: "Đẩy lệch quang phổ sang tím Magenta và xanh điện Cyan cho cảnh phố đêm Neon",
        category: .cyberNeon,
        tags: ["cyberpunk", "neon", "night", "magenta", "cyan"],
        previewBadge: "NEON 2077",
        previewColorsHex: ["#00E5FF", "#FF007F"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: -22, tint: 28, saturation: 18, exposure: 4, contrast: 28, highlight: -10, shadow: -12, white: 16, black: -18, brilliance: 34),
            hsl: HSLAdjustments(
                yellow: HSLChannel(hue: -35, saturation: 20, luminance: 8),
                cyan: HSLChannel(hue: 10, saturation: 42, luminance: 12),
                blue: HSLChannel(hue: -18, saturation: 36, luminance: 6),
                purple: HSLChannel(hue: 16, saturation: 40, luminance: 10),
                magenta: HSLChannel(hue: -8, saturation: 45, luminance: 14)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: -0.18, y: -0.24, luma: -8),
                gamma: ColorWheelOffset(x: 0.14, y: -0.16, luma: 0),
                gain: ColorWheelOffset(x: -0.20, y: 0.12, luma: 8)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.0), CurvePoint(x: 0.20, y: 0.14), CurvePoint(x: 0.80, y: 0.88), CurvePoint(x: 1.0, y: 1.0)],
                blue: [CurvePoint(x: 0.0, y: 0.08), CurvePoint(x: 0.5, y: 0.56), CurvePoint(x: 1.0, y: 1.0)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: 36, vignetteMidpoint: 40, vignetteFeather: 55, grainAmount: 14, grainSize: 30, sharpenAmount: 28)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Neon Grid", downloadsCount: 590, isVerified: true)
    )

    public static let tokyoPastelVlog = AdjustmentPreset(
        id: "creative_color_tokyo_pastel",
        name: "Tokyo Pastel Vlog",
        description: "Trong trẻo, sáng mịn, làm hồng hào tông da và bầu trời xanh Pastel nhẹ nhàng",
        category: .portraitVlog,
        tags: ["pastel", "tokyo", "vlog", "portrait", "clean"],
        previewBadge: "AIRY VLOG",
        previewColorsHex: ["#7DD3FC", "#FDA4AF"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: -6, tint: 6, saturation: -4, exposure: 18, contrast: -10, highlight: -24, shadow: 28, white: 12, black: 10, brilliance: 24),
            hsl: HSLAdjustments(
                red: HSLChannel(hue: 6, saturation: -8, luminance: 12),
                orange: HSLChannel(hue: 4, saturation: -10, luminance: 16),
                green: HSLChannel(hue: 16, saturation: -18, luminance: 10),
                cyan: HSLChannel(hue: -6, saturation: 22, luminance: 12),
                blue: HSLChannel(hue: -10, saturation: 18, luminance: 14)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: -0.04, y: -0.02, luma: 6),
                gamma: ColorWheelOffset(x: 0.05, y: 0.02, luma: 6),
                gain: ColorWheelOffset(x: -0.06, y: 0.04, luma: 4)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.05), CurvePoint(x: 0.35, y: 0.42), CurvePoint(x: 0.75, y: 0.82), CurvePoint(x: 1.0, y: 0.98)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: -12, vignetteMidpoint: 60, vignetteFeather: 80, grainAmount: 6, grainSize: 25, sharpenAmount: 14)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Shibuya Daily", downloadsCount: 470, isVerified: true)
    )

    public static let silverHalideNoir = AdjustmentPreset(
        id: "creative_color_silver_noir",
        name: "Silver Halide Noir (B&W)",
        description: "Đen trắng tương phản cao chuẩn phim nhựa Ilford HP5 với kết cấu hạt bạc rõ nét",
        category: .moodyMono,
        tags: ["bw", "noir", "monochrome", "ilford", "silver"],
        previewBadge: "MONO NOIR",
        previewColorsHex: ["#18181B", "#E4E4E7"],
        config: AdjustmentConfiguration(
            basic: BasicGradingParameters(temp: 0, tint: 0, saturation: -100, exposure: 6, contrast: 36, highlight: -16, shadow: -14, white: 20, black: -22, brilliance: -100),
            hsl: HSLAdjustments(
                red: HSLChannel(hue: 0, saturation: -100, luminance: -8),
                orange: HSLChannel(hue: 0, saturation: -100, luminance: 14),
                blue: HSLChannel(hue: 0, saturation: -100, luminance: -24)
            ),
            wheels: ColorWheelsAdjustments(
                lift: ColorWheelOffset(x: 0.0, y: 0.0, luma: -8),
                gamma: ColorWheelOffset(x: 0.0, y: 0.0, luma: -2),
                gain: ColorWheelOffset(x: 0.0, y: 0.0, luma: 8)
            ),
            curves: ColorCurvesAdjustments(
                master: [CurvePoint(x: 0.0, y: 0.03), CurvePoint(x: 0.22, y: 0.14), CurvePoint(x: 0.78, y: 0.88), CurvePoint(x: 1.0, y: 0.98)]
            ),
            effects: EffectsGradingParameters(vignetteAmount: 38, vignetteMidpoint: 38, vignetteFeather: 58, grainAmount: 36, grainSize: 54, sharpenAmount: 22)
        ),
        isSystem: true,
        community: CommunityMetadata(authorID: "community_sdk", authorName: "Noir Archive", downloadsCount: 385, isVerified: true)
    )
}
