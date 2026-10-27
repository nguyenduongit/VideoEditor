import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

/// Bộ kết xuất đồ họa nâng cao cho Text: Khối đổ bóng 3D (Extrusion), Viền kép (Sticker), và Gradient Fill đa sắc.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm) của AGENTS.md.
public enum TextAdvancedStyleRenderer: Sendable {
    #if os(macOS)
    /// Tạo NSParagraphStyle chuẩn hóa theo cấu hình căn lề và khoảng cách dòng
    public static func makeParagraphStyle(for config: TextConfiguration) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        switch config.alignment {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        paragraph.lineSpacing = CGFloat(config.lineSpacing)
        return paragraph
    }

    /// Kết xuất Outer Glow và Drop Shadow nằm hoàn toàn phía sau lớp chữ và viền
    /// Đảm bảo hào quang tỏa ra ngoài nhưng không bao giờ làm ám màu hay đục màu ruột chữ
    public static func drawGlowAndShadow(
        config: TextConfiguration,
        font: NSFont,
        textString: String,
        paragraph: NSParagraphStyle,
        textRect: CGRect,
        in context: CGContext
    ) {
        let hasGlow = config.hasGlow && config.glowRadius > 0
        let hasShadow = config.hasShadow && (config.shadowRadius > 0 || config.shadowOffsetX != 0 || config.shadowOffsetY != 0)
        guard hasGlow || hasShadow else { return }

        let totalStroke: Double
        if config.hasOuterStroke && config.outerStrokeWidth > 0 {
            totalStroke = abs(config.strokeWidth) + abs(config.outerStrokeWidth) * 2.0
        } else if config.hasStroke && config.strokeWidth > 0 {
            totalStroke = abs(config.strokeWidth)
        } else {
            totalStroke = 0.0
        }

        // 1. Drop Shadow (nằm dưới cùng)
        if hasShadow {
            context.saveGState()
            let shadowColor = parseHexColor(config.shadowColorHex)
            let shadowOffset = CGSize(width: config.shadowOffsetX, height: -config.shadowOffsetY)
            context.setShadow(offset: shadowOffset, blur: CGFloat(config.shadowRadius), color: shadowColor.cgColor)
            var shadowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: shadowColor,
                .paragraphStyle: paragraph,
                .kern: CGFloat(config.characterSpacing)
            ]
            if totalStroke > 0 {
                shadowAttrs[.strokeColor] = shadowColor
                shadowAttrs[.strokeWidth] = -abs(totalStroke)
            }
            NSAttributedString(string: textString, attributes: shadowAttrs).draw(in: textRect)
            context.restoreGState()
        }

