import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Kết xuất Tab `Background` thống nhất của Text Clip.
/// Tự động bám theo tọa độ tâm, góc xoay và tỉ lệ của dòng chữ gốc kèm `offsetX/Y` riêng,
/// hỗ trợ Solid, Linear/Radial Gradient, Vector SVG, Ảnh tĩnh/động (PNG/GIF/APNG với Fill/Fit/Stretch),
/// Viền hộp (Border), Đổ bóng hộp (Box Shadow), Feather GPU thật (`CIFaussianBlur`) và Blend Mode.
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TextCompositeLayerRenderer: Sendable {

    #if os(macOS)
    public static func renderBackground(
        background bg: TextBackgroundStyle,
        anchorConfig: TextConfiguration,
        overlay: TextTransformOverlay,
        textRawSize: CGSize,
        safeguardScale: CGFloat,
        canvasSize: CGSize,
        localTime: Double
    ) -> CIImage? {
        guard bg.isEnabled, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.saveGState()
        let cx = canvasSize.width / 2.0 + CGFloat(anchorConfig.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(anchorConfig.positionY)
        context.translateBy(x: cx, y: cy)
        if safeguardScale < 0.999 {
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }
        if abs(anchorConfig.rotation) > 0.001 {
            context.rotate(by: CGFloat(-anchorConfig.rotation * .pi / 180.0))
        }
        if abs(overlay.skewX) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: 0, c: CGFloat(overlay.skewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, anchorConfig.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, anchorConfig.scale * overlay.scaleY))
        context.scaleBy(x: sx, y: sy)

        let boxW = bg.fitToTextBounds
            ? max(16.0, textRawSize.width + CGFloat(bg.paddingX * 2.0))
            : CGFloat(max(20.0, bg.customWidth))
        let boxH = bg.fitToTextBounds
            ? max(16.0, textRawSize.height + CGFloat(bg.paddingY * 2.0))
            : CGFloat(max(20.0, bg.customHeight))
        let rect = CGRect(
            x: -boxW / 2.0 + CGFloat(bg.offsetX),
            y: -boxH / 2.0 - CGFloat(bg.offsetY),
            width: boxW,
            height: boxH
        )
        let corner = min(CGFloat(bg.cornerRadius), min(boxW, boxH) / 2.0)

        drawBoxShadowIfNeeded(bg: bg, rect: rect, corner: corner, in: context)
        drawBackgroundContent(bg: bg, rect: rect, corner: corner, scale: max(sx, sy), localTime: localTime, in: context)
        drawBoxBorderIfNeeded(bg: bg, rect: rect, corner: corner, in: context)
        context.restoreGState()

        guard let cgImage = context.makeImage() else { return nil }
        var ciImage = CIImage(cgImage: cgImage)
        let canvasExtent = CGRect(origin: .zero, size: canvasSize)

        if bg.featherRadius > 0.25 {
            ciImage = applyGPUFeather(radius: bg.featherRadius, to: ciImage, extent: canvasExtent)
        }
        let effectiveAlpha = max(0.0, min(1.0, bg.opacity * anchorConfig.opacity))
        ciImage = TextSVGAndAssetCache.applyPremultipliedOpacity(effectiveAlpha, to: ciImage)
        return ciImage
    }

    private static func drawBoxShadowIfNeeded(
        bg: TextBackgroundStyle,
        rect: CGRect,
        corner: CGFloat,
        in context: CGContext
    ) {
        guard bg.hasShadow, bg.shadowBlur > 0.1 || bg.shadowDistance > 0.1 else { return }
        let rad = bg.shadowAngleDegrees * .pi / 180.0
        let dx = cos(rad) * bg.shadowDistance
        let dy = sin(rad) * bg.shadowDistance
        let shadowColor = TextAdvancedStyleRenderer.parseHexColor(bg.shadowColorHex)
        let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setShadow(offset: CGSize(width: dx, height: dy), blur: CGFloat(bg.shadowBlur), color: shadowColor.cgColor)
        context.addPath(path)
        context.setFillColor(shadowColor.cgColor)
        context.fillPath()
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setBlendMode(.clear)
        context.addPath(path)
        context.fillPath()
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func drawBackgroundContent(
        bg: TextBackgroundStyle,
        rect: CGRect,
        corner: CGFloat,
        scale: CGFloat,
        localTime: Double,
        in context: CGContext
    ) {
        let clipPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        context.saveGState()
        context.addPath(clipPath)
        context.clip()

        switch bg.sourceKind {
        case .solid:
            context.setFillColor(TextAdvancedStyleRenderer.parseHexColor(bg.solidColorHex).cgColor)
            context.fill(rect)

        case .linearGradient:
            TextAdvancedStyleRenderer.fillPathWithLinearGradient(
                path: clipPath,
                bounds: rect,
                colorsHex: bg.gradientColorsHex,
                angleDegrees: bg.gradientAngleDegrees,
                in: context
            )

        case .radialGradient:
            drawRadialGradient(colorsHex: bg.gradientColorsHex, in: rect, context: context)

        case .inlineSVG:
            let pxSize = CGSize(width: rect.width * max(1.0, scale), height: rect.height * max(1.0, scale))
            if let cgImg = TextSVGAndAssetCache.shared.rasterizeSVG(bg.svgMarkup, targetSize: pxSize) {
                let fitted = fittedRect(for: CGSize(width: cgImg.width, height: cgImg.height), in: rect, mode: bg.contentFitMode)
                context.draw(cgImg, in: fitted)
            }

        case .animatedAsset:
            let pxSize = CGSize(width: rect.width * max(1.0, scale), height: rect.height * max(1.0, scale))
            if let cgImg = TextSVGAndAssetCache.shared.frameForAsset(
                path: bg.assetPathOrURL,
                localTime: localTime,
                loop: bg.loopAsset,
                speed: bg.assetSpeed,
                targetSize: pxSize
            ) {
                let fitted = fittedRect(for: CGSize(width: cgImg.width, height: cgImg.height), in: rect, mode: bg.contentFitMode)
                context.draw(cgImg, in: fitted)
            }
        }
        context.restoreGState()
    }

    private static func drawRadialGradient(colorsHex: [String], in rect: CGRect, context: CGContext) {
        let cgColors = (colorsHex.count >= 2 ? colorsHex : ["#FF2A85", "#7928CA"]).map {
            TextAdvancedStyleRenderer.parseHexColor($0).cgColor
        } as CFArray
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else {
            return
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) * 0.65
        context.drawRadialGradient(
            grad, startCenter: center, startRadius: 0.0,
            endCenter: center, endRadius: radius,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private static func drawBoxBorderIfNeeded(
        bg: TextBackgroundStyle,
        rect: CGRect,
        corner: CGFloat,
        in context: CGContext
    ) {
        guard bg.borderWidth > 0.2 else { return }
        let path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(TextAdvancedStyleRenderer.parseHexColor(bg.borderColorHex).cgColor)
        context.setLineWidth(CGFloat(bg.borderWidth))
        context.strokePath()
        context.restoreGState()
    }

    public static func fittedRect(
        for sourceSize: CGSize,
        in targetRect: CGRect,
        mode: TextBackgroundContentFitMode
    ) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return targetRect }
        switch mode {
        case .stretch:
            return targetRect
        case .fill:
            let s = max(targetRect.width / sourceSize.width, targetRect.height / sourceSize.height)
            let w = sourceSize.width * s
            let h = sourceSize.height * s
            return CGRect(x: targetRect.midX - w / 2.0, y: targetRect.midY - h / 2.0, width: w, height: h)
        case .fit:
            let s = min(targetRect.width / sourceSize.width, targetRect.height / sourceSize.height)
            let w = sourceSize.width * s
            let h = sourceSize.height * s
            return CGRect(x: targetRect.midX - w / 2.0, y: targetRect.midY - h / 2.0, width: w, height: h)
        }
    }

    private static func applyGPUFeather(radius: Double, to image: CIImage, extent: CGRect) -> CIImage {
        guard let blur = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: CGFloat(radius)
        ]), let output = blur.outputImage else {
            return image
        }
        return output.cropped(to: extent)
    }

    public static func blend(layerImage: CIImage, over background: CIImage, mode: TextLayerBlendMode) -> CIImage {
        guard mode != .normal,
              let filter = CIFilter(name: mode.ciFilterName, parameters: [
                  kCIInputImageKey: layerImage,
                  kCIInputBackgroundImageKey: background
              ]),
              let output = filter.outputImage else {
            return layerImage.composited(over: background)
        }
        return output
    }
    #endif
}
