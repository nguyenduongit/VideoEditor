import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
import CoreText
#endif
import Domain

#if os(macOS)
/// Bộ dựng đường dẫn Vector chữ bằng CoreText (`CTLine` -> `CTRun` -> `CTFontCreatePathForGlyph`),
/// hỗ trợ cả chữ thẳng, Cung tròn (`Arc` -360°...+360°) và Sóng hình sin (`Sine Wave`),
/// bảo toàn 100% dấu tiếng Việt tổ hợp và ký tự Emoji màu.
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TextCurvedPathBuilder: Sendable {
    public struct EmojiGlyphDraw {
        public let font: CTFont
        public let glyph: CGGlyph
        public let position: CGPoint
        public let rotationRadians: CGFloat
    }

    public struct ShapedLayout {
        public let combinedPath: CGPath
        public let bounds: CGRect
        public let lineAdvanceWidth: CGFloat
        public let lineHeight: CGFloat
        public let emojiGlyphs: [EmojiGlyphDraw]
    }

    public static func buildShapedLayout(
        text: String,
        font: NSFont,
        characterSpacing: Double,
        curve: TextCurveStyle,
        isUnderlined: Bool = false,
        preserveBaseline: Bool = false
    ) -> ShapedLayout {
        let safeText = text.precomposedStringWithCanonicalMapping
        guard !safeText.isEmpty else {
            return ShapedLayout(combinedPath: CGMutablePath(), bounds: .zero, lineAdvanceWidth: 0, lineHeight: 0, emojiGlyphs: [])
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: CGFloat(characterSpacing)
        ]
        let attrStr = NSAttributedString(string: safeText, attributes: attrs)
        let ctLine = CTLineCreateWithAttributedString(attrStr)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let rawWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading))
        let totalWidth = max(1.0, rawWidth)
        let lineHeight = max(8.0, ascent + descent + leading)
        let baselineOffset = -(ascent - descent) / 2.0

        let combined = CGMutablePath()
        var emojis: [EmojiGlyphDraw] = []
        let runs = (CTLineGetGlyphRuns(ctLine) as? [CTRun]) ?? []

        for run in runs {
            appendRunGlyphs(
                run: run,
                totalWidth: totalWidth,
                baselineOffset: baselineOffset,
                curve: curve,
                into: combined,
                emojis: &emojis
            )
        }
        if isUnderlined && !curve.isActive && !combined.isEmpty {
            let pathBox = combined.boundingBoxOfPath
            let thickness = max(2.0, font.pointSize * 0.065)
            let underlineY = baselineOffset - max(3.0, descent * 0.45) - thickness / 2.0
            let barRect = CGRect(x: pathBox.minX, y: underlineY, width: max(4.0, pathBox.width), height: thickness)
            combined.addRoundedRect(in: barRect, cornerWidth: thickness / 2.0, cornerHeight: thickness / 2.0)
        }
        if preserveBaseline {
            let typographicBounds = CGRect(
                x: -totalWidth / 2.0,
                y: -lineHeight / 2.0,
                width: totalWidth,
                height: lineHeight
            )
            return ShapedLayout(
                combinedPath: combined,
                bounds: typographicBounds,
                lineAdvanceWidth: totalWidth,
                lineHeight: lineHeight,
                emojiGlyphs: emojis
            )
        }
        return makeCenteredLayout(
            combined: combined,
            totalWidth: totalWidth,
            lineHeight: lineHeight,
            emojis: emojis
        )
    }

    private static func makeCenteredLayout(
        combined: CGMutablePath,
        totalWidth: CGFloat,
        lineHeight: CGFloat,
        emojis: [EmojiGlyphDraw]
    ) -> ShapedLayout {
        let rawBounds = combined.isEmpty
            ? CGRect(x: -totalWidth / 2.0, y: -lineHeight / 2.0, width: totalWidth, height: lineHeight)
            : combined.boundingBoxOfPath

        let centerShiftX = rawBounds.midX
        let centerShiftY = rawBounds.midY
        if abs(centerShiftX) > 0.001 || abs(centerShiftY) > 0.001 {
            var centering = CGAffineTransform(translationX: -centerShiftX, y: -centerShiftY)
            let centeredPath = combined.copy(using: &centering) ?? combined
            let centeredEmojis = emojis.map { item in
                EmojiGlyphDraw(
                    font: item.font,
                    glyph: item.glyph,
                    position: CGPoint(x: item.position.x - centerShiftX, y: item.position.y - centerShiftY),
                    rotationRadians: item.rotationRadians
                )
            }
            let centeredBounds = CGRect(
                x: -rawBounds.width / 2.0,
                y: -rawBounds.height / 2.0,
                width: rawBounds.width,
                height: rawBounds.height
            )
            return ShapedLayout(
                combinedPath: centeredPath,
                bounds: centeredBounds,
                lineAdvanceWidth: max(totalWidth, rawBounds.width),
                lineHeight: rawBounds.height,
                emojiGlyphs: centeredEmojis
            )
        }

        return ShapedLayout(
            combinedPath: combined,
            bounds: rawBounds,
            lineAdvanceWidth: totalWidth,
            lineHeight: lineHeight,
            emojiGlyphs: emojis
        )
    }

    private static func appendRunGlyphs(
        run: CTRun,
        totalWidth: CGFloat,
        baselineOffset: CGFloat,
        curve: TextCurveStyle,
        into combined: CGMutablePath,
        emojis: inout [EmojiGlyphDraw]
    ) {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else { return }
        let runAttrs = CTRunGetAttributes(run) as NSDictionary
        guard let nsFont = runAttrs[kCTFontAttributeName] as? NSFont else { return }
        let ctFont = nsFont as CTFont

        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        var advances = [CGSize](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
        CTRunGetPositions(run, CFRangeMake(0, 0), &positions)
        CTRunGetAdvances(run, CFRangeMake(0, 0), &advances)

        for idx in 0..<count {
            let glyph = glyphs[idx]
            let advW = advances[idx].width
            let glyphOriginX = positions[idx].x - totalWidth / 2.0
            let glyphCenterX = glyphOriginX + advW / 2.0

            let (curvePoint, tangentAngle) = evaluateCurve(
                x: glyphCenterX,
                totalWidth: totalWidth,
                baselineOffset: baselineOffset,
                curve: curve
            )

            var transform = CGAffineTransform(translationX: curvePoint.x, y: curvePoint.y)
            if curve.isActive && curve.followTangent && abs(tangentAngle) > 0.0005 {
                transform = transform.rotated(by: tangentAngle)
            }
            transform = transform.translatedBy(x: -advW / 2.0, y: positions[idx].y)

            if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, &transform) {
                combined.addPath(glyphPath)
            } else {
                let rot = (curve.isActive && curve.followTangent) ? tangentAngle : 0.0
                let drawPos = CGPoint(x: curvePoint.x - advW / 2.0, y: curvePoint.y + positions[idx].y)
                emojis.append(EmojiGlyphDraw(font: ctFont, glyph: glyph, position: drawPos, rotationRadians: rot))
            }
        }
    }

    public static func evaluateCurve(
        x: CGFloat,
        totalWidth: CGFloat,
        baselineOffset: CGFloat,
        curve: TextCurveStyle
    ) -> (point: CGPoint, tangentRadians: CGFloat) {
        switch curve.shape {
        case .none:
            return (CGPoint(x: x, y: baselineOffset), 0.0)

        case .arc:
            let deg = curve.angleDegrees
            guard abs(deg) > 0.5 else {
                return (CGPoint(x: x, y: baselineOffset), 0.0)
            }
            let totalRad = CGFloat(deg * .pi / 180.0)
            let baseRadius = max(30.0, totalWidth / max(0.05, abs(totalRad)))
            let radius = max(24.0, baseRadius + CGFloat(curve.radiusOffset))
            let theta = x / radius
            if deg > 0 {
                let px = radius * sin(theta)
                let py = (radius * cos(theta) - radius) + baselineOffset
                return (CGPoint(x: px, y: py), -theta)
            } else {
                let px = radius * sin(theta)
                let py = (radius - radius * cos(theta)) + baselineOffset
                return (CGPoint(x: px, y: py), theta)
            }

        case .wave:
            let amp = CGFloat(curve.waveAmplitude)
            guard abs(amp) > 0.5 else {
                return (CGPoint(x: x, y: baselineOffset), 0.0)
            }
            let wl = max(40.0, CGFloat(curve.wavelength))
            let k = (2.0 * .pi) / wl
            let py = amp * sin(k * x) + baselineOffset
            let slope = amp * k * cos(k * x)
            return (CGPoint(x: x, y: py), atan(slope))
        }
    }

    public static func drawEmojiFallbacks(_ emojis: [EmojiGlyphDraw], in context: CGContext) {
        guard !emojis.isEmpty else { return }
        for item in emojis {
            context.saveGState()
            context.translateBy(x: item.position.x, y: item.position.y)
            if abs(item.rotationRadians) > 0.0005 {
                context.rotate(by: item.rotationRadians)
            }
            var g = item.glyph
            var zero = CGPoint.zero
            CTFontDrawGlyphs(item.font, &g, &zero, 1, context)
            context.restoreGState()
        }
    }
}
#endif
