import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Chứa các thuật toán sinh hình ảnh cho nhóm Nền chuyển động (Backgrounds) và Thị giác (Visuals).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Func <= 50 dòng).
extension ProceduralGenerators {
    static func renderMeshAurora(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let primaryCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        let secondaryCI = ProceduralRenderEngine.parseCIColor(hex: config.secondaryColorHex)
        let t = localTime * 0.5 * config.speed

        let p0 = CGPoint(
            x: canvasSize.width * CGFloat(0.2 + 0.25 * sin(t)),
            y: canvasSize.height * CGFloat(0.1 + 0.2 * cos(t * 0.8))
        )
        let p1 = CGPoint(
            x: canvasSize.width * CGFloat(0.8 + 0.15 * cos(t * 1.2)),
            y: canvasSize.height * CGFloat(0.9 + 0.1 * sin(t * 0.9))
        )

        let baseGradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(cgPoint: p0),
            "inputPoint1": CIVector(cgPoint: p1),
            "inputColor0": primaryCI,
            "inputColor1": secondaryCI
        ])?.outputImage?.cropped(to: canvasRect)

        let orbCenter = CGPoint(
            x: canvasSize.width * CGFloat(0.5 + 0.3 * sin(t * 1.4)),
            y: canvasSize.height * CGFloat(0.5 + 0.25 * cos(t * 1.1))
        )
        let accentCI = ProceduralRenderEngine.parseCIColor(hex: config.accentColorHex, alpha: 0.6)
        let orb = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(cgPoint: orbCenter),
            "inputRadius0": 0.0,
            "inputRadius1": max(canvasSize.width, canvasSize.height) * 0.5,
            "inputColor0": accentCI,
            "inputColor1": CIColor(red: accentCI.red, green: accentCI.green, blue: accentCI.blue, alpha: 0.0)
        ])?.outputImage?.cropped(to: canvasRect)

        if let base = baseGradient, let orbImg = orb {
            return orbImg.composited(over: base)
        }
        return baseGradient ?? CIImage(color: primaryCI).cropped(to: canvasRect)
    }

    static func renderTopographic(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
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

        // Nền tối
        let bgCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        context.setFillColor(CGColor(red: bgCI.red, green: bgCI.green, blue: bgCI.blue, alpha: 1.0))
        context.fill(canvasRect)

        // Các đường đồng mức uốn lượn
        let lineCI = ProceduralRenderEngine.parseCIColor(hex: config.secondaryColorHex)
        context.setStrokeColor(CGColor(red: lineCI.red, green: lineCI.green, blue: lineCI.blue, alpha: 0.55 * CGFloat(config.intensity)))
        context.setLineWidth(2.0 * CGFloat(config.scale))

        let lineCount = 14
        let stepY = canvasSize.height / CGFloat(lineCount)
        let t = localTime * 0.8 * config.speed

        for i in 0..<lineCount {
            let baseY = CGFloat(i) * stepY
            let path = CGMutablePath()
            var first = true

            let segments = 20
            let stepX = canvasSize.width / CGFloat(segments)
            for j in 0...segments {
                let x = CGFloat(j) * stepX
                let wave1 = sin(Double(j) * 0.35 + t + Double(i) * 0.4) * 35.0
                let wave2 = cos(Double(j) * 0.2 - t * 0.7 + Double(i) * 0.2) * 20.0
                let y = baseY + CGFloat(wave1 + wave2)

                if first { path.move(to: CGPoint(x: x, y: y)); first = false }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.addPath(path)
            context.strokePath()
        }

        guard let cgImg = context.makeImage() else {
            return CIImage(color: bgCI).cropped(to: canvasRect)
        }
        return CIImage(cgImage: cgImg)
    }

    static func renderRetroGrid(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
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

        let bgCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        context.setFillColor(CGColor(red: bgCI.red, green: bgCI.green, blue: bgCI.blue, alpha: 1.0))
        context.fill(canvasRect)

        let gridCI = ProceduralRenderEngine.parseCIColor(hex: config.secondaryColorHex)
        context.setStrokeColor(CGColor(red: gridCI.red, green: gridCI.green, blue: gridCI.blue, alpha: 0.85 * CGFloat(config.intensity)))
        context.setLineWidth(2.0)

        let horizonY = canvasSize.height * 0.48
        let vanishPt = CGPoint(x: canvasSize.width * 0.5, y: horizonY)

        // Đường phối cảnh dọc hội tụ về tâm chân trời
        let vLineCount = 16
        for i in 0...vLineCount {
            let xRatio = CGFloat(i) / CGFloat(vLineCount)
            let bottomX = canvasSize.width * (xRatio * 2.2 - 0.6)
            context.strokeLineSegments(between: [vanishPt, CGPoint(x: bottomX, y: 0)])
        }

        // Đường ngang chuyển động tiến về phía người xem
        let hLineCount = 10
        let offset = CGFloat((localTime * 0.8 * config.speed).truncatingRemainder(dividingBy: 1.0))
        for i in 0..<hLineCount {
            let p = (CGFloat(i) + offset) / CGFloat(hLineCount)
            let depth = pow(p, 2.6) // Phối cảnh phi tuyến
            let y = horizonY - (depth * horizonY)
            context.strokeLineSegments(between: [CGPoint(x: 0, y: y), CGPoint(x: canvasSize.width, y: y)])
        }

        // Đường chân trời neon sáng
        context.setStrokeColor(CGColor(red: 1.0, green: 0.3, blue: 0.8, alpha: 0.9))
        context.setLineWidth(3.0)
        context.strokeLineSegments(between: [CGPoint(x: 0, y: horizonY), CGPoint(x: canvasSize.width, y: horizonY)])

        guard let cgImg = context.makeImage() else {
            return CIImage(color: bgCI).cropped(to: canvasRect)
        }
        return CIImage(cgImage: cgImg)
    }

    static func renderHypnoticTunnel(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
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

        context.setFillColor(CGColor(red: 0.04, green: 0.02, blue: 0.08, alpha: 1.0))
        context.fill(canvasRect)

        let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
        let maxR = max(canvasSize.width, canvasSize.height) * 0.75
        let ringCount = 15
        let offset = (localTime * 0.6 * config.speed).truncatingRemainder(dividingBy: 1.0)
        let pCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)
        let sCI = ProceduralRenderEngine.parseCIColor(hex: config.secondaryColorHex)

        for i in (0..<ringCount).reversed() {
            let frac = (Double(i) + offset) / Double(ringCount)
            let r = CGFloat(pow(frac, 1.8)) * maxR
            let color = i % 2 == 0 ? pCI : sCI
            let alpha = CGFloat(min(1.0, frac * 1.5)) * CGFloat(config.intensity)

            context.setStrokeColor(CGColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha))
            context.setLineWidth(CGFloat(2.0 + frac * 8.0 * config.scale))
            context.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        }

        guard let cgImg = context.makeImage() else {
            return CIImage(color: CIColor.black).cropped(to: canvasRect)
        }
        return CIImage(cgImage: cgImg)
    }

    static func renderMatrixRain(config: ProceduralConfiguration, localTime: Double, canvasSize: CGSize) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
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

        context.setFillColor(CGColor(red: 0.0, green: 0.05, blue: 0.02, alpha: 1.0))
        context.fill(canvasRect)

        let columnCount = 28
        let colWidth = canvasSize.width / CGFloat(columnCount)
        let mainCI = ProceduralRenderEngine.parseCIColor(hex: config.primaryColorHex)

        for col in 0..<columnCount {
            let seed = Double(col * 43 + config.seed)
            let colSpeed = (0.7 + sin(seed) * 0.3) * config.speed
            let progress = (localTime * colSpeed + seed * 0.1).truncatingRemainder(dividingBy: 1.0)

            let headY = canvasSize.height * (1.0 - CGFloat(progress))
            let tailLength: CGFloat = 200.0 * CGFloat(config.scale)
            let x = CGFloat(col) * colWidth + colWidth * 0.5

            // Vẽ đuôi vệt sáng mờ dần
            context.saveGState()
            let tailGradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [
                    CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), // Đầu sáng trắng
                    CGColor(red: mainCI.red, green: mainCI.green, blue: mainCI.blue, alpha: 0.8),
                    CGColor(red: mainCI.red, green: mainCI.green * 0.4, blue: 0.0, alpha: 0.0)
                ] as CFArray,
                locations: [0.0, 0.25, 1.0]
            )
            if let grad = tailGradient {
                context.drawLinearGradient(
                    grad,
                    start: CGPoint(x: x, y: headY),
                    end: CGPoint(x: x, y: headY + tailLength),
                    options: []
                )
            }
            context.restoreGState()

            // Đầu phát sáng (head point)
            context.setFillColor(CGColor(red: 0.8, green: 1.0, blue: 0.8, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: x - 3, y: headY - 3, width: 6, height: 6))
        }

        guard let cgImg = context.makeImage() else {
            return CIImage(color: CIColor.black).cropped(to: canvasRect)
        }
        return CIImage(cgImage: cgImg)
    }
}
