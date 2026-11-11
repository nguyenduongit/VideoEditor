import Foundation
import CoreGraphics
#if os(macOS)
import AppKit
#endif
import Domain

#if os(macOS)
/// Bộ nhớ đệm tăng tốc đồ họa vector thuần túy cho kết xuất văn bản và hoạt ảnh 60fps:
/// - Cache `NSFont` đã phân giải traits (`Bold` / `Italic`)
/// - Cache `ShapedLayout` (`CTLine` -> `CGPath` vector thuần + `bounds`)
/// - Cache mảng `[TextToken]` cho hoạt ảnh phân tách từ / ký tự
/// Bảo toàn 100% độ sắc nét vector thuần túy (Retina/4K/8K, không suy giảm độ phân giải hay răng cưa).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R8.3 (Thread-safe bằng NSLock).
public final class TextRenderPerformanceCache: @unchecked Sendable {
    public static let shared = TextRenderPerformanceCache()

    private struct FontKey: Hashable {
        let name: String
        let sizeCentipoints: Int
        let isBold: Bool
        let isItalic: Bool
    }

    private struct LayoutKey: Hashable {
        let text: String
        let fontKey: FontKey
        let spacingCentipoints: Int
        let curve: TextCurveStyle
        let isUnderlined: Bool
        let preserveBaseline: Bool
    }

    private struct TokenizeKey: Hashable {
        let content: String
        let scope: TextAnimationScope
        let fontKey: FontKey
        let spacingCentipoints: Int
    }

    private let lock = NSLock()
    private var fontCache: [FontKey: NSFont] = [:]
    private var layoutCache: [LayoutKey: TextCurvedPathBuilder.ShapedLayout] = [:]
    private var tokenizeCache: [TokenizeKey: (tokens: [TextSegmentRenderer.TextToken], totalWidth: CGFloat)] = [:]

    public init() {}

    public func clearAll() {
        lock.lock()
        fontCache.removeAll()
        layoutCache.removeAll()
        tokenizeCache.removeAll()
        lock.unlock()
    }

    // MARK: - 1. Font Cache

    public func cachedFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
        let safeSize = max(6.0, size)
        let key = FontKey(
            name: name,
            sizeCentipoints: Int((safeSize * 100.0).rounded()),
            isBold: isBold,
            isItalic: isItalic
        )
        lock.lock()
        if let existing = fontCache[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let resolved: NSFont
        if name.lowercased() == "system" {
            resolved = isBold ? NSFont.boldSystemFont(ofSize: safeSize) : NSFont.systemFont(ofSize: safeSize)
        } else {
            var font = NSFont(name: name, size: safeSize) ?? NSFont.systemFont(ofSize: safeSize)
            var traits: NSFontTraitMask = []
            if isBold { traits.insert(.boldFontMask) }
            if isItalic { traits.insert(.italicFontMask) }
            if !traits.isEmpty {
                font = NSFontManager.shared.convert(font, toHaveTrait: traits)
            }
            resolved = font
        }

        lock.lock()
        if fontCache.count >= 128 { fontCache.removeAll(keepingCapacity: true) }
        fontCache[key] = resolved
        lock.unlock()
        return resolved
    }

    // MARK: - 2. ShapedLayout (CoreText CGPath Vector + Bounds) Cache

    public func cachedShapedLayout(
        text: String,
        font: NSFont,
        config: TextConfiguration,
        curveOverride: TextCurveStyle? = nil,
        preserveBaseline: Bool = false
    ) -> TextCurvedPathBuilder.ShapedLayout {
        let effectiveCurve = curveOverride ?? config.curve
        let fKey = FontKey(
            name: config.fontName,
            sizeCentipoints: Int((max(6.0, config.fontSize) * 100.0).rounded()),
            isBold: config.isBold,
            isItalic: config.isItalic
        )
        let key = LayoutKey(
            text: text,
            fontKey: fKey,
            spacingCentipoints: Int((config.characterSpacing * 100.0).rounded()),
            curve: effectiveCurve,
            isUnderlined: config.isUnderlined,
            preserveBaseline: preserveBaseline
        )

        lock.lock()
        if let cached = layoutCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let built = TextCurvedPathBuilder.buildShapedLayout(
            text: text,
            font: font,
            characterSpacing: config.characterSpacing,
            curve: effectiveCurve,
            isUnderlined: config.isUnderlined,
            preserveBaseline: preserveBaseline
        )

        lock.lock()
        if layoutCache.count >= 512 { layoutCache.removeAll(keepingCapacity: true) }
        layoutCache[key] = built
        lock.unlock()
        return built
    }

    // MARK: - 3. Tokenization Cache

    public func cachedTokenize(
        content: String,
        scope: TextAnimationScope,
        font: NSFont,
        config: TextConfiguration
    ) -> (tokens: [TextSegmentRenderer.TextToken], totalWidth: CGFloat) {
        let fKey = FontKey(
            name: config.fontName,
            sizeCentipoints: Int((max(6.0, config.fontSize) * 100.0).rounded()),
            isBold: config.isBold,
            isItalic: config.isItalic
        )
        let key = TokenizeKey(
            content: content,
            scope: scope,
            fontKey: fKey,
            spacingCentipoints: Int((config.characterSpacing * 100.0).rounded())
        )

        lock.lock()
        if let cached = tokenizeCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = TextSegmentRenderer.computeTokens(
            content: content,
            scope: scope,
            font: font,
            spacing: config.characterSpacing
        )

        lock.lock()
        if tokenizeCache.count >= 256 { tokenizeCache.removeAll(keepingCapacity: true) }
        tokenizeCache[key] = result
        lock.unlock()
        return result
    }
}
#endif
