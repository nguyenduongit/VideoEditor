import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

/// Bộ tiện ích tự canh chỉnh kích thước văn bản (Auto-Fit & Safe Scaling) theo khổ Canvas.
/// Đảm bảo tiêu đề luôn nằm trọn trong vùng an toàn, không bị tràn 2 bên mép video.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public enum TextAutoFitter: Sendable {

    /// Tính toán chiều rộng an toàn tối đa cho tiêu đề / văn bản trên canvas
    public static func maxSafeWidth(for canvasSize: CGSize) -> Double {
        guard canvasSize.width > 0 else { return 800.0 }
        let isVertical = canvasSize.height > canvasSize.width
        let ratio = isVertical ? 0.82 : 0.85
        return Double(canvasSize.width) * ratio
    }

    /// Đo bề ngang thực tế của chuỗi trên một dòng đơn (Single-line width)
    public static func measureSingleLineWidth(for config: TextConfiguration) -> Double {
        guard !config.content.isEmpty else { return 0.0 }
        #if os(macOS)
        let safeContent = config.content.precomposedStringWithCanonicalMapping
        let textString = config.isAllCaps ? safeContent.uppercased() : safeContent
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: CGFloat(config.characterSpacing)
        ]
        let attr = NSAttributedString(string: textString, attributes: attrs)
        var w = ceil(Double(attr.size().width))
        if config.hasOuterStroke && config.outerStrokeWidth > 0 {
            w += config.outerStrokeWidth * 2.0
        }
        if config.hasStroke && config.strokeWidth > 0 {
            w += abs(config.strokeWidth)
        }
        if config.hasExtrusion && config.extrusionDepth > 0 {
            w += config.extrusionDepth
        }
        if config.hasBackground {
            w += config.backgroundPadding * 2.0 + max(20.0, config.fontSize * 0.44)
        }
        return max(1.0, w)
        #else
        return Double(config.content.count) * config.fontSize * 0.65
        #endif
    }

    /// Tự động canh chỉnh font size để văn bản vừa vặn hoàn hảo trên 1 dòng trong vùng an toàn của canvas
    @discardableResult
    public static func autoScaleFontSize(
        config: inout TextConfiguration,
        canvasSize: CGSize,
        minFontSize: Double = 28.0
    ) -> Bool {
        guard !config.content.isEmpty, canvasSize.width > 0 else { return false }
        let maxAllowed = maxSafeWidth(for: canvasSize)
        let currentW = measureSingleLineWidth(for: config)

        guard currentW > maxAllowed, currentW > 0 else { return false }

        let ratio = maxAllowed / currentW
        // Co giãn tỷ lệ thuận với hệ số an toàn 0.96 để chữ nằm êm ái trong lề
        let scaled = floor(config.fontSize * ratio * 0.96)
        let targetFontSize = max(minFontSize, scaled)

        if targetFontSize != config.fontSize {
            config.fontSize = targetFontSize
            return true
        }
        return false
    }

    #if os(macOS)
    internal static func resolveFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
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
    #endif
}
