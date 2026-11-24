import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
import CoreText
#endif
import Domain

/// Segmented text renderer for Per-Line, Per-Word, Per-Character, and Karaoke Highlight animation.
public enum TextSegmentRenderer: Sendable {
    nonisolated(unsafe) private static let blurCIContext = CIContext(options: [.useSoftwareRenderer: false])

    public struct TextToken: Sendable {
        public let text: String
        public let relativeX: CGFloat
        public let width: CGFloat
        public let relativeY: CGFloat
        public let lineIndex: Int

        public init(text: String, relativeX: CGFloat, width: CGFloat, relativeY: CGFloat = 0.0, lineIndex: Int = 0) {
            self.text = text
            self.relativeX = relativeX
            self.width = width
            self.relativeY = relativeY
            self.lineIndex = lineIndex
        }
    }

    #if os(macOS)
    /// Splits single-line or multi-line text into positioned tokens respecting alignment.
    public static func tokenize(
        content: String, scope: TextAnimationScope, font: NSFont, spacing: Double, alignment: TextAlignmentType = .center
    ) -> (tokens: [TextToken], totalWidth: CGFloat) {
        computeTokens(content: content, scope: scope, font: font, spacing: spacing, alignment: alignment)
    }

    private struct MeasuredTokenLine {
        let text: String
        let ctLine: CTLine
        let width: CGFloat
        let height: CGFloat
    }

