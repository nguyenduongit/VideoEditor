import AppKit
import CoreImage
import CoreText

final class EditorTitleRenderer {
    private func parseColor(_ hex: String, alpha: Double = 1.0) -> NSColor {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }

    func createTitleOverlayImage(title: String, renderSize: CGSize) -> CIImage? {
        var settings = EditorTextSettings(text: title)
        settings.applyStylePreset(.popDance)
        return createTitleOverlayImage(settings: settings, renderSize: renderSize)
    }

    func createTitleOverlayImage(settings: EditorTextSettings, renderSize: CGSize) -> CIImage? {
        var cleanTitle = settings.text.precomposedStringWithCanonicalMapping
        if settings.isAllUpper { cleanTitle = cleanTitle.uppercased() }
        guard !cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        // 1. Chiều rộng chữ căn cứ theo fontSizeScale
        let targetTextWidth = renderSize.width * 0.76 * CGFloat(settings.fontSizeScale)

        // 2. Phân giải font tiếng Việt chuẩn Unicode
        let sampleFont = VietnameseFontOption.resolveFont(
            at: settings.fontIndex,
            size: 100.0,
            bold: settings.isBold,
            italic: settings.isItalic
        )
        let lines = cleanTitle.components(separatedBy: "\n")
        var maxSampleWidth: CGFloat = 1.0
        for line in lines {
            let s = (line as NSString).size(withAttributes: [.font: sampleFont, .kern: 1.2])
            if s.width > maxSampleWidth { maxSampleWidth = s.width }
        }
        let scaleFactor = targetTextWidth / max(1.0, maxSampleWidth)
        let fontSize = max(24.0, min(120.0 * scaleFactor, renderSize.height * 0.18 * CGFloat(settings.fontSizeScale)))

        let font = VietnameseFontOption.resolveFont(
            at: settings.fontIndex,
            size: fontSize,
            bold: settings.isBold,
            italic: settings.isItalic
        )

        let paragraphStyle = NSMutableParagraphStyle()
        switch settings.alignment {
        case 0: paragraphStyle.alignment = .left
        case 2: paragraphStyle.alignment = .right
        default: paragraphStyle.alignment = .center
        }

        let kernValue: CGFloat = max(0.5, fontSize * 0.015 * CGFloat(settings.letterSpacing))
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: kernValue,
            .paragraphStyle: paragraphStyle
        ]

        // 3. Trích xuất Path vector theo từng dòng, căn lề theo settings.alignment
        var ctLines: [(line: CTLine, width: CGFloat)] = []
        var maxLineWidth: CGFloat = 0.0
        for lineStr in lines {
            let attrString = NSAttributedString(string: lineStr.isEmpty ? " " : lineStr, attributes: baseAttrs)
            let ctLine = CTLineCreateWithAttributedString(attrString)
            let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            if width > maxLineWidth { maxLineWidth = width }
            ctLines.append((line: ctLine, width: width))
        }

        let lineHeight = fontSize * 1.25
        let textPath = CGMutablePath()
        let totalLines = ctLines.count

