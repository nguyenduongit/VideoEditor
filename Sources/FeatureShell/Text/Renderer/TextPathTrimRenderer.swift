import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

#if os(macOS)
/// Renders progressive vector `CGPath` stroke draw-on (`strokeTrimProgress`) with a glowing pen-nib highlight
/// and smooth cross-fade into the full styled typography fill.
public enum TextPathTrimRenderer: Sendable {
    private struct PolylineSegment {
        let start: CGPoint
        let end: CGPoint
        let length: CGFloat
    }

    private struct FlattenedSubpath {
        let segments: [PolylineSegment]
        let totalLength: CGFloat
    }

    private struct CachedFlattenedPath {
        let subpaths: [FlattenedSubpath]
        let totalLength: CGFloat
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var pathCache: [String: CachedFlattenedPath] = [:]

    public static func drawTrimmedGlyphPath(
        _ glyphPath: CGPath,
        pathBounds: CGRect,
        cacheKey: String,
        trimProgress: Double,
        config: TextConfiguration,
        in context: CGContext
    ) {
        let p = max(0.0, min(1.0, trimProgress))
        if p >= 0.999 {
            TextAdvancedStyleRenderer.drawStyledVectorGlyphPath(glyphPath, pathBounds: pathBounds, config: config, in: context)
            return
        }
        guard p > 0.005, !glyphPath.isEmpty else { return }

        let flattened = cachedFlattenedPath(for: glyphPath, key: cacheKey)
        guard flattened.totalLength > 0.5 else { return }

        let targetLength = flattened.totalLength * CGFloat(p)
        let (trimmedPath, nibPoint) = buildTrimmedPath(from: flattened, upTo: targetLength)
        let strokeColor = resolveStrokeColor(for: config)
        let outlineAlpha = p > 0.85 ? CGFloat((1.0 - p) / 0.15) : 1.0
        let lineW = max(2.0, CGFloat(config.fontSize) * 0.055)

        if outlineAlpha > 0.02 {
            context.saveGState()
            context.setAlpha(outlineAlpha)
            context.addPath(trimmedPath)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(lineW)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            if let nibPoint, p < 0.94 {
                drawPenNibDot(at: nibPoint, radius: lineW * 1.15, color: strokeColor, in: context)
            }
            context.restoreGState()
        }

        if p > 0.72 {
            let fillAlpha = CGFloat((p - 0.72) / 0.28)
            context.saveGState()
            context.setAlpha(max(0.0, min(1.0, fillAlpha)))
            TextAdvancedStyleRenderer.drawStyledVectorGlyphPath(glyphPath, pathBounds: pathBounds, config: config, in: context)
            context.restoreGState()
        }
    }

    private static func resolveStrokeColor(for config: TextConfiguration) -> NSColor {
        if config.colorFillMode == .linearGradient, let first = config.gradientColors.first,
           first.uppercased() != "NONE" {
            return TextAdvancedStyleRenderer.parseHexColor(first)
        }
        if config.textColorHex.uppercased() != "NONE" {
            return TextAdvancedStyleRenderer.parseHexColor(config.textColorHex)
        }
        return .white
    }

