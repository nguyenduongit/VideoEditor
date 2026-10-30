import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Phần mở rộng kết xuất hoạt ảnh phân tách ký tự (Per-Character Kinetic Typography) chuẩn CapCut.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TextRendererEngine {

    /// Kiểm tra hoạt ảnh có bản chất kinetic per-character (cần phân tách từng con chữ) hay không
    public static func isKineticTypographyAnimation(_ anim: TextAnimationConfiguration) -> Bool {
        switch anim.inType {
        case .slideUp, .whipRight, .kineticDrop, .typewriter:
            return true
        default: break
        }

        switch anim.outType {
        case .dropDown, .whipOut:
            return true
        default: break
        }

        switch anim.loopType {
        case .wave, .shake:
            return true
        default: break
        }

        return false
    }

    /// Xác định xem văn bản có nên được kết xuất phân tách theo ký tự / từ hay không
    public func shouldRenderSegmented(for config: TextConfiguration) -> Bool {
        guard !config.animation.isDefault else { return false }
        if config.animation.scope != .wholeBlock { return true }
        return Self.isKineticTypographyAnimation(config.animation)
    }

    #if os(macOS)
    /// Kết xuất phân cấp từng ký tự hoặc từng từ với đường cong vật lý và độ trễ sóng chuẩn CapCut
    internal func renderSegmentedAnimatedImage(
        for config: TextConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        guard width > 0, height > 0,
              let context = createBitmapContext(width: width, height: height) else { return nil }

        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer { NSGraphicsContext.restoreGraphicsState() }

        // Mặc định CapCut: Per-Character cho các hiệu ứng kinetic, trừ khi chuỗi quá dài (> 50 ký tự) thì dùng Per-Word
        let effectiveScope: TextAnimationScope
        if config.animation.scope != .wholeBlock {
            effectiveScope = config.animation.scope
        } else {
            effectiveScope = config.content.count > 50 ? .perWord : .perCharacter
        }

        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let displayContent = config.isAllCaps
            ? config.content.precomposedStringWithCanonicalMapping.uppercased()
            : config.content.precomposedStringWithCanonicalMapping
        let (tokens, totalWidth) = TextSegmentRenderer.tokenize(
            content: displayContent, scope: effectiveScope,
            font: font, spacing: config.characterSpacing
        )
        let textSize = measureSize(for: config, canvasSize: canvasSize)

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)
        context.saveGState()
        context.translateBy(x: cx, y: cy)

        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if totalWidth > maxSafeW && totalWidth > 0 {
            let safeguardScale = maxSafeW / totalWidth
            context.scaleBy(x: safeguardScale, y: safeguardScale)
        }

        TextSegmentRenderer.drawSegmentedText(
            tokens: tokens, totalWidth: totalWidth, totalHeight: textSize.height,
            baseConfig: config, localTime: localTime, duration: duration,
            canvasSize: canvasSize, in: context,
            makeAttributedString: { [weak self] in self?.makeAttributedString(for: $0) ?? NSAttributedString() }
        )
        context.restoreGState()

        guard let cgImage = context.makeImage() else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let globalEval = TextAnimationEvaluator.evaluate(
            config: config, localTime: localTime, duration: duration, canvasSize: canvasSize
        )
        return TextShaderFilterEngine.applyFilters(
            to: ciImage,
            blurRadius: globalEval.blurRadius,
            hueAngle: globalEval.hueAngle,
            pixelateScale: globalEval.pixelateScale,
            rgbSplitIntensity: globalEval.rgbSplitIntensity,
            overlay: globalEval.overlay,
            lightSweepIntensity: config.animation.lightSweepIntensity
        )
    }
    #endif
}
