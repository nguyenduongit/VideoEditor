import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

#if os(macOS)
/// Pure-GPU per-line / per-word / per-character compositor using cached glyph & SDF textures.
enum TextGPUSegmentedRenderer {
    static func renderSegmentedGPU(
        tokens: [TextSegmentRenderer.TextToken],
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        baseConfig: TextConfiguration,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double],
        renderPlugins: TextAnimationRenderPluginPipeline,
        atlasCache: TextGlyphAtlasCache
    ) -> (image: CIImage, handledStages: TextShaderFilterEngine.AppliedStagesMask)? {
        guard MetalComputeRuntimeEngine.shared.isAvailable else { return nil }
        let visibleIndices = tokens.indices.filter { !tokens[$0].text.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !visibleIndices.isEmpty else { return nil }

        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var accImage = CIImage.clear.cropped(to: canvasRect)
        var appliedMask: TextShaderFilterEngine.AppliedStagesMask = []

        let startX = -totalWidth / 2.0
        let globalProgress = min(0.9999, max(0.0, localTime / max(0.1, duration)))
        let exactWordPos = globalProgress * Double(visibleIndices.count)
        let activeOrder = Int(floor(exactWordPos))
        let wordLocalFrac = exactWordPos - Double(activeOrder)
        let isKaraokeGlow = baseConfig.animation.scriptId == "karaoke_glow_flow"

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        let safeguard: CGFloat = (totalWidth > maxSafeW && totalWidth > 0) ? (maxSafeW / totalWidth) : 1.0
        let blockTransform = TextGPUGlyphRenderer.makeBlockTransform(
            config: baseConfig, canvasSize: canvasSize, safeguardScale: safeguard
        )

        let tokenLineHeight = max(16.0, font.pointSize * 1.24)
        guard let tokenPass = compositeTokenLoop(
            tokens: tokens, visibleIndices: visibleIndices, activeOrder: activeOrder,
            wordLocalFrac: wordLocalFrac, startX: startX, totalWidth: totalWidth,
            tokenLineHeight: tokenLineHeight, isKaraokeGlow: isKaraokeGlow,
            baseConfig: baseConfig, font: font, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs,
            blockTransform: blockTransform, renderPlugins: renderPlugins, atlasCache: atlasCache, into: accImage
        ) else {
            return nil
        }
        accImage = tokenPass.image
        appliedMask = tokenPass.mask

        accImage = applyBlockClipMask(
            to: accImage, totalWidth: totalWidth, totalHeight: totalHeight,
            baseConfig: baseConfig, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs, blockTransform: blockTransform
        )
        return (TextSVGAndAssetCache.applyPremultipliedOpacity(baseConfig.opacity, to: accImage.cropped(to: canvasRect)), appliedMask)
    }

    private static func compositeTokenLoop(
        tokens: [TextSegmentRenderer.TextToken], visibleIndices: [Int], activeOrder: Int,
        wordLocalFrac: Double, startX: CGFloat, totalWidth: CGFloat, tokenLineHeight: CGFloat,
        isKaraokeGlow: Bool, baseConfig: TextConfiguration,
        font: NSFont, localTime: Double, duration: Double, canvasSize: CGSize,
        animationInputs: [String: Double], blockTransform: CGAffineTransform,
        renderPlugins: TextAnimationRenderPluginPipeline, atlasCache: TextGlyphAtlasCache,
        into initialImage: CIImage
    ) -> (image: CIImage, mask: TextShaderFilterEngine.AppliedStagesMask)? {
        var accImage = initialImage
        var appliedMask: TextShaderFilterEngine.AppliedStagesMask = []
        var depthEntries: [TextGPUSegmentedDepthSorter.DepthEntry] = []

        for (orderIndex, tokenIdx) in visibleIndices.enumerated() {
            var evaluated = evaluateToken(
                token: tokens[tokenIdx], baseConfig: baseConfig, orderIndex: orderIndex,
                visibleCount: visibleIndices.count, localTime: localTime, duration: duration,
                canvasSize: canvasSize, animationInputs: animationInputs
            )
            if evaluated.config.opacity <= 0.005 && evaluated.overlay.trailingCursorOpacity <= 0.01 { continue }
            if evaluated.overlay.strokeTrimProgress < 0.999 { return nil }
            prepareTokenAppearance(
                evaluated: &evaluated, token: tokens[tokenIdx], startX: startX, totalWidth: totalWidth,
                orderIndex: orderIndex, visibleCount: visibleIndices.count, activeOrder: activeOrder,
                wordLocalFrac: wordLocalFrac, isKaraokeGlow: isKaraokeGlow,
                baseConfig: baseConfig
            )
            let curvePt = evaluated.config.content.isEmpty ? .zero : TextSegmentRenderer.resolveTokenWaveAndCurveCenter(
                evaluated: &evaluated, baseConfig: baseConfig,
                tokenCenter: startX + tokens[tokenIdx].relativeX + tokens[tokenIdx].width / 2.0,
                tokenRelativeY: tokens[tokenIdx].relativeY, totalWidth: totalWidth,
                orderIndex: orderIndex, visibleCount: visibleIndices.count
            )
            let depthZ = TextGPUSegmentedDepthSorter.effectiveDepthZ(evaluated: evaluated, curveCenter: curvePt, baseConfig: baseConfig)
            let depthScale = TextGPUSegmentedDepthSorter.perspectiveDepthScale(offsetZEm: evaluated.overlay.offsetZEm)
            depthEntries.append(TextGPUSegmentedDepthSorter.DepthEntry(
                orderIndex: orderIndex, tokenIndex: tokenIdx, evaluated: evaluated,
                curveCenter: curvePt, depthZ: depthZ, depthScale: depthScale
            ))
        }

        for item in TextGPUSegmentedDepthSorter.sortedBackToFront(depthEntries) {
            let tokenMask = TextTokenFXRenderer.perTokenStages(evaluated: item.evaluated, baseConfig: baseConfig, plugins: renderPlugins)
            appliedMask.formUnion(tokenMask)
            if let unitLayer = renderSingleGPUToken(
                evaluated: item.evaluated, tokenMask: tokenMask, tokenWidth: tokens[item.tokenIndex].width,
                totalHeight: tokenLineHeight, curveCenter: item.curveCenter, depthScale: item.depthScale,
                blockTransform: blockTransform, font: font, localTime: localTime, duration: duration,
                canvasSize: canvasSize, orderIndex: item.orderIndex, visibleCount: visibleIndices.count,
                renderPlugins: renderPlugins, atlasCache: atlasCache
            ) {
                accImage = unitLayer.composited(over: accImage)
            }
        }
        return (accImage, appliedMask)
    }

    private static func prepareTokenAppearance(
        evaluated: inout TextAnimationEvaluator.EvaluationResult,
        token: TextSegmentRenderer.TextToken,
        startX: CGFloat,
        totalWidth: CGFloat,
        orderIndex: Int,
        visibleCount: Int,
        activeOrder: Int,
        wordLocalFrac: Double,
        isKaraokeGlow: Bool,
        baseConfig: TextConfiguration
    ) {
        if evaluated.overlay.scrambleStrength > 0.01 {
            evaluated.config.content = TextTokenFXRenderer.resolveDisplayText(
                evaluated.config.content, scrambleStrength: evaluated.overlay.scrambleStrength, unitIndex: orderIndex
            )
        }
        if isKaraokeGlow {
            TextSegmentRenderer.applyKaraokeTokenStyle(
                evaluated: &evaluated, isActive: orderIndex == activeOrder, localFrac: wordLocalFrac,
                isGlowMode: true
            )
        }
    }

    private static func evaluateToken(
        token: TextSegmentRenderer.TextToken,
        baseConfig: TextConfiguration,
        orderIndex: Int,
        visibleCount: Int,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double]
    ) -> TextAnimationEvaluator.EvaluationResult {
        var single = baseConfig
        single.content = token.text
        single.positionX = 0.0; single.positionY = 0.0
        single.scale = 1.0; single.rotation = 0.0
        single.opacity = 1.0; single.blurRadius = 0.0
        var evaluated = TextAnimationEvaluator.evaluate(
            config: single, localTime: localTime, duration: duration, canvasSize: canvasSize,
            charIndex: orderIndex, charCount: visibleCount, externalInputs: animationInputs
        )
        evaluated.config.blurRadius = evaluated.blurRadius
        return evaluated
    }

    private static func renderSingleGPUToken(
        evaluated: TextAnimationEvaluator.EvaluationResult,
        tokenMask: TextShaderFilterEngine.AppliedStagesMask,
        tokenWidth: CGFloat,
        totalHeight: CGFloat,
        curveCenter: CGPoint,
        depthScale: CGFloat,
        blockTransform: CGAffineTransform,
        font: NSFont,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        orderIndex: Int,
        visibleCount: Int,
        renderPlugins: TextAnimationRenderPluginPipeline,
        atlasCache: TextGlyphAtlasCache
    ) -> CIImage? {
        let cfg = evaluated.config, ov = evaluated.overlay
        let pivot = TextUnitPivotHelper.pivotOffset(
            for: ov.anchorPoint, width: max(1.0, tokenWidth), height: totalHeight
        )
        let unitTransform = TextGPUGlyphRenderer.makeUnitTransform(
            center: CGPoint(x: curveCenter.x + CGFloat(cfg.positionX), y: curveCenter.y - CGFloat(cfg.positionY)),
            pivotOffset: pivot, rotationDegrees: cfg.rotation,
            skewX: ov.skewX + tan(cfg.skewX * .pi / 180.0), skewY: tan(cfg.skewY * .pi / 180.0),
            scaleX: CGFloat(max(0.01, cfg.scale * ov.scaleX)) * depthScale,
            scaleY: CGFloat(max(0.01, cfg.scale * ov.scaleY)) * depthScale,
            safeguardScale: 1.0
        ).concatenating(blockTransform)

        let blockScale = max(1.0, hypot(blockTransform.a, blockTransform.b))
        let tokenScale = CGFloat(max(0.01, cfg.scale)) * depthScale * max(1.0, CGFloat(max(abs(ov.scaleX), abs(ov.scaleY))))
        let desiredScale = max(2.0, blockScale * tokenScale)
        var compositeUnit: CIImage?
        if cfg.opacity > 0.005, let entry = atlasCache.entry(
            forText: cfg.content, font: font, config: cfg,
            requestedScale: desiredScale,
            curveOverride: TextCurveStyle(shape: .none), preserveBaseline: true
        ) {
            var localPixels = composeEchoesAndMaskInPixels(entry: entry, cfg: cfg, ov: ov, tokenWidth: tokenWidth, totalHeight: totalHeight, font: font)
            if !tokenMask.isEmpty {
                let pCtx = TextAnimationRenderPluginContext(
                    localTime: localTime, duration: duration, canvasSize: canvasSize,
                    unitIndex: orderIndex, unitCount: visibleCount
                )
                let blockRotationDegrees = Double(-atan2(blockTransform.b, blockTransform.a) * 180.0 / .pi)
                localPixels = TextTokenFXRenderer.applyGPUFXInPixelSpace(
                    to: localPixels, entry: entry, evaluated: evaluated, totalHeight: totalHeight,
                    localTime: localTime, pluginContext: pCtx, plugins: renderPlugins,
                    blockScale: blockScale, totalRotationDegrees: blockRotationDegrees + cfg.rotation
                )
            }
            let combinedTransform = entry.toLogicalTransform.concatenating(unitTransform)
            compositeUnit = localPixels.transformed(by: combinedTransform)
        }

        if ov.trailingCursorOpacity > 0.01 {
            let cursorImg = TextGPUGlyphRenderer.makeTrailingCursorBar(config: cfg, font: font, tokenWidth: tokenWidth, totalHeight: totalHeight, opacity: ov.trailingCursorOpacity)
                .transformed(by: unitTransform)
            compositeUnit = compositeUnit.map { cursorImg.composited(over: $0) } ?? cursorImg
        }
        return compositeUnit
    }

    private static func composeEchoesAndMaskInPixels(
        entry: TextGlyphAtlasEntry, cfg: TextConfiguration, ov: TextTransformOverlay,
        tokenWidth: CGFloat, totalHeight: CGFloat, font: NSFont
    ) -> CIImage {
        var combined = TextSVGAndAssetCache.applyPremultipliedOpacity(cfg.opacity, to: entry.rawPixelCIImage)
        if ov.echoCount > 0, cfg.opacity > 0.01 {
            let em = CGFloat(max(16.0, cfg.fontSize))
            let pxScale = entry.rasterScale
            for idx in (1...ov.echoCount).reversed() {
                let factor = CGFloat(idx)
                let echoAlpha = max(0.0, min(1.0, cfg.opacity * (0.36 / Double(factor))))
                let echoImg = TextSVGAndAssetCache.applyPremultipliedOpacity(echoAlpha, to: entry.rawPixelCIImage)
                    .transformed(by: CGAffineTransform(
                        translationX: CGFloat(ov.echoOffsetXEm) * em * factor * pxScale,
                        y: -CGFloat(ov.echoOffsetYEm) * em * factor * pxScale
                    ))
                combined = combined.composited(over: echoImg)
            }
        }
        if ov.clipRevealX < 0.999 || ov.clipRevealY < 0.999 {
            let padX = max(8.0, font.pointSize * 0.28), padY = max(8.0, totalHeight * 0.35)
            let logicalBounds = CGRect(x: -(tokenWidth + padX * 2.0) / 2.0, y: -(totalHeight + padY * 2.0) / 2.0, width: tokenWidth + padX * 2.0, height: totalHeight + padY * 2.0)
            let pixelBounds = logicalBounds.applying(entry.toLogicalTransform.inverted())
            combined = TextGPUGlyphRenderer.applyGPUMaskInPixelSpace(
                to: combined, pixelBounds: pixelBounds, clipRevealX: ov.clipRevealX, clipRevealY: ov.clipRevealY,
                mode: ov.maskShapeMode
            )
        }
        return combined
    }

    private static func applyBlockClipMask(
        to image: CIImage, totalWidth: CGFloat, totalHeight: CGFloat,
        baseConfig: TextConfiguration, localTime: Double, duration: Double,
        canvasSize: CGSize, animationInputs: [String: Double], blockTransform: CGAffineTransform
    ) -> CIImage {
        var result = image
        if baseConfig.animation.isMaskEnabled {
            let rect = CGRect(x: -totalWidth / 2.0 - 24, y: -totalHeight / 2.0 - 12, width: totalWidth + 48, height: totalHeight + 24)
                .applying(blockTransform)
            result = result.cropped(to: rect)
        }
        let blockEval = TextAnimationEvaluator.evaluate(
            config: baseConfig, localTime: localTime, duration: duration,
            canvasSize: canvasSize, externalInputs: animationInputs
        )
        if blockEval.overlay.revealProgress >= 0.0 {
            let wipeW = (totalWidth + 48.0) * CGFloat(blockEval.overlay.revealProgress)
            let rect = CGRect(x: -totalWidth / 2.0 - 24.0, y: -totalHeight / 2.0 - 24.0, width: wipeW, height: totalHeight + 48.0)
                .applying(blockTransform)
            result = result.cropped(to: rect)
        }
        return result
    }
}
#endif