    private static func drawPenNibDot(at point: CGPoint, radius: CGFloat, color: NSColor, in context: CGContext) {
        let haloRect = CGRect(x: point.x - radius * 2.0, y: point.y - radius * 2.0, width: radius * 4.0, height: radius * 4.0)
        context.setFillColor(color.withAlphaComponent(0.35).cgColor)
        context.fillEllipse(in: haloRect)
        let coreRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2.0, height: radius * 2.0)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: coreRect)
    }

    private static func buildTrimmedPath(from flattened: CachedFlattenedPath, upTo targetLength: CGFloat) -> (CGPath, CGPoint?) {
        let outPath = CGMutablePath()
        var remaining = targetLength
        var tipPoint: CGPoint?

        for subpath in flattened.subpaths {
            guard remaining > 0.01 else { break }
            if remaining >= subpath.totalLength {
                appendSubpath(subpath.segments, to: outPath)
                remaining -= subpath.totalLength
                tipPoint = subpath.segments.last?.end
            } else {
                tipPoint = appendPartialSubpath(subpath.segments, budget: remaining, to: outPath)
                remaining = 0
            }
        }
        return (outPath, tipPoint)
    }

    private static func appendSubpath(_ segments: [PolylineSegment], to path: CGMutablePath) {
        guard let first = segments.first else { return }
        path.move(to: first.start)
        for seg in segments { path.addLine(to: seg.end) }
    }

    private static func appendPartialSubpath(_ segments: [PolylineSegment], budget: CGFloat, to path: CGMutablePath) -> CGPoint? {
        guard let first = segments.first else { return nil }
        var left = budget
        path.move(to: first.start)
        for seg in segments {
            if left >= seg.length {
                path.addLine(to: seg.end)
                left -= seg.length
            } else {
                let frac = seg.length > 0.001 ? (left / seg.length) : 0.0
                let pt = CGPoint(x: seg.start.x + (seg.end.x - seg.start.x) * frac, y: seg.start.y + (seg.end.y - seg.start.y) * frac)
                path.addLine(to: pt)
                return pt
            }
        }
        return segments.last?.end
    }

    private static func cachedFlattenedPath(for path: CGPath, key: String) -> CachedFlattenedPath {
        cacheLock.lock()
        if let cached = pathCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let built = flattenCGPath(path)
        cacheLock.lock()
        if pathCache.count > 256 { pathCache.removeAll(keepingCapacity: true) }
        pathCache[key] = built
        cacheLock.unlock()
        return built
    }

    private static func flattenCGPath(_ path: CGPath) -> CachedFlattenedPath {
        var subpaths: [FlattenedSubpath] = []
        var currentSegments: [PolylineSegment] = []
        var currentPt = CGPoint.zero
        var subpathStart = CGPoint.zero

        path.applyWithBlock { elementPtr in
            let el = elementPtr.pointee
            switch el.type {
            case .moveToPoint:
                if !currentSegments.isEmpty {
                    subpaths.append(FlattenedSubpath(segments: currentSegments, totalLength: currentSegments.reduce(0) { $0 + $1.length }))
                    currentSegments.removeAll(keepingCapacity: true)
                }
                currentPt = el.points[0]
                subpathStart = currentPt
            case .addLineToPoint:
                appendSegment(from: currentPt, to: el.points[0], into: &currentSegments)
                currentPt = el.points[0]
            case .addQuadCurveToPoint:
                flattenQuad(p0: currentPt, p1: el.points[0], p2: el.points[1], into: &currentSegments)
                currentPt = el.points[1]
            case .addCurveToPoint:
                flattenCubic(p0: currentPt, p1: el.points[0], p2: el.points[1], p3: el.points[2], into: &currentSegments)
                currentPt = el.points[2]
            case .closeSubpath:
                appendSegment(from: currentPt, to: subpathStart, into: &currentSegments)
                currentPt = subpathStart
            @unknown default: break
            }
        }
        if !currentSegments.isEmpty {
            subpaths.append(FlattenedSubpath(segments: currentSegments, totalLength: currentSegments.reduce(0) { $0 + $1.length }))
        }
        let total = subpaths.reduce(0) { $0 + $1.totalLength }
        return CachedFlattenedPath(subpaths: subpaths, totalLength: total)
    }

    private static func appendSegment(from a: CGPoint, to b: CGPoint, into list: inout [PolylineSegment]) {
        let len = hypot(b.x - a.x, b.y - a.y)
        if len > 0.05 { list.append(PolylineSegment(start: a, end: b, length: len)) }
    }

    private static func flattenQuad(p0: CGPoint, p1: CGPoint, p2: CGPoint, into list: inout [PolylineSegment]) {
        var prev = p0
        let steps = 8
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps), inv = 1.0 - t
            let pt = CGPoint(
                x: inv * inv * p0.x + 2 * inv * t * p1.x + t * t * p2.x,
                y: inv * inv * p0.y + 2 * inv * t * p1.y + t * t * p2.y
            )
            appendSegment(from: prev, to: pt, into: &list)
            prev = pt
        }
    }

    private static func flattenCubic(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, into list: inout [PolylineSegment]) {
        var prev = p0
        let steps = 10
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps), inv = 1.0 - t
            let pt = CGPoint(
                x: inv * inv * inv * p0.x + 3 * inv * inv * t * p1.x + 3 * inv * t * t * p2.x + t * t * t * p3.x,
                y: inv * inv * inv * p0.y + 3 * inv * inv * t * p1.y + 3 * inv * t * t * p2.y + t * t * t * p3.y
            )
            appendSegment(from: prev, to: pt, into: &list)
            prev = pt
        }
    }
}
#endif
