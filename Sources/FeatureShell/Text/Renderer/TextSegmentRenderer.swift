import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
import CoreText
#endif
import Domain

/// Kết xuất văn bản phân cấp theo từng ký tự (Per-Character), từng từ (Per-Word) và Karaoke Highlight.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public enum TextSegmentRenderer: Sendable {
    public struct TextToken: Sendable {
        public let text: String
        public let relativeX: CGFloat
        public let width: CGFloat
    }

    #if os(macOS)
    /// Chia tách văn bản đơn dòng thành danh sách token kèm toạ độ x tương đối
    public static func tokenize(
        content: String, scope: TextAnimationScope, font: NSFont, spacing: Double
    ) -> (tokens: [TextToken], totalWidth: CGFloat) {
        computeTokens(content: content, scope: scope, font: font, spacing: spacing)
    }

    public static func computeTokens(
        content: String, scope: TextAnimationScope, font: NSFont, spacing: Double
    ) -> (tokens: [TextToken], totalWidth: CGFloat) {
        guard !content.isEmpty else { return ([], 0) }
        let rawUnits: [String]
        switch scope {
        case .wholeBlock: rawUnits = [content]
        case .perWord: rawUnits = splitWordsPreservingSpaces(content)
        case .perCharacter: rawUnits = content.map { String($0) }
        }

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: CGFloat(spacing)]
        let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: content, attributes: attrs))
        let fullTypoWidth = max(1.0, CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil)))

        var tokens: [TextToken] = []
        var utf16Cursor = 0
        for unit in rawUnits {
            let nextCursor = utf16Cursor + unit.utf16.count
            let xStart = CTLineGetOffsetForStringIndex(ctLine, utf16Cursor, nil)
            let xEnd = CTLineGetOffsetForStringIndex(ctLine, nextCursor, nil)
            tokens.append(TextToken(text: unit, relativeX: xStart, width: max(1.0, xEnd - xStart)))
            utf16Cursor = nextCursor
        }
        return (tokens, fullTypoWidth)
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
        if baseConfig.animation.isMaskEnabled {
            let clipRect = CGRect(
                x: -totalWidth / 2.0 - 24,
                y: -totalHeight / 2.0 - 12,
                width: totalWidth + 48,
                height: totalHeight + 24
            )
            context.clip(to: clipRect)
        }

        let blockEval = TextAnimationEvaluator.evaluate(
            config: baseConfig, localTime: localTime, duration: duration, canvasSize: canvasSize
        )
        if blockEval.overlay.revealProgress >= 0.0 {
            let wipeW = (totalWidth + 48.0) * CGFloat(blockEval.overlay.revealProgress)
            let wipeRect = CGRect(
                x: -totalWidth / 2.0 - 24.0,
                y: -totalHeight / 2.0 - 24.0,
                width: wipeW,
                height: totalHeight + 48.0
            )
            context.clip(to: wipeRect)
        }

        let visibleIndices = tokens.indices.filter { !tokens[$0].text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !visibleIndices.isEmpty else { return }

        let safeDur = max(0.1, duration)
        let globalProgress = min(0.9999, max(0.0, localTime / safeDur))
        let exactWordPos = globalProgress * Double(visibleIndices.count)
        let activeOrder = Int(floor(exactWordPos))
        let wordLocalFrac = exactWordPos - Double(activeOrder)

        if baseConfig.animation.comboType == .karaokeBox {
            drawKaraokeHighlightBox(
                tokens: tokens, visibleIndices: visibleIndices,
                activeOrder: activeOrder, localFrac: wordLocalFrac,
                startX: startX, totalHeight: totalHeight,
                baseConfig: baseConfig, in: context
            )
        }

        renderTokenLoop(
            tokens: tokens, visibleIndices: visibleIndices,
            activeOrder: activeOrder, wordLocalFrac: wordLocalFrac,
            startX: startX, totalHeight: totalHeight,
            baseConfig: baseConfig, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, in: context
        )
    }

    private static func renderTokenLoop(
        tokens: [TextToken],
        visibleIndices: [Int],
        activeOrder: Int,
        wordLocalFrac: Double,
        startX: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        in context: CGContext
    ) {
        let isKaraokeBox = baseConfig.animation.comboType == .karaokeBox
        let isKaraokeGlow = baseConfig.animation.comboType == .karaokeGlow
        let visibleCount = visibleIndices.count

        let effectiveStaggerDelay: Double
        let inDur = baseConfig.animation.inDuration
        if inDur > 0.05, visibleCount > 1 {
            let maxTotalStagger = inDur * 0.55
            let computed = maxTotalStagger / Double(visibleCount - 1)
            effectiveStaggerDelay = max(0.012, min(0.06, computed))
        } else {
            effectiveStaggerDelay = baseConfig.animation.staggerDelay
        }

        for (orderIndex, tokenIdx) in visibleIndices.enumerated() {
            let token = tokens[tokenIdx]
            let itemLocalTime: Double
            if baseConfig.animation.hasScriptAnimation {
                itemLocalTime = localTime
            } else {
                let staggerOrder = TextAnimationCurves.staggerOrderIndex(
                    index: orderIndex, count: visibleCount, direction: baseConfig.animation.staggerDirection
                )
                let tokenDelay = staggerOrder * effectiveStaggerDelay
                let rawItemTime = localTime - tokenDelay
                if rawItemTime < 0, baseConfig.animation.hasInAnimation {
                    continue
                }
                itemLocalTime = max(0.0, rawItemTime)
            }

            var singleConfig = baseConfig
            singleConfig.content = token.text
            singleConfig.positionX = 0.0
            singleConfig.positionY = 0.0
            singleConfig.scale = 1.0
            singleConfig.rotation = 0.0
            singleConfig.opacity = 1.0

            var evaluated = TextAnimationEvaluator.evaluate(
                config: singleConfig, localTime: itemLocalTime,
                duration: duration, canvasSize: canvasSize,
                charIndex: orderIndex, charCount: visibleCount
            )
            if evaluated.config.opacity <= 0.005 && evaluated.overlay.trailingCursorOpacity <= 0.01 {
                continue
            }

            if isKaraokeGlow || isKaraokeBox {
                applyKaraokeTokenStyle(
                    evaluated: &evaluated, isActive: orderIndex == activeOrder,
                    localFrac: wordLocalFrac, isGlowMode: isKaraokeGlow,
                    highlightHex: baseConfig.animation.highlightColorHex
                )
            }

            let tokenCenter = startX + token.relativeX + token.width / 2.0
            let curvePt = resolveTokenWaveAndCurveCenter(
                evaluated: &evaluated,
                baseConfig: baseConfig,
                tokenCenter: tokenCenter,
                totalWidth: -startX * 2.0,
                orderIndex: orderIndex,
                visibleCount: visibleCount
            )
            drawSingleToken(
                evaluated.config, font: font, overlay: evaluated.overlay,
                center: curvePt,
                tokenWidth: token.width,
                totalHeight: totalHeight,
                in: context
            )
        }
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
        let pivotOffsetY: CGFloat
        switch config.animation.anchorPoint {
        case .center: pivotOffsetY = 0.0
        case .bottom: pivotOffsetY = -totalHeight / 2.0
        case .top: pivotOffsetY = totalHeight / 2.0
        }

        context.translateBy(
            x: center.x + CGFloat(config.positionX),
            y: center.y - CGFloat(config.positionY) + pivotOffsetY
        )
        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        let radSkewX = config.skewX * .pi / 180.0
        let radSkewY = config.skewY * .pi / 180.0
        let totalSkewX = overlay.skewX + tan(radSkewX)
        let totalSkewY = tan(radSkewY)
        if abs(totalSkewX) > 0.001 || abs(totalSkewY) > 0.001 {
            context.concatenate(CGAffineTransform(a: 1, b: CGFloat(totalSkewY), c: CGFloat(totalSkewX), d: 1, tx: 0, ty: 0))
        }
        let sx = CGFloat(max(0.01, config.scale * overlay.scaleX))
        let sy = CGFloat(max(0.01, config.scale * overlay.scaleY))
        if abs(sx - 1.0) > 0.001 || abs(sy - 1.0) > 0.001 {
            context.scaleBy(x: sx, y: sy)
        }
        context.translateBy(x: 0, y: -pivotOffsetY)

        if config.opacity > 0.005 {
            renderTokenGlyphAndEchoes(
                config: config,
                font: font,
                overlay: overlay,
                tokenWidth: tokenWidth,
                totalHeight: totalHeight,
                in: context
            )
        }

        if overlay.trailingCursorOpacity > 0.01 {
            drawTrailingCursorBar(
                config: config,
                font: font,
                tokenWidth: tokenWidth,
                totalHeight: totalHeight,
                cursorOpacity: overlay.trailingCursorOpacity,
                in: context
            )
        }
        context.restoreGState()
    }
    #endif
}
