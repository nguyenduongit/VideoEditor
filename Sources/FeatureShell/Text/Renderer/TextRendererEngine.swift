import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất văn bản (Typography) với định dạng font chữ, viền, bóng, nền và transform vật lý Pro.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
public final class TextRendererEngine: Sendable {
    public init() {}

    /// Đo kích thước bounding box của văn bản dựa trên cấu hình và kích thước canvas.
    public func measureSize(for config: TextConfiguration, canvasSize: CGSize) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        #if os(macOS)
        let attributed = makeAttributedString(for: config)
        let maxTextSize = CGSize(width: max(100.0, canvasSize.width), height: max(100.0, canvasSize.height))
        let bounds = attributed.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        var w = ceil(bounds.width)
        var h = ceil(bounds.height)
        if config.hasOuterStroke && config.outerStrokeWidth > 0 {
            let ow = CGFloat(config.outerStrokeWidth * 2.0); w += ow; h += ow
        }
        if config.hasExtrusion && config.extrusionDepth > 0 {
            let ed = CGFloat(config.extrusionDepth); w += ed; h += ed
        }
        if config.hasBackground {
            let pad = CGFloat(config.backgroundPadding * 2.0); w += pad; h += pad
        }
        return CGSize(width: max(20.0, w), height: max(20.0, h))
        #else
        return CGSize(width: 200, height: 60)
        #endif
    }

    /// Kết xuất văn bản với hoạt ảnh chuyển động tại thời điểm `localTime`.
    public func renderAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        #if os(macOS)
        if shouldRenderSegmented(for: config) {
            return renderSegmentedAnimatedImage(
                for: config, localTime: localTime,
                duration: duration, canvasSize: canvasSize
            )
        }
        #endif

        let evaluated = TextAnimationEvaluator.evaluate(
            config: config, localTime: localTime, duration: duration, canvasSize: canvasSize
        )
        guard let image = renderImage(for: evaluated.config, canvasSize: canvasSize, overlay: evaluated.overlay) else {
            return nil
        }
        return TextShaderFilterEngine.applyFilters(
            to: image, blurRadius: evaluated.blurRadius, hueAngle: evaluated.hueAngle,
            pixelateScale: evaluated.pixelateScale, rgbSplitIntensity: evaluated.rgbSplitIntensity,
            overlay: evaluated.overlay, lightSweepIntensity: config.animation.lightSweepIntensity
        )
    }


    /// Kết xuất văn bản tĩnh hoặc biến đổi khối thành CIImage
    public func renderImage(
        for config: TextConfiguration,
        canvasSize: CGSize,
        overlay: TextTransformOverlay = TextTransformOverlay()
    ) -> CIImage? {
        guard !config.content.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard let context = createBitmapContext(width: width, height: height) else { return nil }

        #if os(macOS)
        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        drawText(config: config, overlay: overlay, canvasSize: canvasSize, in: context)
        #endif

        guard let cgImage = context.makeImage() else { return nil }
        var ciImage = CIImage(cgImage: cgImage)
        if config.opacity < 1.0 {
            let vec = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, config.opacity)))
            if let f = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": vec, kCIInputImageKey: ciImage]) {
                ciImage = f.outputImage ?? ciImage
            }
        }
        return ciImage
    }

    internal func createBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    #if os(macOS)
    private func drawText(
        config: TextConfiguration,
        overlay: TextTransformOverlay,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let attributed = makeAttributedString(for: config)
        let maxTextSize = CGSize(width: max(100.0, canvasSize.width), height: max(100.0, canvasSize.height))
        let bounds = attributed.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let textWidth = ceil(bounds.width)
        let textHeight = ceil(bounds.height)

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        let pivotY: CGFloat
        switch config.animation.anchorPoint {
        case .center: pivotY = 0.0
        case .bottom: pivotY = -textHeight / 2.0
        case .top: pivotY = textHeight / 2.0
        }

        context.saveGState()
        context.translateBy(x: cx, y: cy + pivotY)

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if textWidth > maxSafeW && textWidth > 0 {
            let safeguardScale = maxSafeW / textWidth
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }

        if abs(config.rotation) > 0.001 { context.rotate(by: CGFloat(-config.rotation * .pi / 180.0)) }
        if abs(overlay.skewX) > 0.001 { context.concatenate(CGAffineTransform(a: 1, b: 0, c: CGFloat(overlay.skewX), d: 1, tx: 0, ty: 0)) }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 { context.scaleBy(x: sx, y: sy) }
        context.translateBy(x: 0, y: -pivotY)

        if config.hasBackground {
            let padY = CGFloat(config.backgroundPadding)
            let extraPadX = max(10.0, ceil(CGFloat(config.fontSize) * 0.22))
            let padX = padY + extraPadX
            let bgRect = CGRect(x: -textWidth / 2.0 - padX, y: -textHeight / 2.0 - padY, width: textWidth + padX * 2.0, height: textHeight + padY * 2.0)
            let corner = CGFloat(config.backgroundCornerRadius)
            let path = CGPath(roundedRect: bgRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
            context.saveGState()
            context.addPath(path)
            context.setFillColor(parseHexColor(config.backgroundColorHex).cgColor)
            context.fillPath()
            context.restoreGState()
        }

        if config.animation.isMaskEnabled {
            let maskRect = CGRect(x: -textWidth / 2.0 - 10, y: -textHeight / 2.0 - 4, width: textWidth + 20, height: textHeight + 8)
            context.clip(to: maskRect)
        }

        let drawW = textWidth + 12.0
        let drawH = textHeight + 8.0
        let textRect = CGRect(x: -drawW / 2.0, y: -drawH / 2.0, width: drawW, height: drawH)

        let safeContent = config.content.precomposedStringWithCanonicalMapping
        let textString = config.isAllCaps ? safeContent.uppercased() : safeContent
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let paragraph = TextAdvancedStyleRenderer.makeParagraphStyle(for: config)

        // 1. Tỏa Outer Glow và Drop Shadow ở lớp đáy (không bao giờ đè hay ám màu lên ruột chữ)
        TextAdvancedStyleRenderer.drawGlowAndShadow(
            config: config, font: font, textString: textString,
            paragraph: paragraph, textRect: textRect, in: context
        )
        // 2. Khối 3D Extrusion
        TextAdvancedStyleRenderer.drawExtrusion(
            config: config, font: font, textString: textString,
            paragraph: paragraph, textRect: textRect, in: context
        )
        // 3. Viền kép ngoài (Sticker)
        TextAdvancedStyleRenderer.drawOuterStroke(
            config: config, font: font, textString: textString,
            paragraph: paragraph, textRect: textRect, in: context
        )
        // 4. Gradient Fill (nếu có)
        TextAdvancedStyleRenderer.drawGradientFill(
            config: config, font: font, textString: textString,
            paragraph: paragraph, textRect: textRect, in: context
        )
        // 5. Chữ sắc nét trên cùng (ruột chữ & viền trong sạch hoàn toàn)
        attributed.draw(in: textRect)

        context.restoreGState()
    }

    public func makeAttributedString(for config: TextConfiguration) -> NSAttributedString {
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let paragraph = TextAdvancedStyleRenderer.makeParagraphStyle(for: config)

        let isHollowOrGradient = config.isHollow || config.textColorHex.uppercased() == "NONE" || (config.isGradient && config.gradientColors.count >= 2)
        let fgColor = isHollowOrGradient ? NSColor.clear : parseHexColor(config.textColorHex)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fgColor,
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]

        if config.isUnderline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if config.isStrikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }

        if config.hasStroke && config.strokeWidth > 0 {
            attrs[.strokeColor] = parseHexColor(config.strokeColorHex)
            attrs[.strokeWidth] = isHollowOrGradient ? abs(config.strokeWidth) : -abs(config.strokeWidth)
        }

        let safeContent = config.content.precomposedStringWithCanonicalMapping
        let textString = config.isAllCaps ? safeContent.uppercased() : safeContent
        return NSAttributedString(string: textString, attributes: attrs)
    }

    internal func resolveFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
        let safeSize = max(6.0, size)
        if name.lowercased() == "system" {
            return isBold ? NSFont.boldSystemFont(ofSize: safeSize) : NSFont.systemFont(ofSize: safeSize)
        }
        var font = NSFont(name: name, size: safeSize) ?? NSFont.systemFont(ofSize: safeSize)
        var traits: NSFontTraitMask = []
        if isBold { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            font = NSFontManager.shared.convert(font, toHaveTrait: traits)
        }
        return font
    }

    public static func parseHexColor(_ hex: String) -> NSColor {
        TextAdvancedStyleRenderer.parseHexColor(hex)
    }

    public func parseHexColor(_ hex: String) -> NSColor {
        Self.parseHexColor(hex)
    }
    #endif
}
