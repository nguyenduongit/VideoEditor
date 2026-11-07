import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất Nhãn dán (Sticker `.svg`, `.png`, `.gif`, `.apng`) ở 60fps.
/// Hỗ trợ rasterize Vector SVG trực tiếp ở độ phân giải sau phóng đại (`baseSize * scale`),
/// lật ngang/dọc, đổ bóng, hòa trộn Blend Mode và đồng bộ trọn vẹn hệ thống hoạt ảnh `In / Out / Loop`.
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public final class StickerRendererEngine: Sendable {
    public init() {}

    /// Kích thước cơ sở (chưa nhân `scale`) của Sticker theo khung hình Canvas.
    public static func baseStickerSize(for canvasSize: CGSize) -> CGSize {
        let side = max(32.0, round(min(canvasSize.width, canvasSize.height) * 0.22))
        return CGSize(width: side, height: side)
    }

    /// Hòa trộn Sticker lên nền `background` theo `blendMode` của `StickerConfiguration`.
    public func composite(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        over background: CIImage,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        guard let fg = renderStickerImage(
            config: config,
            clipProperties: clipProperties,
            localTime: localTime,
            duration: duration,
            canvasSize: canvasSize
        ) else {
            return background
        }

        if config.blendMode == .normal {
            return fg.composited(over: background).cropped(to: canvasRect)
        }
        guard let filter = CIFilter(name: config.blendMode.ciFilterName, parameters: [
            kCIInputImageKey: fg,
            kCIInputBackgroundImageKey: background
        ]), let out = filter.outputImage else {
            return fg.composited(over: background).cropped(to: canvasRect)
        }
        return out.cropped(to: canvasRect)
    }

    /// Kết xuất Sticker thành `CIImage` kích thước `canvasSize` (đã áp dụng Transform, Shadow & Animation).
    public func renderStickerImage(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let refSize = CanvasAspectRatio.closest(for: canvasSize).renderSize
        let coordScaleX = refSize.width > 0 ? Double(canvasSize.width / refSize.width) : 1.0
        let coordScaleY = refSize.height > 0 ? Double(canvasSize.height / refSize.height) : 1.0

        let rawPosX = (clipProperties["positionX"]?.asNumber ?? 0.0) * coordScaleX
        let rawPosY = (clipProperties["positionY"]?.asNumber ?? 0.0) * coordScaleY
        let rawScale = max(0.05, clipProperties["scale"]?.asNumber ?? 1.0)
        let rawRotation = clipProperties["rotation"]?.asNumber ?? 0.0
        let rawOpacity = max(0.0, min(1.0, clipProperties["opacity"]?.asNumber ?? 1.0))

        var animCarrier = TextConfiguration(
            content: "S",
            positionX: rawPosX,
            positionY: rawPosY,
            scale: rawScale,
            rotation: rawRotation,
            opacity: rawOpacity,
            animation: config.animation
        )
        animCarrier.animation.scope = .wholeBlock

        let evaluated = TextAnimationEvaluator.evaluate(
            config: animCarrier,
            localTime: localTime,
            duration: max(0.1, duration),
            canvasSize: canvasSize
        )
        guard evaluated.config.opacity > 0.002 else { return nil }

        let baseSize = Self.baseStickerSize(for: canvasSize)
        let effScaleX = max(0.02, evaluated.config.scale * evaluated.overlay.scaleX)
        let effScaleY = max(0.02, evaluated.config.scale * evaluated.overlay.scaleY)
        let rasterTarget = CGSize(
            width: max(32.0, min(4096.0, baseSize.width * CGFloat(effScaleX))),
            height: max(32.0, min(4096.0, baseSize.height * CGFloat(effScaleY)))
        )

        guard let sourceCG = resolveSourceCGImage(
            config: config,
            clipProperties: clipProperties,
            localTime: localTime,
            rasterTarget: rasterTarget
        ) else {
            return nil
        }

        return transformAndStyleSticker(
            sourceCG: sourceCG,
            config: config,
            evaluated: evaluated,
            baseSize: baseSize,
            effScaleX: effScaleX,
            effScaleY: effScaleY,
            canvasSize: canvasSize
        )
    }

    private func resolveSourceCGImage(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        localTime: Double,
        rasterTarget: CGSize
    ) -> CGImage? {
        if let svg = config.svgMarkup, !svg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let cg = TextSVGAndAssetCache.shared.rasterizeSVG(svg, targetSize: rasterTarget) {
                return cg
            }
        }

        if let srcPath = config.sourceURLString, !srcPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let speed = clipProperties["speed"]?.asNumber ?? config.playbackSpeed
            let loopRaw = clipProperties["loopMode"]?.asString ?? config.loopMode.rawValue
            let shouldLoop = (StickerLoopMode(rawValue: loopRaw) ?? config.loopMode) == .loop
            if let cg = TextSVGAndAssetCache.shared.frameForAsset(
                path: srcPath,
                localTime: localTime,
                loop: shouldLoop,
                speed: speed,
                targetSize: rasterTarget
            ) {
                return cg
            }
        }

        let symbol = clipProperties["systemSymbolFallback"]?.asString
            ?? config.systemSymbolFallback
            ?? "face.smiling"
        return TextSVGAndAssetCache.shared.rasterizeSymbol(
            name: symbol,
            tintHex: "#06B6D4",
            targetSize: rasterTarget
        )
    }

    private func transformAndStyleSticker(
        sourceCG: CGImage,
        config: StickerConfiguration,
        evaluated: TextAnimationEvaluator.EvaluationResult,
        baseSize: CGSize,
        effScaleX: Double,
        effScaleY: Double,
        canvasSize: CGSize
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var img = CIImage(cgImage: sourceCG)
        let srcW = max(1.0, CGFloat(sourceCG.width))
        let srcH = max(1.0, CGFloat(sourceCG.height))

        // Bảo toàn tỷ lệ khung hình thực tế của nguồn ảnh trong hộp baseSize * scale
        let aspect = srcW / srcH
        let targetW: CGFloat = aspect >= 1.0 ? baseSize.width * CGFloat(effScaleX) : baseSize.height * CGFloat(effScaleX) * aspect
        let targetH: CGFloat = aspect >= 1.0 ? (baseSize.width * CGFloat(effScaleY)) / aspect : baseSize.height * CGFloat(effScaleY)

        let flipX: CGFloat = config.flipHorizontal ? -1.0 : 1.0
        let flipY: CGFloat = config.flipVertical ? -1.0 : 1.0

        var transform = CGAffineTransform(translationX: -srcW / 2.0, y: -srcH / 2.0)
        transform = transform.concatenating(
            CGAffineTransform(scaleX: (targetW / srcW) * flipX, y: (targetH / srcH) * flipY)
        )
        if abs(evaluated.overlay.skewX) > 0.001 {
            transform = transform.concatenating(
                CGAffineTransform(a: 1, b: 0, c: CGFloat(evaluated.overlay.skewX), d: 1, tx: 0, ty: 0)
            )
        }
        if abs(evaluated.config.rotation) > 0.001 {
            let rad = CGFloat(-evaluated.config.rotation * .pi / 180.0)
            transform = transform.concatenating(CGAffineTransform(rotationAngle: rad))
        }
        let cx = canvasSize.width / 2.0 + CGFloat(evaluated.config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(evaluated.config.positionY)
        transform = transform.concatenating(CGAffineTransform(translationX: cx, y: cy))

        img = img.transformed(by: transform)

        if config.hasShadow {
            img = applyDropShadow(to: img, config: config, canvasRect: canvasRect)
        }

        img = TextShaderFilterEngine.applyFilters(
            to: img,
            blurRadius: evaluated.blurRadius,
            hueAngle: evaluated.hueAngle,
            pixelateScale: evaluated.pixelateScale,
            rgbSplitIntensity: evaluated.rgbSplitIntensity,
            overlay: evaluated.overlay,
            lightSweepIntensity: config.animation.lightSweepIntensity
        )

        img = TextSVGAndAssetCache.applyPremultipliedOpacity(evaluated.config.opacity, to: img)
        let clearCanvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: canvasRect)
        return img.cropped(to: canvasRect).composited(over: clearCanvas)
    }

    private func applyDropShadow(
        to image: CIImage,
        config: StickerConfiguration,
        canvasRect: CGRect
    ) -> CIImage {
        #if os(macOS)
        let nsColor = TextAdvancedStyleRenderer.parseHexColor(config.shadowColorHex)
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = srgb.redComponent
        let g = srgb.greenComponent
        let b = srgb.blueComponent
        let a = srgb.alphaComponent
        #else
        let (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0.6)
        #endif

        guard a > 0.01 else { return image }
        var shadow = image
        if let tint = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: shadow,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: a),
            "inputBiasVector": CIVector(x: r * a, y: g * a, z: b * a, w: 0)
        ])?.outputImage {
            shadow = tint
        }
        if config.shadowBlur > 0.2,
           let blurred = CIFilter(name: "CIGaussianBlur", parameters: [
               kCIInputImageKey: shadow,
               kCIInputRadiusKey: config.shadowBlur
           ])?.outputImage {
            shadow = blurred
        }
        shadow = shadow.transformed(
            by: CGAffineTransform(translationX: CGFloat(config.shadowOffsetX), y: CGFloat(-config.shadowOffsetY))
        ).cropped(to: canvasRect)
        return image.composited(over: shadow)
    }
}
