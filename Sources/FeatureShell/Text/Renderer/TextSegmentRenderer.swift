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
        _ line: MeasuredTokenLine, lineIdx: Int, centerY: CGFloat, alignX: CGFloat,
        scope: TextAnimationScope, into tokens: inout [TextToken]
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

    /// Vẽ danh sách tokens với độ trễ theo hướng (stagger direction), Karaoke Highlight và shader riêng từng đơn vị.
    @discardableResult
    public static func drawSegmentedText(
        tokens: [TextToken],
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double] = [:],
        renderPlugins: TextAnimationRenderPluginPipeline = TextAnimationRenderPluginPipeline(),
        in context: CGContext
    ) -> TextShaderFilterEngine.AppliedStagesMask {
        let startX = -totalWidth / 2.0
        applySegmentedClipMask(
            totalWidth: totalWidth, totalHeight: totalHeight, baseConfig: baseConfig,
            localTime: localTime, duration: duration, canvasSize: canvasSize,
            animationInputs: animationInputs, in: context
        )
        let visibleIndices = tokens.indices.filter { !tokens[$0].text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !visibleIndices.isEmpty else { return [] }

        let globalProgress = min(0.9999, max(0.0, localTime / max(0.1, duration)))
        let exactWordPos = globalProgress * Double(visibleIndices.count)
        let activeOrder = Int(floor(exactWordPos))
        let wordLocalFrac = exactWordPos - Double(activeOrder)

        return renderTokenLoop(
            tokens: tokens, visibleIndices: visibleIndices, activeOrder: activeOrder, wordLocalFrac: wordLocalFrac,
            startX: startX, baseConfig: baseConfig, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs, renderPlugins: renderPlugins, in: context
        )
    }

    private static func applySegmentedClipMask(
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double],
        in context: CGContext
    ) {
        if baseConfig.animation.isMaskEnabled {
            context.clip(to: CGRect(x: -totalWidth / 2.0 - 24, y: -totalHeight / 2.0 - 12, width: totalWidth + 48, height: totalHeight + 24))
        }
        let blockEval = TextAnimationEvaluator.evaluate(
            config: baseConfig, localTime: localTime, duration: duration,
            canvasSize: canvasSize, externalInputs: animationInputs
        )
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
        animationInputs: [String: Double],
        renderPlugins: TextAnimationRenderPluginPipeline,
        in context: CGContext
    ) -> TextShaderFilterEngine.AppliedStagesMask {
        let isKaraokeGlow = baseConfig.animation.scriptId == "karaoke_glow_flow"
        let visibleCount = visibleIndices.count
        let tokenLineHeight = max(16.0, font.pointSize * 1.24)
        var appliedMask: TextShaderFilterEngine.AppliedStagesMask = []

        for (orderIndex, tokenIdx) in visibleIndices.enumerated() {
            let token = tokens[tokenIdx]
            var evaluated = evaluateTokenConfig(
                token: token, baseConfig: baseConfig, orderIndex: orderIndex, visibleCount: visibleCount,
                localTime: localTime, duration: duration, canvasSize: canvasSize, animationInputs: animationInputs
            )
            if evaluated.config.opacity <= 0.005 && evaluated.overlay.trailingCursorOpacity <= 0.01 { continue }
            if evaluated.overlay.scrambleStrength > 0.01 {
                evaluated.config.content = TextTokenFXRenderer.resolveDisplayText(
                    evaluated.config.content, scrambleStrength: evaluated.overlay.scrambleStrength, unitIndex: orderIndex
                )
            }
            if isKaraokeGlow {
                applyKaraokeTokenStyle(
                    evaluated: &evaluated, isActive: orderIndex == activeOrder, localFrac: wordLocalFrac,
                    isGlowMode: true
                )
            }
            let curvePt = resolveTokenWaveAndCurveCenter(
                evaluated: &evaluated, baseConfig: baseConfig, tokenCenter: startX + token.relativeX + token.width / 2.0,
                tokenRelativeY: token.relativeY, totalWidth: -startX * 2.0, orderIndex: orderIndex, visibleCount: visibleCount
            )
            let tokenMask = TextTokenFXRenderer.perTokenStages(evaluated: evaluated, baseConfig: baseConfig, plugins: renderPlugins)
            appliedMask.formUnion(tokenMask)
            let pluginCtx = TextAnimationRenderPluginContext(
                localTime: localTime, duration: duration, canvasSize: canvasSize,
                unitIndex: orderIndex, unitCount: visibleCount
            )
            drawSingleToken(
                evaluated, baseMask: tokenMask, font: font, center: curvePt,
                tokenWidth: token.width, totalHeight: tokenLineHeight,
                localTime: localTime, pluginContext: pluginCtx, renderPlugins: renderPlugins,
                blockRotationDegrees: baseConfig.rotation, in: context
            )
        }
        return appliedMask
    }

    private static func evaluateTokenConfig(
        token: TextToken,
        baseConfig: TextConfiguration,
        orderIndex: Int,
        visibleCount: Int,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double]
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
            canvasSize: canvasSize, charIndex: orderIndex, charCount: visibleCount,
            externalInputs: animationInputs
        )
        evaluated.config.blurRadius = evaluated.blurRadius
        return evaluated
    }

    private static func drawSingleToken(
        _ evaluated: TextAnimationEvaluator.EvaluationResult,
        baseMask: TextShaderFilterEngine.AppliedStagesMask,
        font: NSFont,
        center: CGPoint,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        localTime: Double,
        pluginContext: TextAnimationRenderPluginContext,
        renderPlugins: TextAnimationRenderPluginPipeline,
        blockRotationDegrees: Double = 0.0,
        in context: CGContext
    ) {
        let config = evaluated.config
        let overlay = evaluated.overlay
        context.saveGState()
        applyTokenTransform(config, overlay: overlay, center: center, totalHeight: totalHeight, in: context)

        if config.opacity > 0.005 {
            if !baseMask.isEmpty {
                TextTokenFXRenderer.drawTokenWithFX(
                    evaluated: evaluated, font: font, tokenWidth: tokenWidth, totalHeight: totalHeight,
                    localTime: localTime, pluginContext: pluginContext, plugins: renderPlugins,
                    totalRotationDegrees: blockRotationDegrees + config.rotation,
                    renderGlyphBlock: { cfg, fnt, ov, w, h, ctx in
                        renderTokenGlyphAndEchoes(config: cfg, font: fnt, overlay: ov, tokenWidth: w, totalHeight: h, in: ctx)
                    },
                    in: context
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
    #endif
}
