import Foundation
import CoreGraphics
import CoreImage
import Metal
#if os(macOS)
import AppKit
#endif
import Domain

/// Thread-safe bounded GPU Glyph & Signed Distance Field Atlas cache (`colorTexture` + `.rgba16Float` `sdfTexture`).
/// Rasterizes CoreText vector paths into crisp supersampled scale buckets so magnified/animated glyphs never pixelate.
public final class TextGlyphAtlasCache: @unchecked Sendable {
    private struct AtlasKey: Hashable {
        let text: String
        let fontName: String
        let fontSizeCentipoints: Int
        let scaleBucketCentiscale: Int
        let isBold: Bool
        let isItalic: Bool
        let spacingCentipoints: Int
        let curve: TextCurveStyle
        let isUnderlined: Bool
        let preserveBaseline: Bool
        let alignment: TextAlignmentType
        let textColorHex: String
        let colorFillMode: TextColorFillMode
        let gradientColors: [String]
        let gradientAngleCentidegrees: Int
        let innerStroke: TextStrokeStyle
        let outerStroke: TextStrokeStyle
    }

    private static let scaleBuckets: [CGFloat] = [2.0, 3.0, 4.0, 6.0, 8.0]
    private let lock = NSLock()
    private var entries: [AtlasKey: TextGlyphAtlasEntry] = [:]
    private var lruOrder: [AtlasKey] = []
    private let capacity: Int

    public init(capacity: Int = 256) {
        self.capacity = max(16, capacity)
    }

    public func clearAll() {
        lock.lock()
        entries.removeAll()
        lruOrder.removeAll()
        lock.unlock()
    }

    public var cachedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    public static func quantizedScaleBucket(for requestedScale: CGFloat) -> CGFloat {
        let clamped = max(1.0, min(8.0, requestedScale))
        for bucket in scaleBuckets where clamped <= bucket {
            return bucket
        }
        return 8.0
    }

    #if os(macOS)
    public func entry(
        forText text: String,
        font: NSFont,
        config: TextConfiguration,
        requestedScale: CGFloat = 1.0,
        curveOverride: TextCurveStyle? = nil,
        preserveBaseline: Bool = false
    ) -> TextGlyphAtlasEntry? {
        guard !text.isEmpty, MetalComputeRuntimeEngine.shared.isAvailable else { return nil }
        let safeText = text.precomposedStringWithCanonicalMapping
        let effectiveCurve = curveOverride ?? config.curve
        let layout = TextRenderPerformanceCache.shared.cachedShapedLayout(
            text: safeText, font: font, config: config,
            curveOverride: effectiveCurve, preserveBaseline: preserveBaseline
        )
        let bucket = Self.quantizedScaleBucket(for: requestedScale)
        let effectiveScale = resolveClampedScale(
            requestedBucket: bucket, layout: layout, config: config
        )
        let key = makeKey(
            text: safeText, config: config, scaleCentiscale: Int((effectiveScale * 100.0).rounded()),
            curve: effectiveCurve, preserveBaseline: preserveBaseline
        )

        lock.lock()
        if let hit = entries[key] {
            touchLRU(key)
            lock.unlock()
            return hit
        }
        lock.unlock()

        guard let built = buildEntry(
            layout: layout, config: config, effectiveScale: effectiveScale
        ) else {
            return nil
        }

        lock.lock()
        if entries[key] == nil {
            if entries.count >= capacity, let evicted = lruOrder.first {
                lruOrder.removeFirst()
                entries.removeValue(forKey: evicted)
            }
            entries[key] = built
            lruOrder.append(key)
        }
        lock.unlock()
        return built
    }

    private func resolveClampedScale(
        requestedBucket: CGFloat,
        layout: TextCurvedPathBuilder.ShapedLayout,
        config: TextConfiguration
    ) -> CGFloat {
        let pathBox = layout.combinedPath.isEmpty ? layout.bounds : layout.combinedPath.boundingBoxOfPath.union(layout.bounds)
        let innerW = config.innerStroke.isEnabled ? max(0.0, config.innerStroke.width) : 0.0
        let outerW = config.outerStroke.isEnabled ? max(0.0, config.outerStroke.width) : 0.0
        let pad = ceil(max(24.0, (innerW + outerW) * 2.0 + 16.0))
        let logicalW = max(8.0, pathBox.width) + pad * 2.0
        let logicalH = max(8.0, pathBox.height) + pad * 2.0
        let maxTexDim: CGFloat = 2048.0
        let capScale = min(maxTexDim / logicalW, maxTexDim / logicalH)
        return max(1.0, min(requestedBucket, capScale))
    }

