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
        let layout = TextCurvedPathBuilder.buildShapedLayout(
            text: config.content,
            font: font,
            characterSpacing: config.characterSpacing,
            curve: config.curve
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

    /// Đo tổng kích thước bounding box hiển thị (bao gồm cả hộp `Background` nếu đang bật) cho khung kéo thả trên Preview.
    public func measureSize(for config: TextConfiguration, canvasSize: CGSize) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        var size = measureCoreGlyphBounds(for: config)
        let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
        if size.width > maxSafeW && size.width > 0 {
            let ratio = maxSafeW / size.width
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
        canvasSize: CGSize
    ) -> CIImage {
        #if os(macOS)
        if config.background.isEnabled && config.background.blendMode != .normal {
            var textOnlyCfg = config
            textOnlyCfg.background.isEnabled = false
            let evaluated = TextAnimationEvaluator.evaluate(
                config: config, localTime: localTime, duration: duration, canvasSize: canvasSize
            )
            let rawBounds = measureCoreGlyphBounds(for: config)
            let maxSafeW = CGFloat(TextAutoFitter.maxSafeWidth(for: canvasSize))
            let safeguard: CGFloat = (rawBounds.width > maxSafeW && rawBounds.width > 0) ? (maxSafeW / rawBounds.width) : 1.0
            let anchor = config.background.animateWithText ? evaluated.config : config
            let overlay = config.background.animateWithText ? evaluated.overlay : TextTransformOverlay()

            var result = canvas
            if var bgImg = TextCompositeLayerRenderer.renderBackground(
                background: config.background, anchorConfig: anchor, overlay: overlay,
                textRawSize: rawBounds, safeguardScale: safeguard, canvasSize: canvasSize, localTime: localTime
            ) {
                if config.background.animateWithText {
                    bgImg = TextShaderFilterEngine.applyFilters(
                        to: bgImg, blurRadius: evaluated.blurRadius, hueAngle: evaluated.hueAngle,
                        pixelateScale: evaluated.pixelateScale, rgbSplitIntensity: evaluated.rgbSplitIntensity,
                        overlay: evaluated.overlay, lightSweepIntensity: 0.0
                    )
                }
                result = TextCompositeLayerRenderer.blend(
                    layerImage: bgImg, over: result, mode: config.background.blendMode
                ).cropped(to: CGRect(origin: .zero, size: canvasSize))
            }
            if let fg = renderAnimatedImage(for: textOnlyCfg, localTime: localTime, duration: duration, canvasSize: canvasSize) {
                result = fg.composited(over: result)
            }
            return result
        }
        #endif

        guard let combined = renderAnimatedImage(
            for: config, localTime: localTime, duration: duration, canvasSize: canvasSize
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
        let safeSize = max(6.0, size)
        if name.lowercased() == "system" {
            return isBold ? NSFont.boldSystemFont(ofSize: safeSize) : NSFont.systemFont(ofSize: safeSize)
        }
        var font = NSFont(name: name, size: safeSize) ?? NSFont.systemFont(ofSize: safeSize)
        var traits: NSFontTraitMask = []
        if isBold { traits.insert(.boldFontMask) }
        if isItalic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            font = NSFontManager.shared.convert(font, toHaveTrait: traits)
        }
        return font
    }

    public static func parseHexColor(_ hex: String) -> NSColor {
        TextAdvancedStyleRenderer.parseHexColor(hex)
    }

    public func parseHexColor(_ hex: String) -> NSColor {
        Self.parseHexColor(hex)
    }
    #endif
}
