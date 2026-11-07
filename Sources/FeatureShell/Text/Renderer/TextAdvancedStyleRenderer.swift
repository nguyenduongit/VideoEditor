import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
import CoreText
#endif
import Domain

/// Bộ kết xuất đồ họa vector chuyên sâu cho Text 1-Layer:
/// Hỗ trợ Glow (Intensity + Range), Shadow (Opacity + Blur + Distance + Angle),
/// Dual Stroke (2 viền độc lập có Gradient) và Linear Gradient Fill trên cả chữ thẳng lẫn chữ cong (Arc / Wave).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TextAdvancedStyleRenderer: Sendable {
    #if os(macOS)
    public static func makeParagraphStyle(for config: TextConfiguration) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        switch config.alignment {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        paragraph.lineBreakMode = .byClipping
        return paragraph
    }

    /// Vẽ trọn bộ 5 lớp (Shadow -> Glow -> Outer Stroke -> Inner Stroke -> Fill) trực tiếp lên đường dẫn Vector `CGPath`
    public static func drawStyledVectorGlyphPath(
        _ glyphPath: CGPath,
        pathBounds: CGRect,
        config: TextConfiguration,
        in context: CGContext
    ) {
        guard !glyphPath.isEmpty else { return }
        let innerW = config.innerStroke.isEnabled ? max(0.0, config.innerStroke.width) : 0.0
        let outerW = config.outerStroke.isEnabled ? max(0.0, config.outerStroke.width) : 0.0
        let fullSilhouetteStroke = (innerW + outerW) * 2.0

        drawVectorShadow(glyphPath: glyphPath, silhouetteStroke: fullSilhouetteStroke, shadow: config.shadow, in: context)
        drawVectorGlow(glyphPath: glyphPath, silhouetteStroke: fullSilhouetteStroke, glow: config.glow, in: context)

        if config.outerStroke.isEnabled && outerW > 0.25 {
            drawVectorStroke(
                glyphPath: glyphPath,
                bounds: pathBounds,
                stroke: config.outerStroke,
                strokeWidth: (innerW + outerW) * 2.0,
                in: context
            )
        }
        if config.innerStroke.isEnabled && innerW > 0.25 {
            drawVectorStroke(
                glyphPath: glyphPath,
                bounds: pathBounds,
                stroke: config.innerStroke,
                strokeWidth: innerW * 2.0,
                in: context
            )
        }
        drawVectorFill(glyphPath: glyphPath, bounds: pathBounds, config: config, in: context)
    }

    private static func drawVectorShadow(
        glyphPath: CGPath,
        silhouetteStroke: Double,
        shadow: TextShadowStyle,
        in context: CGContext
    ) {
        guard shadow.isEnabled, shadow.opacity > 0.5 else { return }
        let baseColor = parseHexColor(shadow.colorHex)
        let alpha = CGFloat(shadow.opacity / 100.0) * baseColor.alphaComponent
        let shadowColor = baseColor.withAlphaComponent(max(0.0, min(1.0, alpha)))

        let silPath = makeSilhouettePath(from: glyphPath, extraStrokeWidth: silhouetteStroke)
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        let offset = CGSize(width: shadow.offsetX, height: -shadow.offsetY)
        context.setShadow(offset: offset, blur: CGFloat(shadow.blur), color: shadowColor.cgColor)
        context.addPath(silPath)
        context.setFillColor(shadowColor.cgColor)
        context.fillPath()
        // Xóa phần nhân bên trong để bóng chỉ nằm phía sau, không ám đục ruột chữ bán trong suốt
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setBlendMode(.clear)
        context.addPath(silPath)
        context.fillPath()
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func drawVectorGlow(
        glyphPath: CGPath,
        silhouetteStroke: Double,
        glow: TextGlowStyle,
        in context: CGContext
    ) {
        guard glow.isEnabled, glow.intensity > 0.5, glow.range > 0.2 else { return }
        let baseColor = parseHexColor(glow.colorHex)
        let normIntensity = max(0.0, min(1.0, glow.intensity / 100.0))
        let glowColor = baseColor.withAlphaComponent(CGFloat(min(1.0, 0.35 + normIntensity * 0.65)))
        let silPath = makeSilhouettePath(from: glyphPath, extraStrokeWidth: silhouetteStroke)

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setShadow(offset: .zero, blur: CGFloat(glow.range), color: glowColor.cgColor)
        context.addPath(silPath)
        context.setFillColor(glowColor.cgColor)
        context.fillPath()
        if normIntensity > 0.55 {
            context.addPath(silPath)
            context.fillPath()
        }
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setBlendMode(.clear)
        context.addPath(silPath)
        context.fillPath()
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func makeSilhouettePath(from glyphPath: CGPath, extraStrokeWidth: Double) -> CGPath {
        guard extraStrokeWidth > 0.5 else { return glyphPath }
        let combined = CGMutablePath()
        combined.addPath(glyphPath)
        let stroked = glyphPath.copy(
            strokingWithWidth: CGFloat(extraStrokeWidth),
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4.0
        )
        combined.addPath(stroked)
        return combined
    }

    /// Giải mã mã màu HEX (#RRGGBB hoặc #RRGGBBAA) thành NSColor chuẩn sRGB
    public static func parseHexColor(_ hex: String) -> NSColor {
        if hex.uppercased() == "NONE" { return .clear }
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 6 { clean.append("FF") }
        guard clean.count == 8, let num = UInt64(clean, radix: 16) else { return .white }
        let r = CGFloat((num & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((num & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((num & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(num & 0x000000FF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    #endif
}