    private func buildEntry(
        layout: TextCurvedPathBuilder.ShapedLayout,
        config: TextConfiguration,
        effectiveScale: CGFloat
    ) -> TextGlyphAtlasEntry? {
        let pathBox = layout.combinedPath.isEmpty ? layout.bounds : layout.combinedPath.boundingBoxOfPath.union(layout.bounds)
        let innerW = config.innerStroke.isEnabled ? max(0.0, config.innerStroke.width) : 0.0
        let outerW = config.outerStroke.isEnabled ? max(0.0, config.outerStroke.width) : 0.0
        let strokePad = CGFloat((innerW + outerW) * 2.0)
        let pad = ceil(max(24.0, strokePad + 16.0))
        let logicalW = max(8.0, pathBox.width) + pad * 2.0
        let logicalH = max(8.0, pathBox.height) + pad * 2.0
        let texW = max(8, min(4096, Int(ceil(logicalW * effectiveScale))))
        let texH = max(8, min(4096, Int(ceil(logicalH * effectiveScale))))

        guard let cgCtx = CGContext(
            data: nil, width: texW, height: texH, bitsPerComponent: 8, bytesPerRow: texW * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        cgCtx.setShouldAntialias(true)
        cgCtx.setAllowsAntialiasing(true)
        cgCtx.interpolationQuality = .high
        let centerPxX = CGFloat(texW) * 0.5
        let centerPxY = CGFloat(texH) * 0.5
        cgCtx.translateBy(x: centerPxX, y: centerPxY)
        cgCtx.scaleBy(x: effectiveScale, y: effectiveScale)
        cgCtx.translateBy(x: -pathBox.midX, y: -pathBox.midY)
        TextAdvancedStyleRenderer.drawStyledVectorGlyphPath(layout.combinedPath, pathBounds: layout.bounds, config: config, in: cgCtx)
        TextCurvedPathBuilder.drawEmojiFallbacks(layout.emojiGlyphs, in: cgCtx)

        let jfaStride = min(64, max(16, Int((32.0 * effectiveScale).rounded())))
        guard let cgImg = cgCtx.makeImage(),
              let gpu = MetalComputeRuntimeEngine.shared.buildGlyphTexturesWithSDF(
                  from: CIImage(cgImage: cgImg),
                  pixelSize: CGSize(width: texW, height: texH),
                  jfaMaxStride: jfaStride
              ) else {
            return nil
        }

        let toLogical = CGAffineTransform(translationX: -centerPxX, y: -centerPxY)
            .concatenating(CGAffineTransform(scaleX: 1.0 / effectiveScale, y: 1.0 / effectiveScale))
            .concatenating(CGAffineTransform(translationX: pathBox.midX, y: pathBox.midY))
        let pixelSize = CGSize(width: texW, height: texH)
        let logicalExtent = CGRect(origin: .zero, size: pixelSize).applying(toLogical)
        let shiftedCI = gpu.colorCIImage.transformed(by: toLogical)
        return TextGlyphAtlasEntry(
            colorTexture: gpu.colorTexture,
            sdfTexture: gpu.sdfTexture,
            pixelSize: pixelSize,
            rasterScale: effectiveScale,
            toLogicalTransform: toLogical,
            rawPixelCIImage: gpu.colorCIImage,
            localExtent: logicalExtent,
            shapedBounds: layout.bounds,
            padding: pad,
            colorCIImage: shiftedCI
        )
    }

    private func makeKey(
        text: String, config: TextConfiguration, scaleCentiscale: Int,
        curve: TextCurveStyle, preserveBaseline: Bool
    ) -> AtlasKey {
        AtlasKey(
            text: text, fontName: config.fontName,
            fontSizeCentipoints: Int((max(6.0, config.fontSize) * 100.0).rounded()),
            scaleBucketCentiscale: scaleCentiscale,
            isBold: config.isBold, isItalic: config.isItalic,
            spacingCentipoints: Int((config.characterSpacing * 100.0).rounded()),
            curve: curve, isUnderlined: config.isUnderlined,
            preserveBaseline: preserveBaseline, alignment: config.alignment,
            textColorHex: config.textColorHex, colorFillMode: config.colorFillMode,
            gradientColors: config.gradientColors,
            gradientAngleCentidegrees: Int((config.gradientAngle * 100.0).rounded()),
            innerStroke: config.innerStroke, outerStroke: config.outerStroke
        )
    }

    private func touchLRU(_ key: AtlasKey) {
        if let idx = lruOrder.firstIndex(of: key) {
            lruOrder.remove(at: idx)
            lruOrder.append(key)
        }
    }
    #endif
}
