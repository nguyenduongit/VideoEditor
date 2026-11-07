import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

/// Phần mở rộng cho `TextAdvancedStyleRenderer`: Kết xuất Viền Kép (Dual Stroke) và Mặt Chữ (Solid / Linear Gradient)
/// cho cả đường dẫn Vector `CGPath` lẫn các token hoạt ảnh phân tách ký tự (Segmented Kinetic Animation).
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TextAdvancedStyleRenderer {
    #if os(macOS)
    internal static func drawVectorStroke(
        glyphPath: CGPath,
        bounds: CGRect,
        stroke: TextStrokeStyle,
        strokeWidth: Double,
        in context: CGContext
    ) {
        let strokedOutline = glyphPath.copy(
            strokingWithWidth: CGFloat(strokeWidth),
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4.0
        )
        let unionPath = CGMutablePath()
        unionPath.addPath(strokedOutline)
        unionPath.addPath(glyphPath)

        if stroke.isGradient && stroke.gradientColors.count >= 2 {
            let expanded = bounds.insetBy(dx: -CGFloat(strokeWidth), dy: -CGFloat(strokeWidth))
            fillPathWithLinearGradient(
                path: unionPath,
                bounds: expanded,
                colorsHex: stroke.gradientColors,
                angleDegrees: stroke.gradientAngle,
                in: context
            )
        } else {
            context.saveGState()
            context.addPath(unionPath)
            context.setFillColor(parseHexColor(stroke.colorHex).cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }

    internal static func drawVectorFill(
        glyphPath: CGPath,
        bounds: CGRect,
        config: TextConfiguration,
        in context: CGContext
    ) {
        guard config.textColorHex.uppercased() != "NONE" || config.colorFillMode == .linearGradient else { return }
        if config.colorFillMode == .linearGradient && config.gradientColors.count >= 2 {
            fillPathWithLinearGradient(
                path: glyphPath,
                bounds: bounds,
                colorsHex: config.gradientColors,
                angleDegrees: config.gradientAngle,
                in: context
            )
        } else {
            context.saveGState()
            context.addPath(glyphPath)
            context.setFillColor(parseHexColor(config.textColorHex).cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }

    public static func fillPathWithLinearGradient(
        path: CGPath,
        bounds: CGRect,
        colorsHex: [String],
        angleDegrees: Double,
        in context: CGContext
    ) {
        let cgColors = colorsHex.map { parseHexColor($0).cgColor } as CFArray
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else {
            return
        }
        context.saveGState()
        context.addPath(path)
        context.clip()

        let rad = angleDegrees * .pi / 180.0
        let hw = max(4.0, bounds.width / 2.0)
        let hh = max(4.0, bounds.height / 2.0)
        let start = CGPoint(x: bounds.midX - cos(rad) * hw, y: bounds.midY + sin(rad) * hh)
        let end = CGPoint(x: bounds.midX + cos(rad) * hw, y: bounds.midY - sin(rad) * hh)
        context.drawLinearGradient(
            grad,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    /// Hỗ trợ vẽ nhanh một Token đơn lẻ trong chế độ Kinetic Per-Character Animation
    public static func drawStyledTokenString(
        _ tokenText: String,
        font: NSFont,
        config: TextConfiguration,
        in context: CGContext
    ) {
        let layout = TextCurvedPathBuilder.buildShapedLayout(
            text: tokenText,
            font: font,
            characterSpacing: config.characterSpacing,
            curve: TextCurveStyle(shape: .none)
        )
        drawStyledVectorGlyphPath(layout.combinedPath, pathBounds: layout.bounds, config: config, in: context)
        TextCurvedPathBuilder.drawEmojiFallbacks(layout.emojiGlyphs, in: context)
    }
    #endif
}