        // 2. Outer Glow (tỏa hào quang bên ngoài viền chữ mà không đè lên ruột chữ)
        if hasGlow {
            context.saveGState()
            let glowColor = parseHexColor(config.glowColorHex)
            context.setShadow(offset: .zero, blur: CGFloat(config.glowRadius), color: glowColor.cgColor)
            var glowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: glowColor,
                .paragraphStyle: paragraph,
                .kern: CGFloat(config.characterSpacing)
            ]
            if totalStroke > 0 {
                glowAttrs[.strokeColor] = glowColor
                glowAttrs[.strokeWidth] = -abs(totalStroke)
            }
            let glowStr = NSAttributedString(string: textString, attributes: glowAttrs)
            glowStr.draw(in: textRect)
            glowStr.draw(in: textRect)
            context.restoreGState()
        }
    }

    /// Kết xuất bóng khối 3D kéo dài (Extruded 3D / Isometric block shadow)
    public static func drawExtrusion(
        config: TextConfiguration,
        font: NSFont,
        textString: String,
        paragraph: NSParagraphStyle,
        textRect: CGRect,
        in context: CGContext
    ) {
        guard config.hasExtrusion && config.extrusionDepth > 0.5 else { return }
        let rad = config.extrusionAngle * .pi / 180.0
        let stepCount = max(2, min(40, Int(ceil(config.extrusionDepth * 1.5))))
        let stepDx = cos(rad) * (config.extrusionDepth / Double(stepCount))
        let stepDy = sin(rad) * (config.extrusionDepth / Double(stepCount))
        let extColor = parseHexColor(config.extrusionColorHex)

        let totalStroke: Double
        if config.hasOuterStroke && config.outerStrokeWidth > 0 {
            totalStroke = abs(config.strokeWidth) + abs(config.outerStrokeWidth) * 2.0
        } else if config.hasStroke && config.strokeWidth > 0 {
            totalStroke = abs(config.strokeWidth)
        } else {
            totalStroke = 0.0
        }

        var extAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: extColor,
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]
        if totalStroke > 0 {
            extAttrs[.strokeColor] = extColor
            extAttrs[.strokeWidth] = -abs(totalStroke)
        }

        let extString = NSAttributedString(string: textString, attributes: extAttrs)
        for i in stride(from: stepCount, through: 1, by: -1) {
            let curDx = CGFloat(Double(i) * stepDx)
            let curDy = CGFloat(Double(i) * stepDy)
            let sliceRect = textRect.offsetBy(dx: curDx, dy: -curDy)
            extString.draw(in: sliceRect)
        }
    }

    /// Kết xuất viền ngoài thứ hai (Outer Stroke / Sticker Cutout Effect)
    public static func drawOuterStroke(
        config: TextConfiguration,
        font: NSFont,
        textString: String,
        paragraph: NSParagraphStyle,
        textRect: CGRect,
        in context: CGContext
    ) {
        guard config.hasOuterStroke && config.outerStrokeWidth > 0.5 else { return }
        let outerColor = parseHexColor(config.outerStrokeColorHex)
        let totalStroke = abs(config.strokeWidth) + abs(config.outerStrokeWidth) * 2.0

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: outerColor,
            .strokeColor: outerColor,
            .strokeWidth: -abs(totalStroke),
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]
        let outerString = NSAttributedString(string: textString, attributes: attrs)
        outerString.draw(in: textRect)
    }

    /// Kết xuất màu chuyển sắc (Linear Gradient Fill đa sắc) lên bề mặt glyphs của chữ
    public static func drawGradientFill(
        config: TextConfiguration,
        font: NSFont,
        textString: String,
        paragraph: NSParagraphStyle,
        textRect: CGRect,
        in context: CGContext
    ) {
        guard config.isGradient && config.gradientColors.count >= 2 else { return }
        let cgColors = config.gradientColors.map {
            parseHexColor($0).cgColor
        } as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: nil) else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        // Vẽ khuôn chữ với màu trắng đục làm mask alpha
        let maskAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]
        let maskString = NSAttributedString(string: textString, attributes: maskAttrs)
        maskString.draw(in: textRect)

        // Áp dụng blend mode sourceIn để đổ gradient chỉ vào vùng có chữ
        context.setBlendMode(.sourceIn)
        let rad = config.gradientAngle * .pi / 180.0
        let halfW = textRect.width / 2.0
        let halfH = textRect.height / 2.0
        let midX = textRect.midX
        let midY = textRect.midY

        let startPt = CGPoint(x: midX - cos(rad) * halfW, y: midY + sin(rad) * halfH)
        let endPt = CGPoint(x: midX + cos(rad) * halfW, y: midY - sin(rad) * halfH)

        context.drawLinearGradient(
            gradient,
            start: startPt,
            end: endPt,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )

        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// Giải mã mã màu HEX thành NSColor chuẩn sRGB
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

    /// Tạo NSShadow cho hiệu ứng phát sáng Outer Glow
    public static func makeGlowShadow(color: NSColor, radius: Double) -> NSShadow {
        let glow = NSShadow()
        glow.shadowColor = color
        glow.shadowBlurRadius = CGFloat(radius)
        return glow
    }

    /// Tạo NSShadow cho hiệu ứng đổ bóng Drop Shadow
    public static func makeDropShadow(color: NSColor, radius: Double, dx: Double, dy: Double) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = CGFloat(radius)
        shadow.shadowOffset = NSSize(width: dx, height: -dy)
        return shadow
    }
    #endif
}
