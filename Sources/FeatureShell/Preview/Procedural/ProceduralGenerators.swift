import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Chứa các thuật toán sinh hình ảnh cho nhóm Tiện ích (Utilities) và Lớp phủ (Overlays).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Func <= 50 dòng).
enum ProceduralGenerators {
    static func renderSolid(hex: String, canvasRect: CGRect) -> CIImage {
        let color = ProceduralRenderEngine.parseCIColor(hex: hex)
        return CIImage(color: color).cropped(to: canvasRect)
    }

    static func renderColorBars(canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let colors: [CIColor] = [
            CIColor(red: 0.75, green: 0.75, blue: 0.75), // 75% White
            CIColor(red: 0.75, green: 0.75, blue: 0.0),  // Yellow
            CIColor(red: 0.0, green: 0.75, blue: 0.75),  // Cyan
            CIColor(red: 0.0, green: 0.75, blue: 0.0),   // Green
            CIColor(red: 0.75, green: 0.0, blue: 0.75),  // Magenta
            CIColor(red: 0.75, green: 0.0, blue: 0.0),   // Red
            CIColor(red: 0.0, green: 0.0, blue: 0.75)    // Blue
        ]

        var composite = CIImage(color: CIColor.black).cropped(to: canvasRect)
        let barWidth = canvasSize.width / CGFloat(colors.count)

        for (idx, color) in colors.enumerated() {
            let x = CGFloat(idx) * barWidth
            let barRect = CGRect(x: x, y: canvasSize.height * 0.25, width: barWidth + 1, height: canvasSize.height * 0.75)
            let barImage = CIImage(color: color).cropped(to: barRect)
            composite = barImage.composited(over: composite)
        }
        return composite
    }

    static func renderFilmCountdown(localTime: Double, duration: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let totalCount = 5
        let currentSecond = Int(floor(localTime))
        let displayDigit = max(1, totalCount - (currentSecond % totalCount))
        let fraction = localTime.truncatingRemainder(dividingBy: 1.0)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(canvasSize.width),
                height: Int(canvasSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return CIImage(color: CIColor.black).cropped(to: canvasRect)
        }

        let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
        let radius = min(canvasSize.width, canvasSize.height) * 0.35

        // Nền xám đen cổ điển
        context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0))
        context.fill(canvasRect)

        // Vòng tròn đôi đồng tâm
        context.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8))
        context.setLineWidth(4.0)
        context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.strokeEllipse(in: CGRect(x: center.x - radius * 0.85, y: center.y - radius * 0.85, width: radius * 1.7, height: radius * 1.7))

        // Kim quét 360 độ
        let startAngle: CGFloat = .pi / 2
        let endAngle = startAngle - CGFloat(fraction * 2.0 * .pi)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.closePath()
        context.fillPath()

        // Đường chữ thập ngắm
        context.setStrokeColor(CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.5))
        context.setLineWidth(2.0)
        context.strokeLineSegments(between: [
            CGPoint(x: 0, y: center.y), CGPoint(x: canvasSize.width, y: center.y),
            CGPoint(x: center.x, y: 0), CGPoint(x: center.x, y: canvasSize.height)
        ])

        // Chữ số đếm ngược
        let digitStr = "\(displayDigit)" as CFString
        let fontSize = radius * 0.75
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ]
        let attrString = CFAttributedStringCreate(nil, digitStr, attributes as CFDictionary)
        if let line = attrString.flatMap({ CTLineCreateWithAttributedString($0) }) {
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            context.textPosition = CGPoint(x: center.x - bounds.width * 0.5, y: center.y - bounds.height * 0.35)
            CTLineDraw(line, context)
        }

        guard let cgImg = context.makeImage() else {
            return CIImage(color: CIColor.black).cropped(to: canvasRect)
        }
        return CIImage(cgImage: cgImg)
    }

    static func renderFilmGrain(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        guard let random = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return CIImage(color: CIColor.clear).cropped(to: canvasRect)
        }

        // Tạo offset seed ngẫu nhiên theo từng frame để hạt rung lắc chân thật
        let frameSeed = floor(localTime * 24.0 * config.speed)
        let tx = CGFloat(sin(frameSeed * 12.9898) * 1000.0).truncatingRemainder(dividingBy: 500.0)
        let ty = CGFloat(cos(frameSeed * 78.233) * 1000.0).truncatingRemainder(dividingBy: 500.0)
        let transformed = random.transformed(by: CGAffineTransform(translationX: tx, y: ty)).cropped(to: canvasRect)

        // Chuyển sang đơn sắc (monochrome grain) và điều chỉnh cường độ alpha
        let intensity = CGFloat(max(0.05, min(0.6, 0.18 * config.intensity)))
        let matrixFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: transformed,
            "inputRVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputGVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputBVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: intensity)
        ])
        return matrixFilter?.outputImage?.cropped(to: canvasRect) ?? CIImage(color: CIColor.clear).cropped(to: canvasRect)
    }

    static func renderFloatingBokeh(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var composite = CIImage(color: CIColor.clear).cropped(to: canvasRect)
        let particleCount = 12
        let primaryCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        let secondaryCI = ProceduralRenderEngine.parseCIColor(hex: config.secondaryColorHex)

        for i in 0..<particleCount {
            let seed = Double(i * 37 + config.seed)
            let baseSpeed = 0.25 * config.speed
            let progress = (localTime * baseSpeed + seed * 0.1).truncatingRemainder(dividingBy: 1.0)

            let xFrac = (sin(seed + localTime * 0.1) * 0.5 + 0.5)
            let yFrac = 1.0 - progress
            let center = CGPoint(x: CGFloat(xFrac) * canvasSize.width, y: CGFloat(yFrac) * canvasSize.height)

            let radius = CGFloat(20.0 + (sin(seed * 2.0) * 0.5 + 0.5) * 60.0 * config.scale)
            let color = i % 2 == 0 ? primaryCI : secondaryCI

            if let radial = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": CIVector(cgPoint: center),
                "inputRadius0": 0.0,
                "inputRadius1": radius,
                "inputColor0": CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.45 * CGFloat(config.intensity)),
                "inputColor1": CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0.0)
            ])?.outputImage?.cropped(to: canvasRect) {
                composite = radial.composited(over: composite)
            }
        }
        return composite
    }

    static func renderLightLeaks(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let primaryCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        let phase = localTime * 0.4 * config.speed

        let cx = canvasSize.width * CGFloat(0.3 + sin(phase) * 0.35)
        let cy = canvasSize.height * CGFloat(0.8 + cos(phase * 0.7) * 0.25)
        let radius = max(canvasSize.width, canvasSize.height) * CGFloat(0.65 * config.scale)

        let flare = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: cx, y: cy),
            "inputRadius0": 0.0,
            "inputRadius1": radius,
            "inputColor0": CIColor(red: primaryCI.red, green: primaryCI.green, blue: primaryCI.blue, alpha: 0.55 * CGFloat(config.intensity)),
            "inputColor1": CIColor(red: primaryCI.red, green: primaryCI.green * 0.4, blue: 0.0, alpha: 0.0)
        ])?.outputImage?.cropped(to: canvasRect)

        return flare ?? CIImage(color: CIColor.clear).cropped(to: canvasRect)
    }
}