    public static func computeTokens(
        content: String, scope: TextAnimationScope, font: NSFont, spacing: Double, alignment: TextAlignmentType = .center
    ) -> (tokens: [TextToken], totalWidth: CGFloat) {
        guard !content.isEmpty else { return ([], 0) }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: CGFloat(spacing)]
        let measured: [MeasuredTokenLine] = content.components(separatedBy: "\n").map { lineText in
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: lineText, attributes: attrs))
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            let w = lineText.isEmpty ? 0.0 : CGFloat(CTLineGetTypographicBounds(ctLine, &asc, &desc, &lead))
            return MeasuredTokenLine(text: lineText, ctLine: ctLine, width: max(1.0, w), height: max(8.0, asc + desc + lead))
        }
        let maxLineW = max(1.0, measured.map(\.width).max() ?? 1.0)
        let lineStep = max(font.pointSize * 1.24, (measured.map(\.height).max() ?? font.pointSize) * 1.15)
        let totalSpanY = CGFloat(max(0, measured.count - 1)) * lineStep

        var tokens: [TextToken] = []
        for (lineIdx, line) in measured.enumerated() {
            let lineCenterY = (totalSpanY * 0.5) - CGFloat(lineIdx) * lineStep
            let alignOffsetX: CGFloat
            switch alignment {
            case .center: alignOffsetX = (maxLineW - line.width) * 0.5
            case .left: alignOffsetX = 0.0
            case .right: alignOffsetX = maxLineW - line.width
            }
            appendLineTokens(line, lineIdx: lineIdx, centerY: lineCenterY, alignX: alignOffsetX, scope: scope, into: &tokens)
        }
        return (tokens, maxLineW)
    }

    private static func appendLineTokens(
        _ line: MeasuredTokenLine,
        lineIdx: Int,
        centerY: CGFloat,
        alignX: CGFloat,
        scope: TextAnimationScope,
        into tokens: inout [TextToken]
    ) {
        if scope == .perLine || scope == .wholeBlock {
            tokens.append(TextToken(text: line.text, relativeX: alignX, width: line.width, relativeY: centerY, lineIndex: lineIdx))
            return
        }
        let rawUnits = scope == .perWord ? splitWordsPreservingSpaces(line.text) : line.text.map { String($0) }
        var utf16Cursor = 0
        for unit in rawUnits {
            let nextCursor = utf16Cursor + unit.utf16.count
            let xStart = CTLineGetOffsetForStringIndex(line.ctLine, utf16Cursor, nil)
            let xEnd = CTLineGetOffsetForStringIndex(line.ctLine, nextCursor, nil)
            tokens.append(TextToken(
                text: unit, relativeX: alignX + xStart, width: max(1.0, xEnd - xStart), relativeY: centerY, lineIndex: lineIdx
            ))
            utf16Cursor = nextCursor
        }
    }

    private static func splitWordsPreservingSpaces(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for char in text {
            if char.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
                result.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    /// Vẽ danh sách tokens với độ trễ theo hướng (stagger direction) và Karaoke Highlight
    public static func drawSegmentedText(
        tokens: [TextToken],
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let startX = -totalWidth / 2.0
        applySegmentedClipMask(
            totalWidth: totalWidth, totalHeight: totalHeight,
            baseConfig: baseConfig, localTime: localTime, duration: duration, canvasSize: canvasSize, in: context
        )
        let visibleIndices = tokens.indices.filter { !tokens[$0].text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !visibleIndices.isEmpty else { return }

        let globalProgress = min(0.9999, max(0.0, localTime / max(0.1, duration)))
        let exactWordPos = globalProgress * Double(visibleIndices.count)
        let activeOrder = Int(floor(exactWordPos))
        let wordLocalFrac = exactWordPos - Double(activeOrder)

        if baseConfig.animation.scriptId == "karaoke_box_pop" {
            drawKaraokeHighlightBox(
                tokens: tokens, visibleIndices: visibleIndices, activeOrder: activeOrder,
                localFrac: wordLocalFrac, startX: startX, totalHeight: totalHeight, baseConfig: baseConfig, in: context
            )
        }
        renderTokenLoop(
            tokens: tokens, visibleIndices: visibleIndices, activeOrder: activeOrder, wordLocalFrac: wordLocalFrac,
            startX: startX, baseConfig: baseConfig, font: font, localTime: localTime, duration: duration, canvasSize: canvasSize, in: context
        )
    }

    private static func applySegmentedClipMask(
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        if baseConfig.animation.isMaskEnabled {
            context.clip(to: CGRect(x: -totalWidth / 2.0 - 24, y: -totalHeight / 2.0 - 12, width: totalWidth + 48, height: totalHeight + 24))
        }
        let blockEval = TextAnimationEvaluator.evaluate(config: baseConfig, localTime: localTime, duration: duration, canvasSize: canvasSize)
        if blockEval.overlay.revealProgress >= 0.0 {
            let wipeW = (totalWidth + 48.0) * CGFloat(blockEval.overlay.revealProgress)
            context.clip(to: CGRect(x: -totalWidth / 2.0 - 24.0, y: -totalHeight / 2.0 - 24.0, width: wipeW, height: totalHeight + 48.0))
        }
    }

    private static func renderTokenLoop(
        tokens: [TextToken],
        visibleIndices: [Int],
        activeOrder: Int,
        wordLocalFrac: Double,
        startX: CGFloat,
        baseConfig: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let isKaraokeBox = baseConfig.animation.scriptId == "karaoke_box_pop"
        let isKaraokeGlow = baseConfig.animation.scriptId == "karaoke_glow_flow"
        let visibleCount = visibleIndices.count
        let tokenLineHeight = max(16.0, font.pointSize * 1.24)

        for (orderIndex, tokenIdx) in visibleIndices.enumerated() {
            let token = tokens[tokenIdx]
            var evaluated = evaluateTokenConfig(
                token: token, baseConfig: baseConfig, orderIndex: orderIndex, visibleCount: visibleCount,
                localTime: localTime, duration: duration, canvasSize: canvasSize
            )
            if evaluated.config.opacity <= 0.005 && evaluated.overlay.trailingCursorOpacity <= 0.01 { continue }
            if isKaraokeGlow || isKaraokeBox {
                applyKaraokeTokenStyle(
                    evaluated: &evaluated, isActive: orderIndex == activeOrder, localFrac: wordLocalFrac,
                    isGlowMode: isKaraokeGlow, highlightHex: baseConfig.animation.highlightColorHex
                )
            }
            let curvePt = resolveTokenWaveAndCurveCenter(
                evaluated: &evaluated, baseConfig: baseConfig, tokenCenter: startX + token.relativeX + token.width / 2.0,
                tokenRelativeY: token.relativeY, totalWidth: -startX * 2.0, orderIndex: orderIndex, visibleCount: visibleCount
            )
            drawSingleToken(
                evaluated.config, font: font, overlay: evaluated.overlay, center: curvePt,
                tokenWidth: token.width, totalHeight: tokenLineHeight, in: context
            )
        }
    }

    private static func evaluateTokenConfig(
        token: TextToken,
        baseConfig: TextConfiguration,
        orderIndex: Int,
        visibleCount: Int,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> TextAnimationEvaluator.EvaluationResult {
        var singleConfig = baseConfig
        singleConfig.content = token.text
        singleConfig.positionX = 0.0
        singleConfig.positionY = 0.0
        singleConfig.scale = 1.0
        singleConfig.rotation = 0.0
        singleConfig.opacity = 1.0
        singleConfig.blurRadius = 0.0

        var evaluated = TextAnimationEvaluator.evaluate(
            config: singleConfig, localTime: localTime, duration: duration,
            canvasSize: canvasSize, charIndex: orderIndex, charCount: visibleCount
        )
        evaluated.config.blurRadius = evaluated.blurRadius
        return evaluated
    }

    private static func drawSingleToken(
        _ config: TextConfiguration,
        font: NSFont,
        overlay: TextTransformOverlay,
        center: CGPoint,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        in context: CGContext
    ) {
        context.saveGState()
        applyTokenTransform(config, overlay: overlay, center: center, totalHeight: totalHeight, in: context)

        if config.opacity > 0.005 {
            if config.blurRadius > 0.4 {
                drawBlurredTokenGlyph(
                    config: config, font: font, overlay: overlay,
                    tokenWidth: tokenWidth, totalHeight: totalHeight, in: context
                )
            } else {
                renderTokenGlyphAndEchoes(
                    config: config, font: font, overlay: overlay,
                    tokenWidth: tokenWidth, totalHeight: totalHeight, in: context
                )
            }
        }
        if overlay.trailingCursorOpacity > 0.01 {
            drawTrailingCursorBar(
                config: config, font: font, tokenWidth: tokenWidth,
                totalHeight: totalHeight, cursorOpacity: overlay.trailingCursorOpacity, in: context
            )
        }
        context.restoreGState()
    }

    private static func applyTokenTransform(
        _ config: TextConfiguration,
        overlay: TextTransformOverlay,
        center: CGPoint,
        totalHeight: CGFloat,
        in context: CGContext
    ) {
        let pivotOffsetY: CGFloat
        switch config.animation.anchorPoint {
        case .center: pivotOffsetY = 0.0
        case .bottom: pivotOffsetY = -totalHeight / 2.0
        case .top: pivotOffsetY = totalHeight / 2.0
        }
        context.translateBy(x: center.x + CGFloat(config.positionX), y: center.y - CGFloat(config.positionY) + pivotOffsetY)
        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        let totalSkewX = overlay.skewX + tan(config.skewX * .pi / 180.0)
        let totalSkewY = tan(config.skewY * .pi / 180.0)
        if abs(totalSkewX) > 0.001 || abs(totalSkewY) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: CGFloat(totalSkewY), c: CGFloat(totalSkewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 {
            context.scaleBy(x: sx, y: sy)
        }
        context.translateBy(x: 0, y: -pivotOffsetY)
    }

    private static func drawBlurredTokenGlyph(
        config: TextConfiguration,
        font: NSFont,
        overlay: TextTransformOverlay,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        in context: CGContext
    ) {
        let blurR = min(28.0, config.blurRadius)
        let pad = ceil(CGFloat(blurR) * 2.5 + 16.0)
        let boxW = max(8, Int(ceil(tokenWidth + pad * 2.0)))
        let boxH = max(8, Int(ceil(totalHeight + pad * 2.0)))
        guard let scratch = CGContext(
            data: nil, width: boxW, height: boxH, bitsPerComponent: 8, bytesPerRow: boxW * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            renderTokenGlyphAndEchoes(
                config: config, font: font, overlay: overlay,
                tokenWidth: tokenWidth, totalHeight: totalHeight, in: context
            )
            return
        }
        let nsScratch = NSGraphicsContext(cgContext: scratch, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsScratch
        scratch.translateBy(x: CGFloat(boxW) / 2.0, y: CGFloat(boxH) / 2.0)
        renderTokenGlyphAndEchoes(
            config: config, font: font, overlay: overlay,
            tokenWidth: tokenWidth, totalHeight: totalHeight, in: scratch
        )
        NSGraphicsContext.restoreGraphicsState()

        let fullRect = CGRect(x: -CGFloat(boxW) / 2.0, y: -CGFloat(boxH) / 2.0, width: CGFloat(boxW), height: CGFloat(boxH))
        guard let cg = scratch.makeImage(),
              let filter = CIFilter(name: "CIGaussianBlur", parameters: [
                  kCIInputImageKey: CIImage(cgImage: cg),
                  kCIInputRadiusKey: blurR
              ])?.outputImage else {
            renderTokenGlyphAndEchoes(
                config: config, font: font, overlay: overlay,
                tokenWidth: tokenWidth, totalHeight: totalHeight, in: context
            )
            return
        }
        let cropRect = CGRect(x: 0, y: 0, width: boxW, height: boxH)
        if let blurredCG = blurCIContext.createCGImage(filter.cropped(to: cropRect), from: cropRect) {
            context.draw(blurredCG, in: fullRect)
        }
    }
    #endif
}
