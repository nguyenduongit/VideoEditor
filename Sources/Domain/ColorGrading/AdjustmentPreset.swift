import Foundation

/// Mẫu thiết lập sẵn thông số màu (Color Grading Template)
public struct AdjustmentPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let config: AdjustmentConfiguration

    public init(
        id: String,
        name: String,
        description: String,
        config: AdjustmentConfiguration
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
    }

    public static let `default` = AdjustmentPreset(
        id: "default",
        name: "Mặc định",
        description: "Màu nguyên bản không chỉnh sửa",
        config: AdjustmentConfiguration()
    )

    public static let templates: [AdjustmentPreset] = [
        AdjustmentPreset(
            id: "cinematic",
            name: "Điện ảnh",
            description: "Tông Teal & Orange tương phản chuẩn Hollywood",
            config: {
                var hsl = HSLAdjustments()
                hsl.orange = HSLChannel(hue: -15, saturation: 20, luminance: 10)
                hsl.blue = HSLChannel(hue: -10, saturation: 35, luminance: -10)
                hsl.cyan = HSLChannel(hue: 5, saturation: 25, luminance: -5)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: 15, tint: 5, saturation: 5,
                        exposure: 2, contrast: 18, highlight: -20, shadow: 15,
                        white: 5, black: -5, brilliance: 12
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "sunset",
            name: "Hoàng hôn",
            description: "Ánh nắng vàng cam ấm áp, lãng mạn",
            config: {
                var hsl = HSLAdjustments()
                hsl.orange = HSLChannel(hue: -10, saturation: 30, luminance: 15)
                hsl.yellow = HSLChannel(hue: -15, saturation: 25, luminance: 10)
                hsl.red = HSLChannel(hue: 5, saturation: 20, luminance: 5)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: 40, tint: -5, saturation: 15,
                        exposure: 5, contrast: 10, highlight: -10, shadow: 20,
                        white: 10, black: 0, brilliance: 20
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "cold_blue",
            name: "Băng giá",
            description: "Tông xanh lạnh buốt, trong trẻo tinh tế",
            config: {
                var hsl = HSLAdjustments()
                hsl.blue = HSLChannel(hue: 0, saturation: 30, luminance: 10)
                hsl.cyan = HSLChannel(hue: -5, saturation: 25, luminance: 15)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: -35, tint: 5, saturation: -5,
                        exposure: 8, contrast: 12, highlight: -15, shadow: 15,
                        white: 15, black: -5, brilliance: 10
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "korean_glow",
            name: "Hàn Quốc",
            description: "Da trắng hồng mịn màng rạng rỡ, khử vàng",
            config: {
                var hsl = HSLAdjustments()
                hsl.orange = HSLChannel(hue: -18, saturation: -15, luminance: 25)
                hsl.yellow = HSLChannel(hue: 10, saturation: -20, luminance: 10)
                hsl.red = HSLChannel(hue: 10, saturation: 15, luminance: 8)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: -10, tint: 12, saturation: 0,
                        exposure: 14, contrast: 5, highlight: -15, shadow: 25,
                        white: 8, black: 5, brilliance: 22
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "vintage",
            name: "Cổ điển",
            description: "Màu phim hoài niệm Vintage Film, vùng tối ấm mượt",
            config: {
                var hsl = HSLAdjustments()
                hsl.yellow = HSLChannel(hue: -10, saturation: 15, luminance: 5)
                hsl.green = HSLChannel(hue: 15, saturation: -25, luminance: -5)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: 25, tint: -6, saturation: -12,
                        exposure: -2, contrast: -5, highlight: -25, shadow: 35,
                        white: -10, black: 18, brilliance: -5
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "cyberpunk",
            name: "Cyberpunk",
            description: "Ánh sáng neon tím hồng và xanh lam tương phản cao",
            config: {
                var hsl = HSLAdjustments()
                hsl.purple = HSLChannel(hue: 15, saturation: 45, luminance: 10)
                hsl.magenta = HSLChannel(hue: -10, saturation: 40, luminance: 15)
                hsl.cyan = HSLChannel(hue: -10, saturation: 40, luminance: 10)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: -15, tint: 25, saturation: 20,
                        exposure: 5, contrast: 28, highlight: -10, shadow: -10,
                        white: 15, black: -15, brilliance: 25
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "vivid",
            name: "Rực rỡ",
            description: "Màu sắc sống động, độ tươi và tương phản cao",
            config: {
                var hsl = HSLAdjustments()
                hsl.red = HSLChannel(hue: 0, saturation: 25, luminance: 5)
                hsl.green = HSLChannel(hue: 0, saturation: 25, luminance: 5)
                hsl.blue = HSLChannel(hue: 0, saturation: 25, luminance: 5)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: 5, tint: 0, saturation: 22,
                        exposure: 6, contrast: 15, highlight: -10, shadow: 10,
                        white: 8, black: -5, brilliance: 28
                    ),
                    hsl: hsl
                )
            }()
        ),
        AdjustmentPreset(
            id: "monochrome",
            name: "Đen trắng",
            description: "Monochrome nghệ thuật tương phản ấn tượng",
            config: AdjustmentConfiguration(
                basic: BasicGradingParameters(
                    temp: 0, tint: 0, saturation: -100,
                    exposure: 5, contrast: 25, highlight: -20, shadow: 15,
                    white: 12, black: -10, brilliance: 0
                )
            )
        )
    ]
}
