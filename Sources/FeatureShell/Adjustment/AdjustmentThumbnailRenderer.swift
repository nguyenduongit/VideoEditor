import AppKit
@preconcurrency import CoreImage
import Domain

/// Bộ dựng và lưu đệm ảnh Thumbnail minh họa trực quan cho từng `AdjustmentPreset`.
/// Vẽ một khung cảnh điện ảnh chuẩn (Bầu trời Cyan/Blue, Mặt trời Hoàng hôn Cam/Đỏ, Núi tím, Rừng thông xanh lá, Mặt hồ phản chiếu)
/// và chạy trực tiếp qua `ColorGradingEngine` để hiển thị chính xác chất màu thực tế của từng JSON Template.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@MainActor
public final class AdjustmentThumbnailRenderer {
    public static let shared = AdjustmentThumbnailRenderer()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var cache: [String: NSImage] = [:]
    private var baseSceneImage: CIImage?

    private init() {}

    public func thumbnail(for preset: AdjustmentPreset) -> NSImage? {
        if let cached = cache[preset.id] {
            return cached
        }
        let base = getOrCreateBaseScene()
        let graded = ColorGradingEngine.shared.applyGrading(
            to: base,
            config: preset.config,
            intensity: 1.0
        ).cropped(to: base.extent)

        guard let cgImage = ciContext.createCGImage(graded, from: base.extent) else {
            return nil
        }
        let nsImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: base.extent.width, height: base.extent.height)
        )
        cache[preset.id] = nsImage
        return nsImage
    }

    public func invalidateCache() {
        cache.removeAll()
    }

    private func getOrCreateBaseScene() -> CIImage {
        if let existing = baseSceneImage {
            return existing
        }
        let size = 180
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CIImage(color: .gray).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        }

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        drawSkyAndSun(in: ctx, rect: rect, colorSpace: colorSpace)
        drawMountainsAndFoliage(in: ctx, rect: rect)
        drawWaterReflection(in: ctx, rect: rect, colorSpace: colorSpace)

        guard let cgImage = ctx.makeImage() else {
            return CIImage(color: .gray).cropped(to: rect)
        }
        let ciImage = CIImage(cgImage: cgImage)
        baseSceneImage = ciImage
        return ciImage
    }

    private func drawSkyAndSun(in ctx: CGContext, rect: CGRect, colorSpace: CGColorSpace) {
        let skyColors = [
            CGColor(red: 0.10, green: 0.32, blue: 0.58, alpha: 1.0),
            CGColor(red: 0.22, green: 0.58, blue: 0.68, alpha: 1.0),
            CGColor(red: 0.94, green: 0.62, blue: 0.38, alpha: 1.0)
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.52, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: skyColors, locations: locations) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.maxY),
                end: CGPoint(x: rect.midX, y: rect.height * 0.34),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        // Vầng mặt trời ấm (kiểm thử vùng Highlight, Red, Orange, Yellow & Skin tone)
        let sunCenter = CGPoint(x: rect.width * 0.66, y: rect.height * 0.62)
        let glowColors = [
            CGColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 0.95),
            CGColor(red: 0.98, green: 0.52, blue: 0.36, alpha: 0.55),
            CGColor(red: 0.92, green: 0.36, blue: 0.48, alpha: 0.0)
        ] as CFArray
        if let sunGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.42, 1.0]) {
            ctx.drawRadialGradient(
                sunGrad,
                startCenter: sunCenter,
                startRadius: 2,
                endCenter: sunCenter,
                endRadius: rect.width * 0.34,
                options: []
            )
        }
    }

    private func drawMountainsAndFoliage(in ctx: CGContext, rect: CGRect) {
        let w = rect.width
        let h = rect.height

        // Dãy núi xa sắc tím lam (kiểm thử vùng Midtones, Purple & Magenta)
        ctx.saveGState()
        let farMountain = CGMutablePath()
        farMountain.move(to: CGPoint(x: 0, y: h * 0.36))
        farMountain.addLine(to: CGPoint(x: w * 0.28, y: h * 0.60))
        farMountain.addLine(to: CGPoint(x: w * 0.55, y: h * 0.44))
        farMountain.addLine(to: CGPoint(x: w * 0.82, y: h * 0.56))
        farMountain.addLine(to: CGPoint(x: w, y: h * 0.42))
        farMountain.addLine(to: CGPoint(x: w, y: h * 0.34))
        farMountain.addLine(to: CGPoint(x: 0, y: h * 0.34))
        farMountain.closeSubpath()
        ctx.addPath(farMountain)
        ctx.setFillColor(CGColor(red: 0.36, green: 0.30, blue: 0.48, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()

        // Đồi rừng thông tiền cảnh sắc xanh lá (kiểm thử kênh Green, Cyan & Shadow)
        ctx.saveGState()
        let nearHills = CGMutablePath()
        nearHills.move(to: CGPoint(x: 0, y: h * 0.34))
        nearHills.addLine(to: CGPoint(x: 0, y: h * 0.48))
        nearHills.addLine(to: CGPoint(x: w * 0.42, y: h * 0.38))
        nearHills.addLine(to: CGPoint(x: w * 0.74, y: h * 0.47))
        nearHills.addLine(to: CGPoint(x: w, y: h * 0.37))
        nearHills.addLine(to: CGPoint(x: w, y: h * 0.34))
        nearHills.closeSubpath()
        ctx.addPath(nearHills)
        ctx.setFillColor(CGColor(red: 0.16, green: 0.42, blue: 0.30, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()
    }

    private func drawWaterReflection(in ctx: CGContext, rect: CGRect, colorSpace: CGColorSpace) {
        let w = rect.width
        let h = rect.height
        let waterRect = CGRect(x: 0, y: 0, width: w, height: h * 0.34)

        ctx.saveGState()
        ctx.clip(to: waterRect)
        let waterColors = [
            CGColor(red: 0.82, green: 0.48, blue: 0.34, alpha: 1.0),
            CGColor(red: 0.14, green: 0.34, blue: 0.48, alpha: 1.0),
            CGColor(red: 0.06, green: 0.10, blue: 0.16, alpha: 1.0)
        ] as CFArray
        if let waterGrad = CGGradient(colorsSpace: colorSpace, colors: waterColors, locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(
                waterGrad,
                start: CGPoint(x: w * 0.5, y: waterRect.maxY),
                end: CGPoint(x: w * 0.5, y: 0),
                options: []
            )
        }

        // Gợn sóng phản chiếu ánh nắng trên mặt hồ
        ctx.setFillColor(CGColor(red: 0.98, green: 0.78, blue: 0.55, alpha: 0.45))
        for i in 0..<5 {
            let y = waterRect.maxY - CGFloat(i + 1) * (waterRect.height * 0.16)
            let rippleW = w * (0.28 - CGFloat(i) * 0.04)
            let rippleRect = CGRect(x: w * 0.66 - rippleW * 0.5, y: y, width: rippleW, height: 2.2)
            ctx.fillEllipse(in: rippleRect)
        }
        ctx.restoreGState()
    }
}