        for (lineIdx, item) in ctLines.enumerated() {
            let ctLine = item.line
            let lineWidth = item.width
            let lineX: CGFloat
            switch settings.alignment {
            case 0: lineX = 0 // Left
            case 2: lineX = max(0, maxLineWidth - lineWidth) // Right
            default: lineX = max(0, (maxLineWidth - lineWidth) / 2.0) // Center
            }
            let lineY: CGFloat = CGFloat(totalLines - 1 - lineIdx) * lineHeight

            let runs = (CTLineGetGlyphRuns(ctLine) as? [CTRun]) ?? []
            for run in runs {
                let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
                let runFont: CTFont = (attributes?[.font] as? NSFont).map { $0 as CTFont } ?? (font as CTFont)
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
                CTRunGetPositions(run, CFRangeMake(0, count), &positions)
                for i in 0..<count {
                    if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                        let transform = CGAffineTransform(translationX: lineX + positions[i].x, y: lineY + positions[i].y)
                        textPath.addPath(glyphPath, transform: transform)
                    }
                }
            }
        }

        let pathBounds = textPath.boundingBoxOfPath
        let paddingX = max(60.0, fontSize * 0.7)
        let paddingY = max(60.0, fontSize * 0.7)
        let canvasWidth = ceil(pathBounds.width + paddingX * 2)
        let canvasHeight = ceil(pathBounds.height + paddingY * 2)

        var shiftTransform = CGAffineTransform(translationX: paddingX - pathBounds.minX, y: paddingY - pathBounds.minY)
        guard let centeredPath = textPath.copy(using: &shiftTransform) else { return nil }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(canvasWidth),
                height: Int(canvasHeight),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setMiterLimit(2.0)

        // ── LỚP 0: Hộp Nền (Background Banner) ─────────────────────────────────
        if settings.backgroundEnabled {
            context.saveGState()
            let boxPaddingX: CGFloat = max(16.0, fontSize * 0.3)
            let boxPaddingY: CGFloat = max(10.0, fontSize * 0.2)
            let boxRect = NSRect(
                x: paddingX - boxPaddingX,
                y: paddingY - boxPaddingY,
                width: pathBounds.width + boxPaddingX * 2,
                height: pathBounds.height + boxPaddingY * 2
            )
            let bgCorner = CGFloat(settings.backgroundCornerRadius)
            let bgPath = NSBezierPath(roundedRect: boxRect, xRadius: bgCorner, yRadius: bgCorner)
            let bgColor = parseColor(settings.backgroundColor, alpha: settings.backgroundAlpha)
            bgColor.setFill()
            bgPath.fill()
            context.restoreGState()
        }

        // ── XỬ LÝ THEO TỪNG STYLE PRESET ───────────────────────────────────────
        if settings.stylePreset == .popDance {
            // Mẫu Pop Dance: Neon Yellow Glow + White Stroke + Dark Crimson Contour + Pop Red Face
            let outerWhiteThickness = max(12.0, fontSize * 0.18)
            let innerDarkThickness = max(5.0, fontSize * 0.07)
            let glowBlur = max(20.0, fontSize * 0.35)

            // 1. Neon Glow
            context.saveGState()
            let glowColor = parseColor(settings.glowColor, alpha: 0.95).cgColor
            context.setShadow(offset: .zero, blur: glowBlur, color: glowColor)
            context.setStrokeColor(glowColor)
            context.setFillColor(glowColor)
            context.setLineWidth(outerWhiteThickness)
            context.addPath(centeredPath)
            context.drawPath(using: .fillStroke)
            context.addPath(centeredPath)
            context.drawPath(using: .fillStroke)
            context.restoreGState()

            // 2. Viền trắng dày bo tròn
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setFillColor(NSColor.white.cgColor)
            context.setLineWidth(outerWhiteThickness)
            context.addPath(centeredPath)
            context.drawPath(using: .fillStroke)
            context.restoreGState()

            // 3. Viền boóc-đô đậm tạo khối
            context.saveGState()
            context.setStrokeColor(NSColor(red: 0.45, green: 0.00, blue: 0.06, alpha: 1.0).cgColor)
            context.setFillColor(NSColor(red: 0.45, green: 0.00, blue: 0.06, alpha: 1.0).cgColor)
            context.setLineWidth(innerDarkThickness)
            context.addPath(centeredPath)
            context.drawPath(using: .fillStroke)
            context.restoreGState()

            // 4. Ruột chữ đỏ tươi
            context.saveGState()
            context.setFillColor(parseColor(settings.fillColor, alpha: settings.fillAlpha).cgColor)
            context.addPath(centeredPath)
            context.drawPath(using: .fill)
            context.restoreGState()
        } else {
            // Các Style Templates khác hoặc Custom Overrides

            // 1. Glow / Shadow
            if settings.glowEnabled && settings.glowRadius > 0 {
                context.saveGState()
                let glowColor = parseColor(settings.glowColor, alpha: 0.9).cgColor
                let blur = CGFloat(settings.glowRadius)
                context.setShadow(offset: .zero, blur: blur, color: glowColor)
                context.setStrokeColor(glowColor)
                context.setFillColor(glowColor)
                let strokeW = settings.strokeEnabled ? max(4.0, CGFloat(settings.strokeWidth)) : 4.0
                context.setLineWidth(strokeW)
                context.addPath(centeredPath)
                context.drawPath(using: .fillStroke)
                context.restoreGState()
            }

            // 2. Stroke / Outline
            if settings.strokeEnabled && settings.strokeWidth > 0 {
                context.saveGState()
                let strokeColor = parseColor(settings.strokeColor).cgColor
                context.setStrokeColor(strokeColor)
                context.setFillColor(strokeColor)
                context.setLineWidth(CGFloat(settings.strokeWidth))
                context.addPath(centeredPath)
                context.drawPath(using: .fillStroke)
                context.restoreGState()
            }

            // 3. Fill Face
            context.saveGState()
            let fillColor = parseColor(settings.fillColor, alpha: settings.fillAlpha).cgColor
            context.setFillColor(fillColor)
            context.addPath(centeredPath)
            context.drawPath(using: .fill)
            context.restoreGState()
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
