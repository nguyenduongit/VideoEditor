import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất văn bản (Typography) với định dạng font chữ, viền, bóng, nền và transform vật lý Pro.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
public final class TextRendererEngine: @unchecked Sendable {
    public static let shared = TextRendererEngine()

    private init() {}

    /// Đo kích thước bounding box của văn bản dựa trên cấu hình và kích thước canvas.
    public func measureSize(for config: TextConfiguration, canvasSize: CGSize) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        #if os(macOS)
        let attributed = makeAttributedString(for: config)
        let maxTextSize = CGSize(width: max(100.0, canvasSize.width), height: max(100.0, canvasSize.height))
        let bounds = attributed.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        var w = ceil(bounds.width)
        var h = ceil(bounds.height)
        if config.hasBackground {
            let pad = CGFloat(config.backgroundPadding)
            w += pad * 2.0
            h += pad * 2.0
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
        let isKaraoke = config.animation.comboType == .karaokeBox || config.animation.comboType == .karaokeGlow
        if (config.animation.scope != .wholeBlock || isKaraoke) && !config.animation.isDefault {
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

    #if os(macOS)
    /// Kết xuất phân cấp từng ký tự, từng từ hoặc Karaoke Highlight
    private func renderSegmentedAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0,
              let context = createBitmapContext(width: width, height: height) else { return nil }

        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        let effectiveScope: TextAnimationScope = config.animation.scope == .wholeBlock ? .perWord : config.animation.scope
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let displayContent = config.isAllCaps
            ? config.content.precomposedStringWithCanonicalMapping.uppercased()
            : config.content.precomposedStringWithCanonicalMapping
        let (tokens, totalWidth) = TextSegmentRenderer.tokenize(
            content: displayContent, scope: effectiveScope,
            font: font, spacing: config.characterSpacing
        )
        let textSize = measureSize(for: config, canvasSize: canvasSize)

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        context.saveGState()
        context.translateBy(x: cx, y: cy)

        TextSegmentRenderer.drawSegmentedText(
            tokens: tokens, totalWidth: totalWidth, totalHeight: textSize.height,
            baseConfig: config, localTime: localTime, duration: duration,
            canvasSize: canvasSize, in: context,
            makeAttributedString: { [weak self] in self?.makeAttributedString(for: $0) ?? NSAttributedString() }
        )
        context.restoreGState()

        guard let cgImage = context.makeImage() else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let globalEval = TextAnimationEvaluator.evaluate(
            config: config, localTime: localTime, duration: duration, canvasSize: canvasSize
        )
        return TextShaderFilterEngine.applyFilters(
            to: ciImage,
            blurRadius: globalEval.blurRadius,
            hueAngle: globalEval.hueAngle,
            pixelateScale: globalEval.pixelateScale,
            rgbSplitIntensity: globalEval.rgbSplitIntensity,
            overlay: globalEval.overlay,
            lightSweepIntensity: config.animation.lightSweepIntensity
        )
    }
    #endif

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
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, config.opacity)))
            if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: ciImage]) {
                ciImage = matrix.outputImage ?? ciImage
            }
        }
        return ciImage
    }

    private func createBitmapContext(width: Int, height: Int) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
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

        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        if abs(overlay.skewX) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: 0, c: CGFloat(overlay.skewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 {
            context.scaleBy(x: sx, y: sy)
        }
        context.translateBy(x: 0, y: -pivotY)

        if config.hasBackground {
            let pad = CGFloat(config.backgroundPadding)
            let bgRect = CGRect(x: -textWidth / 2.0 - pad, y: -textHeight / 2.0 - pad, width: textWidth + pad * 2.0, height: textHeight + pad * 2.0)
            let corner = CGFloat(config.backgroundCornerRadius)
            let path = NSBezierPath(roundedRect: bgRect, xRadius: corner, yRadius: corner)
            parseHexColor(config.backgroundColorHex).setFill()
            path.fill()
        }

        if config.animation.isMaskEnabled || config.animation.inType == .maskReveal {
            let maskRect = CGRect(x: -textWidth / 2.0 - 10, y: -textHeight / 2.0 - 4, width: textWidth + 20, height: textHeight + 8)
            context.clip(to: maskRect)
        }

        let drawW = textWidth + 12.0
        let drawH = textHeight + 8.0
        let textRect = CGRect(x: -drawW / 2.0, y: -drawH / 2.0, width: drawW, height: drawH)
        attributed.draw(in: textRect)

        context.restoreGState()
    }

    public func makeAttributedString(for config: TextConfiguration) -> NSAttributedString {
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let paragraph = NSMutableParagraphStyle()
        switch config.alignment {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        paragraph.lineSpacing = CGFloat(config.lineSpacing)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: parseHexColor(config.textColorHex),
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]

        if config.isUnderline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if config.isStrikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }

        if config.hasStroke && config.strokeWidth > 0 {
            attrs[.strokeColor] = parseHexColor(config.strokeColorHex)
            attrs[.strokeWidth] = -abs(config.strokeWidth)
        }

        if config.hasGlow && config.glowRadius > 0 {
            let glow = NSShadow()
            glow.shadowColor = parseHexColor(config.glowColorHex)
            glow.shadowBlurRadius = CGFloat(config.glowRadius)
            attrs[.shadow] = glow
        } else if config.hasShadow && (config.shadowRadius > 0 || config.shadowOffsetX != 0 || config.shadowOffsetY != 0) {
            let shadow = NSShadow()
            shadow.shadowColor = parseHexColor(config.shadowColorHex)
            shadow.shadowBlurRadius = CGFloat(config.shadowRadius)
            shadow.shadowOffset = NSSize(width: config.shadowOffsetX, height: -config.shadowOffsetY)
            attrs[.shadow] = shadow
        }

        let safeContent = config.content.precomposedStringWithCanonicalMapping
        let textString = config.isAllCaps ? safeContent.uppercased() : safeContent
        return NSAttributedString(string: textString, attributes: attrs)
    }

    private func resolveFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
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

    public func parseHexColor(_ hex: String) -> NSColor {
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
