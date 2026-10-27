import Foundation
import CoreGraphics
import CoreImage
import AppKit

/// Thread-safe in-memory cache for rendered mask CIImages.
final class MaskImageCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: CIImage] = [:]
    private let maxEntries = 24

    func image(for key: String) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func store(_ image: CIImage, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        if cache.count >= maxEntries {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = image
    }
}

/// Generates high-performance CoreImage masks and applies them to video frames.
/// Complies with R3.1 and R9.4 of AGENTS.md.
public final class TimelineMaskGenerator: Sendable {
    private static let maskCache = MaskImageCache()
    private static let metalPipeline = TimelineMaskMetalPipeline()
    /// Applies mask parameters to the given source video image.
    public static func applyMask(
        to sourceImage: CIImage,
        params: TimelineMaskParameters,
        canvasSize: CGSize
    ) -> CIImage {
        guard params.isMaskActive,
              let maskImage = generateMask(for: params, canvasSize: canvasSize) else {
            return sourceImage
        }
        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            return sourceImage
        }
        blend.setValue(sourceImage, forKey: kCIInputImageKey)
        blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        blend.setValue(maskImage, forKey: kCIInputMaskImageKey)
        return blend.outputImage ?? sourceImage
    }

    /// Generates or retrieves a cached mask CIImage for given parameters and canvas size.
    public static func generateMask(
        for params: TimelineMaskParameters,
        canvasSize: CGSize
    ) -> CIImage? {
        guard params.isMaskActive else { return nil }
        let key = cacheKey(params: params, size: canvasSize)

        if let cached = maskCache.image(for: key) {
            return cached
        }

        guard let generated = buildMaskCIImage(params: params, canvasSize: canvasSize) else {
            return nil
        }

        maskCache.store(generated, for: key)
        return generated
    }

    private static func buildMaskCIImage(params: TimelineMaskParameters, canvasSize: CGSize) -> CIImage? {
        if metalPipeline.isAvailable,
           let gpuMask = metalPipeline.generateMask(params: params, canvasSize: canvasSize) {
            return gpuMask
        }
        return buildMaskCIImageCPUFallback(params: params, canvasSize: canvasSize)
    }

    private static func buildMaskCIImageCPUFallback(params: TimelineMaskParameters, canvasSize: CGSize) -> CIImage? {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(canvasSize.width)),
            pixelsHigh: max(1, Int(canvasSize.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        let cgCtx = context.cgContext

        cgCtx.setFillColor(NSColor.black.cgColor)
        cgCtx.fill(CGRect(origin: .zero, size: canvasSize))

        let cx: CGFloat
        let cy: CGFloat
        let rot: CGFloat

        if params.shape == .filmstrip {
            cx = canvasSize.width / 2.0
            cy = canvasSize.height / 2.0 + CGFloat(params.offsetY)
            rot = 0.0
        } else {
            cx = canvasSize.width / 2.0 + CGFloat(params.positionX)
            cy = canvasSize.height / 2.0 + CGFloat(params.positionY)
            rot = CGFloat(-params.rotation * .pi / 180.0)
        }

        cgCtx.saveGState()
        cgCtx.translateBy(x: cx, y: cy)
        if rot != 0.0 {
            cgCtx.rotate(by: rot)
        }
        cgCtx.setFillColor(NSColor.white.cgColor)

        drawShape(params: params, canvasSize: canvasSize, in: cgCtx)

        cgCtx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = rep.cgImage else { return nil }
        var ciMask = CIImage(cgImage: cgImage)

        if params.feather > 0.0 && (params.shape == .circle || params.shape == .rectangle),
           let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(ciMask, forKey: kCIInputImageKey)
            blur.setValue(params.feather * 150.0, forKey: kCIInputRadiusKey)
            if let blurred = blur.outputImage {
                ciMask = blurred.cropped(to: CGRect(origin: .zero, size: canvasSize))
            }
        }

        if params.invert, let inv = CIFilter(name: "CIColorInvert") {
            inv.setValue(ciMask, forKey: kCIInputImageKey)
            if let inverted = inv.outputImage {
                ciMask = inverted.cropped(to: CGRect(origin: .zero, size: canvasSize))
            }
        }

        return ciMask
    }

    private static func drawShape(params: TimelineMaskParameters, canvasSize: CGSize, in ctx: CGContext) {
        switch params.shape {
        case .split:
            drawSplit(feather: params.feather, canvasSize: canvasSize, in: ctx)
        case .filmstrip:
            drawFilmstrip(params: params, canvasSize: canvasSize, in: ctx)
        case .circle:
            ctx.setFillColor(NSColor.white.cgColor)
            let rx = max(1.0, params.radiusX)
            let ry = max(1.0, params.radiusY)
            ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2.0, height: ry * 2.0))
        case .rectangle:
            ctx.setFillColor(NSColor.white.cgColor)
            let w = max(1.0, params.width)
            let h = max(1.0, params.height)
            let cr = min(min(w, h) / 2.0, max(0.0, params.cornerRadius))
            let path = CGPath(roundedRect: CGRect(x: -w / 2.0, y: -h / 2.0, width: w, height: h),
                              cornerWidth: cr, cornerHeight: cr, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
        case .none:
            break
        }
    }

    private static func makeGaussianGradient() -> CGGradient? {
        let count = 21
        let c0 = 0.5 * (1.0 + erf(-3.0 / sqrt(2.0)))
        let c1 = 0.5 * (1.0 + erf(3.0 / sqrt(2.0)))
        var locations = [CGFloat]()
        var colors = [CGColor]()
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let u = (t - 0.5) * 6.0
            let c = 0.5 * (1.0 + erf(u / sqrt(2.0)))
            let val = CGFloat((c - c0) / (c1 - c0))
            locations.append(CGFloat(t))
            colors.append(NSColor(white: val, alpha: 1.0).cgColor)
        }
        return CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        )
    }

    private static func drawSplit(feather: Double, canvasSize: CGSize, in ctx: CGContext) {
        let fw = CGFloat(feather * 800.0)
        let dim = max(canvasSize.width, canvasSize.height) * 3.0
        if fw <= 0.0 {
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: -dim / 2.0, width: dim, height: dim))
            return
        }
        guard let gradient = makeGaussianGradient() else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: -fw / 2.0, y: 0),
            end: CGPoint(x: fw / 2.0, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private static func drawFilmstrip(params: TimelineMaskParameters, canvasSize: CGSize, in ctx: CGContext) {
        let filmH = max(1.0, CGFloat(params.filmHeight))
        let fw = CGFloat(params.feather * 800.0)
        let dim = max(canvasSize.width, canvasSize.height) * 3.0
        if fw <= 0.0 {
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: -dim / 2.0, y: -filmH / 2.0, width: dim, height: filmH))
            return
        }
        let (gradient, yStart, yEnd) = makeFilmstripGradient(filmH: filmH, fw: fw)
        guard let gradient else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: yStart),
            end: CGPoint(x: 0, y: yEnd),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private static func makeFilmstripGradient(filmH: CGFloat, fw: CGFloat) -> (CGGradient?, CGFloat, CGFloat) {
        let fade = min(fw, filmH)
        let yStart = -filmH / 2.0 - fw / 2.0
        let yEnd = filmH / 2.0 + fw / 2.0
        let totalSpan = max(1.0, yEnd - yStart)
        let count = 11
        let c0 = 0.5 * (1.0 + erf(-3.0 / sqrt(2.0)))
        let c1 = 0.5 * (1.0 + erf(3.0 / sqrt(2.0)))

        var locations = [CGFloat]()
        var colors = [CGColor]()

        let yBotPeak = -filmH / 2.0 + fade / 2.0
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let u = (t - 0.5) * 6.0
            let c = 0.5 * (1.0 + erf(u / sqrt(2.0)))
            let val = CGFloat((c - c0) / (c1 - c0))
            let y = yStart + CGFloat(t) * (yBotPeak - yStart)
            locations.append((y - yStart) / totalSpan)
            colors.append(NSColor(white: val, alpha: 1.0).cgColor)
        }

        let yTopStart = filmH / 2.0 - fade / 2.0
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let u = (t - 0.5) * 6.0
            let c = 0.5 * (1.0 + erf(u / sqrt(2.0)))
            let val = CGFloat(1.0 - (c - c0) / (c1 - c0))
            let y = yTopStart + CGFloat(t) * (yEnd - yTopStart)
            locations.append((y - yStart) / totalSpan)
            colors.append(NSColor(white: val, alpha: 1.0).cgColor)
        }

        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)
        return (grad, yStart, yEnd)
    }

    private static func cacheKey(params: TimelineMaskParameters, size: CGSize) -> String {
        "\(Int(size.width))x\(Int(size.height))-\(params.shape.rawValue)-\(params.invert)-\(params.feather)-\(params.positionX)-\(params.positionY)-\(params.rotation)-\(params.radiusX)-\(params.radiusY)-\(params.width)-\(params.height)-\(params.cornerRadius)-\(params.offsetY)-\(params.filmHeight)"
    }
}
