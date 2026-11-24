import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Phần mở rộng cho `TextRendererEngine`: Đo kích thước (Measurement), sinh AttributedString, phân giải Font chữ
/// và hòa trộn `Background` (Blend Mode) + `Text` trực tiếp lên khung hình Video bên dưới.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
extension TextRendererEngine {

    /// Đo kích thước lõi của chữ (chưa tính hộp nền) phục vụ căn chỉnh hộp `Background` ôm chữ chuẩn xác.
    public func measureCoreGlyphBounds(for config: TextConfiguration) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        #if os(macOS)
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let layout = TextRenderPerformanceCache.shared.cachedShapedLayout(
            text: config.content,
            font: font,
            config: config
        )
        var w = ceil(max(layout.bounds.width, layout.lineAdvanceWidth))
        var h = ceil(max(16.0, layout.bounds.height))
        let innerW = config.innerStroke.isEnabled ? config.innerStroke.width : 0.0
        let outerW = config.outerStroke.isEnabled ? config.outerStroke.width : 0.0
        let strokePad = CGFloat((innerW + outerW) * 2.0)
        w += strokePad
        h += strokePad
        return CGSize(width: max(16.0, w), height: max(16.0, h))
        #else
        return CGSize(width: 200, height: 60)
        #endif
    }

    /// Đo vùng bao giới hạn cực đại (Envelope Bounds) mà Text + Style (Glow/Shadow) + Biên độ Animation có thể chạm tới.
    public func measureBackgroundEnvelopeBounds(for config: TextConfiguration) -> CGSize {
        let core = measureCoreGlyphBounds(for: config)
        guard core.width > 0, core.height > 0 else { return .zero }

        let glowExpand = config.glow.isActive ? CGFloat(config.glow.range * 0.85) : 0.0
        let shadowExpandX = config.shadow.isActive ? CGFloat(abs(config.shadow.offsetX) + config.shadow.blur * 0.5) : 0.0
        let shadowExpandY = config.shadow.isActive ? CGFloat(abs(config.shadow.offsetY) + config.shadow.blur * 0.5) : 0.0
        let animEnv = measureAnimationEnvelopeDelta(for: config, em: max(16.0, config.fontSize))

        let envW = core.width * CGFloat(animEnv.sx) + CGFloat(animEnv.dx * 2.0) + (glowExpand + shadowExpandX) * 2.0
        let envH = core.height * CGFloat(animEnv.sy) + CGFloat(animEnv.dy * 2.0) + (glowExpand + shadowExpandY) * 2.0
        return CGSize(width: ceil(max(16.0, envW)), height: ceil(max(16.0, envH)))
    }

    private func measureAnimationEnvelopeDelta(
        for config: TextConfiguration,
        em: Double
    ) -> (dx: Double, dy: Double, sx: Double, sy: Double) {
        if let graph = config.animation.graph {
            return measureGraphEnvelopeDelta(for: config, graph: graph, em: em)
        }
        guard config.animation.hasScriptAnimation,
              let script = TextAnimationScriptRegistry.shared.script(for: config.animation.scriptId) else {
            return (0.0, 0.0, 1.0, 1.0)
        }
        return measureScriptEnvelopeDelta(for: config, script: script, em: em)
    }

    private func measureGraphEnvelopeDelta(
        for config: TextConfiguration,
        graph: TextAnimationGraph,
        em: Double
    ) -> (dx: Double, dy: Double, sx: Double, sy: Double) {
        let effectiveScope = config.animation.scopeOverride ?? graph.scope
        let rawUnits = effectiveScope == .wholeBlock ? 1 : max(1, min(12, config.content.count))
        let indices = Array(Set([0, rawUnits / 2, max(0, rawUnits - 1)]))
        let boundForBg = config.background.isActive && !config.background.animateWithText
        let seed = graph.id.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        let overrideDir = config.animation.staggerDirection == .forward ? nil : config.animation.staggerDirection
        let samples = [0.0, 0.2, 0.4, 0.6, 0.8, 0.95]

        var maxDx = 0.0, maxDy = 0.0, maxSX = 1.0, maxSY = 1.0
        let totalDur = max(0.2, config.animation.scriptDuration)
        for phase in [TextAnimationGraphPhase.intro, .loop, .outro] {
            for p in samples {
                let gProg = (phase == .intro ? p * 0.2 : (phase == .loop ? 0.2 + p * 0.6 : 0.8 + p * 0.2))
                for uIdx in indices {
                    let ctx = TextAnimationGraphContext(
                        phase: phase, globalProgress: gProg, phaseProgress: p, loopProgress: p,
                        elapsedSeconds: totalDur * gProg, phaseDuration: max(0.2, totalDur / 3.0),
                        unitIndex: uIdx, unitCount: rawUnits, randomSeed: seed, staggerDirectionOverride: overrideDir
                    )
                    let d = TextAnimationGraphMapper.unitDelta(from: graph.evaluate(in: ctx))
                    guard d.opacity > 0.10 else { continue }
                    let (effDx, effDy) = boundForBg
                        ? TextAnimationEvaluator.boundOffsetForFixedBackground(dx: d.offsetX, dy: d.offsetY, em: em)
                        : (d.offsetX, d.offsetY)
                    let rot = rotationEnvelopeExpansion(degrees: d.rotation, scaleX: d.scaleX, scaleY: d.scaleY, em: em)
                    let trackDx = abs(d.trackingEmDelta) * em * Double(rawUnits) * 0.5
                    let cursorDx = d.trailingCursorOpacity > 0.01 ? em * 0.18 : 0.0
                    maxDx = max(maxDx, abs(effDx) + trackDx + rot.x + cursorDx)
                    maxDy = max(maxDy, abs(effDy) + rot.y)
                    maxSX = max(maxSX, abs(d.scaleX))
                    maxSY = max(maxSY, abs(d.scaleY))
                }
            }
        }
        return (min(em * 1.25, maxDx), min(em * 1.0, maxDy), min(1.35, max(1.0, maxSX)), min(1.35, max(1.0, maxSY)))
    }

    private func measureScriptEnvelopeDelta(
        for config: TextConfiguration,
        script: any TextAnimationScript,
        em: Double
    ) -> (dx: Double, dy: Double, sx: Double, sy: Double) {
        let unitTotal = max(1, min(12, config.content.count))
        let sampleIndices = Array(Set([0, unitTotal / 2, max(0, unitTotal - 1)]))
        let boundForBg = config.background.isActive && !config.background.animateWithText
        var phases: [TextScriptPhase] = (0..<8).map { let c = Double($0) / 8.0; return .loop(time: c, cycleProgress: c) }
        phases += [0.20, 0.40, 0.60, 0.75, 0.90].map { .intro(progress: $0) }
        phases += [0.10, 0.25, 0.40, 0.60, 0.80].map { .outro(progress: $0) }

        var maxDx = 0.0, maxDy = 0.0, maxSX = 1.0, maxSY = 1.0
        for phase in phases {
            for uIdx in sampleIndices {
                let d = script.evaluatePhase(base: config, phase: phase, unitIndex: uIdx, unitTotal: unitTotal)
                guard d.opacity > 0.10 else { continue }
                let (effDx, effDy) = boundForBg
                    ? TextAnimationEvaluator.boundOffsetForFixedBackground(dx: d.offsetX, dy: d.offsetY, em: em)
                    : (d.offsetX, d.offsetY)
                let rot = rotationEnvelopeExpansion(degrees: d.rotation, scaleX: d.scaleX, scaleY: d.scaleY, em: em)
                let trackDx = abs(d.trackingEmDelta) * em * Double(unitTotal) * 0.5
                let cursorDx = d.trailingCursorOpacity > 0.01 ? em * 0.18 : 0.0
                let dx = abs(effDx) + trackDx + rot.x + cursorDx
                let dy = abs(effDy) + rot.y
                maxDx = max(maxDx, dx); maxDy = max(maxDy, dy)
                maxSX = max(maxSX, d.scaleX); maxSY = max(maxSY, d.scaleY)
            }
        }
        return (min(em * 1.25, maxDx), min(em * 1.0, maxDy), min(1.35, max(1.0, maxSX)), min(1.35, max(1.0, maxSY)))
    }

    private func rotationEnvelopeExpansion(
        degrees: Double, scaleX: Double, scaleY: Double, em: Double
    ) -> (x: Double, y: Double) {
        let rad = abs(degrees) * .pi / 180.0
        return (em * 0.45 * max(1.0, scaleY) * sin(rad), em * 0.35 * max(1.0, scaleX) * sin(rad))
    }

    /// Đo tổng kích thước bounding box hiển thị (bao gồm cả hộp `Background` nếu đang bật) cho khung kéo thả trên Preview.
    public func measureSize(for config: TextConfiguration, canvasSize: CGSize) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        let coreBounds = measureCoreGlyphBounds(for: config)
        var size = config.background.isEnabled ? measureBackgroundEnvelopeBounds(for: config) : coreBounds
        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if coreBounds.width > maxSafeW && coreBounds.width > 0 {
            let ratio = maxSafeW / coreBounds.width
            size.width *= ratio
            size.height *= ratio
        }
        if config.background.isEnabled {
            if config.background.fitToTextBounds {
                size.width += CGFloat(config.background.paddingX * 2.0)
                size.height += CGFloat(config.background.paddingY * 2.0)
            } else {
                size.width = max(size.width, CGFloat(config.background.customWidth))
                size.height = max(size.height, CGFloat(config.background.customHeight))
            }
        }
        return CGSize(width: max(20.0, size.width), height: max(20.0, size.height))
    }

    /// Kết xuất và hòa trộn cả `Background` (hỗ trợ Blend Mode thật với nền video bên dưới) lẫn `Text` lên `canvas`.
    public func composite(
        config: TextConfiguration,
        over canvas: CIImage,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        animationInputs: [String: Double] = [:]
    ) -> CIImage {
        #if os(macOS)
        if config.background.isEnabled && config.background.blendMode != .normal {
            var textOnlyCfg = config
            textOnlyCfg.background.isEnabled = false
            let coreBounds = measureCoreGlyphBounds(for: config)
            let envelopeBounds = measureBackgroundEnvelopeBounds(for: config)
            let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
            let safeguard: CGFloat = (coreBounds.width > maxSafeW && coreBounds.width > 0) ? (maxSafeW / coreBounds.width) : 1.0

            let followText = config.background.animateWithText
            let evaluated = followText
                ? TextAnimationEvaluator.evaluate(
                    config: config, localTime: localTime, duration: duration,
                    canvasSize: canvasSize, externalInputs: animationInputs
                )
                : TextAnimationEvaluator.EvaluationResult(config: config)
            var result = canvas
            if let bgImg = TextCompositeLayerRenderer.renderBackground(
                background: config.background,
                anchorConfig: followText ? evaluated.config : config,
                overlay: followText ? evaluated.overlay : TextTransformOverlay(),
                textRawSize: followText ? coreBounds : envelopeBounds,
                safeguardScale: safeguard,
                canvasSize: canvasSize,
                localTime: localTime
            ) {
                result = TextCompositeLayerRenderer.blend(
                    layerImage: bgImg, over: result, mode: config.background.blendMode
                ).cropped(to: CGRect(origin: .zero, size: canvasSize))
            }
            if let fg = renderAnimatedImage(
                for: textOnlyCfg, localTime: localTime, duration: duration,
                canvasSize: canvasSize, animationInputs: animationInputs
            ) {
                result = fg.composited(over: result)
            }
            return result
        }
        #endif

        guard let combined = renderAnimatedImage(
            for: config, localTime: localTime, duration: duration,
            canvasSize: canvasSize, animationInputs: animationInputs
        ) else {
            return canvas
        }
        return combined.composited(over: canvas)
    }

    #if os(macOS)
    public func makeAttributedString(for config: TextConfiguration) -> NSAttributedString {
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let paragraph = TextAdvancedStyleRenderer.makeParagraphStyle(for: config)
        let isGradient = config.colorFillMode == .linearGradient && config.gradientColors.count >= 2
        let fgColor = (isGradient || config.textColorHex.uppercased() == "NONE")
            ? NSColor.clear
            : parseHexColor(config.textColorHex)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fgColor,
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]
        if config.innerStroke.isEnabled && config.innerStroke.width > 0 {
            attrs[.strokeColor] = parseHexColor(config.innerStroke.colorHex)
            attrs[.strokeWidth] = -abs(config.innerStroke.width)
        }
        let safeContent = config.content.precomposedStringWithCanonicalMapping
        return NSAttributedString(string: safeContent, attributes: attrs)
    }

    internal func resolveFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
        TextRenderPerformanceCache.shared.cachedFont(name: name, size: size, isBold: isBold, isItalic: isItalic)
    }

    public static func parseHexColor(_ hex: String) -> NSColor {
        TextAdvancedStyleRenderer.parseHexColor(hex)
    }

    public func parseHexColor(_ hex: String) -> NSColor {
        Self.parseHexColor(hex)
    }
    #endif
}
