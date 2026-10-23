import Foundation

/// Mẫu kiểu chữ có sẵn (Preset) để người dùng chọn và thêm nhanh vào timeline
public struct TextPreset: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let config: TextConfiguration

    public init(
        id: String,
        name: String,
        description: String,
        config: TextConfiguration
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.config = config
    }

    /// Mẫu văn bản chuẩn mặc định
    public static let `default` = TextPreset(
        id: "default",
        name: "Văn bản mặc định",
        description: "Kiểu chữ tiêu chuẩn cơ bản",
        config: TextConfiguration(
            content: "Văn bản",
            fontName: "Helvetica",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
    )

    /// Danh sách mẫu chữ thiết kế sẵn phong phú
    public static let templates: [TextPreset] = [
        TextPreset(
            id: "headline_bold",
            name: "Tiêu đề lớn",
            description: "Chữ in hoa nổi bật kèm đổ bóng",
            config: TextConfiguration(
                content: "TIÊU ĐỀ",
                fontName: "Impact",
                fontSize: 64.0,
                textColorHex: "#FFFFFF",
                isBold: true,
                hasShadow: true,
                shadowColorHex: "#000000",
                shadowRadius: 8.0,
                shadowOffsetX: 3.0,
                shadowOffsetY: 3.0
            )
        ),
        TextPreset(
            id: "subtitle_box",
            name: "Phụ đề hộp",
            description: "Chữ trắng nền mờ bo góc cho phụ đề",
            config: TextConfiguration(
                content: "Nội dung phụ đề tại đây",
                fontName: "Helvetica",
                fontSize: 32.0,
                textColorHex: "#FFFFFF",
                hasBackground: true,
                backgroundColorHex: "#000000A6",
                backgroundCornerRadius: 6.0,
                backgroundPadding: 10.0,
                positionY: -350.0
            )
        ),
        TextPreset(
            id: "neon_yellow",
            name: "Neon Vàng",
            description: "Hiệu ứng chữ phát sáng màu vàng cam",
            config: TextConfiguration(
                content: "GLOW NEON",
                fontName: "Helvetica",
                fontSize: 52.0,
                textColorHex: "#FFF566",
                isBold: true,
                hasShadow: true,
                shadowColorHex: "#FF7A45",
                shadowRadius: 16.0,
                shadowOffsetX: 0.0,
                shadowOffsetY: 0.0
            )
        ),
        TextPreset(
            id: "cyber_cyan",
            name: "Cyber Cyan",
            description: "Phong cách công nghệ xanh ngọc rực rỡ",
            config: TextConfiguration(
                content: "CYBER TECH",
                fontName: "Helvetica",
                fontSize: 50.0,
                textColorHex: "#36CFC9",
                isBold: true,
                hasShadow: true,
                shadowColorHex: "#08979C",
                shadowRadius: 14.0,
                shadowOffsetX: 0.0,
                shadowOffsetY: 0.0
            )
        ),
        TextPreset(
            id: "cinematic_outline",
            name: "Viền điện ảnh",
            description: "Chữ trắng viền đen dày nổi bật trên nền video",
            config: TextConfiguration(
                content: "CINEMA",
                fontName: "Helvetica",
                fontSize: 56.0,
                textColorHex: "#FFFFFF",
                isBold: true,
                hasStroke: true,
                strokeColorHex: "#000000",
                strokeWidth: 4.0
            )
        ),
        TextPreset(
            id: "news_badge",
            name: "Hộp tin tức",
            description: "Hộp đỏ bắt mắt kiểu tin nóng Breaking News",
            config: TextConfiguration(
                content: "BREAKING NEWS",
                fontName: "Impact",
                fontSize: 42.0,
                textColorHex: "#FFFFFF",
                isBold: true,
                hasBackground: true,
                backgroundColorHex: "#CF1322",
                backgroundCornerRadius: 4.0,
                backgroundPadding: 14.0
            )
        ),
        TextPreset(
            id: "retro_serif",
            name: "Cổ điển Serif",
            description: "Chữ nghiêng màu kem phong cách hoài cổ",
            config: TextConfiguration(
                content: "Vintage Story",
                fontName: "Georgia",
                fontSize: 46.0,
                textColorHex: "#FFF1B8",
                isBold: false,
                isItalic: true
            )
        ),
        TextPreset(
            id: "typewriter",
            name: "Máy đánh chữ",
            description: "Phông Monospace kiểu kịch bản",
            config: TextConfiguration(
                content: "Scene 1: Introduction...",
                fontName: "Courier",
                fontSize: 34.0,
                textColorHex: "#E6F7FF",
                isBold: false,
                alignment: .left
            )
        )
    ]
}
