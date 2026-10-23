import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất văn bản (Typography) với định dạng font chữ, viền, bóng, nền và transform.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
public final class TextRendererEngine: @unchecked Sendable {
    public static let shared = TextRendererEngine()

    private init() {}

    /// Đo kích thước bounding box của văn bản dựa trên cấu hình và kích thước canvas.
    public func measureSize(for config: TextConfiguration, canvasSize: CGSize) -> CGSize {
        guard !config.content.isEmpty else { return .zero }
        #if os(macOS)
        let attributed = makeAttributedString(for: config)
        let maxTextSize = CGSize(width: max(100.0, canvasSize.width), height: max(100.0, canvasSize.height))
        let bounds = attributed.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        var w = ceil(bounds.width)
        var h = ceil(bounds.height)
        if config.hasBackground {
            let pad = CGFloat(config.backgroundPadding)
            w += pad * 2.0
            h += pad * 2.0
        }
        return CGSize(width: max(20.0, w), height: max(20.0, h))
        #else
        return CGSize(width: 200, height: 60)
        #endif
    }

    /// Kết xuất văn bản thành CIImage để hòa trộn trong Video Compositor.
    public func renderImage(for config: TextConfiguration, canvasSize: CGSize) -> CIImage? {
        guard !config.content.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else {
            return nil
        }
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        #if os(macOS)
        let nsGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphicsContext
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        drawText(config: config, canvasSize: canvasSize, in: context)
        #endif

        guard let cgImage = context.makeImage() else { return nil }
        var ciImage = CIImage(cgImage: cgImage)

        if config.opacity < 1.0 {
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(max(0.0, config.opacity)))
            if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: ciImage]) {
                ciImage = matrix.outputImage ?? ciImage
            }
        }

        return ciImage
    }

    #if os(macOS)
    private func drawText(config: TextConfiguration, canvasSize: CGSize, in context: CGContext) {
        let attributed = makeAttributedString(for: config)
        let maxTextSize = CGSize(width: max(100.0, canvasSize.width), height: max(100.0, canvasSize.height))
        let bounds = attributed.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let textWidth = ceil(bounds.width)
        let textHeight = ceil(bounds.height)

        let cx = canvasSize.width / 2.0 + CGFloat(config.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(config.positionY)

        context.saveGState()
        context.translateBy(x: cx, y: cy)

        if abs(config.rotation) > 0.001 {
            context.rotate(by: CGFloat(-config.rotation * .pi / 180.0))
        }
        if abs(config.scale - 1.0) > 0.001 {
            let s = CGFloat(max(0.01, config.scale))
            context.scaleBy(x: s, y: s)
        }

        if config.hasBackground {
            let pad = CGFloat(config.backgroundPadding)
            let bgRect = CGRect(x: -textWidth / 2.0 - pad, y: -textHeight / 2.0 - pad, width: textWidth + pad * 2.0, height: textHeight + pad * 2.0)
            let corner = CGFloat(config.backgroundCornerRadius)
            let path = NSBezierPath(roundedRect: bgRect, xRadius: corner, yRadius: corner)
            parseHexColor(config.backgroundColorHex).setFill()
            path.fill()
        }

        let textRect = CGRect(x: -textWidth / 2.0, y: -textHeight / 2.0, width: textWidth, height: textHeight)
        attributed.draw(in: textRect)

        context.restoreGState()
    }

    private func makeAttributedString(for config: TextConfiguration) -> NSAttributedString {
        let font = resolveFont(name: config.fontName, size: CGFloat(config.fontSize), isBold: config.isBold, isItalic: config.isItalic)
        let paragraph = NSMutableParagraphStyle()
        switch config.alignment {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        paragraph.lineSpacing = CGFloat(config.lineSpacing)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: parseHexColor(config.textColorHex),
            .paragraphStyle: paragraph,
            .kern: CGFloat(config.characterSpacing)
        ]

        if config.hasStroke && config.strokeWidth > 0 {
            attrs[.strokeColor] = parseHexColor(config.strokeColorHex)
            attrs[.strokeWidth] = -abs(config.strokeWidth)
        }

        if config.hasShadow && (config.shadowRadius > 0 || config.shadowOffsetX != 0 || config.shadowOffsetY != 0) {
            let shadow = NSShadow()
            shadow.shadowColor = parseHexColor(config.shadowColorHex)
            shadow.shadowBlurRadius = CGFloat(config.shadowRadius)
            shadow.shadowOffset = NSSize(width: config.shadowOffsetX, height: -config.shadowOffsetY)
            attrs[.shadow] = shadow
        }

        return NSAttributedString(string: config.content, attributes: attrs)
    }

    private func resolveFont(name: String, size: CGFloat, isBold: Bool, isItalic: Bool) -> NSFont {
        let safeSize = max(6.0, size)
        if name.lowercased() == "system" {
            if isBold {
                return isItalic ? NSFont.boldSystemFont(ofSize: safeSize) : NSFont.boldSystemFont(ofSize: safeSize)
            }
            return NSFont.systemFont(ofSize: safeSize)
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

    public func parseHexColor(_ hex: String) -> NSColor {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 6 {
            clean.append("FF")
        }
        guard clean.count == 8, let num = UInt64(clean, radix: 16) else {
            return .white
        }
        let r = CGFloat((num & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((num & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((num & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(num & 0x000000FF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    #endif
}
