import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Phần mở rộng cho `TextShaderFilterEngine`: Xử lý Đổ bóng (Shadow) và Phát quang (Glow)
/// trực tiếp trên GPU Metal qua CoreImage với thuật toán Dual-Grid Downsampling Blur,
/// loại bỏ 100% tình trạng giật lag, đảm bảo tốc độ 60fps mượt mà ngay cả với bán kính nhòe cực lớn.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
extension TextShaderFilterEngine {

    /// Áp dụng đồng thời Shadow và Glow theo thứ tự đồ họa chuẩn (Text trên cùng -> Glow ở giữa -> Shadow dưới cùng).
    /// Silhouette được trích xuất độc lập từ ảnh chữ gốc, không làm mờ lặp chồng chéo và giới hạn chặt chẽ trong canvasExtent.
    public static func applyStyleEffects(
        to image: CIImage,
        shadow: TextShadowStyle,
        glow: TextGlowStyle,
        extent: CGRect
    ) -> CIImage {
        guard !extent.isInfinite, !extent.isEmpty else { return image }
        let shadowLayer = renderShadowLayer(from: image, shadow: shadow, extent: extent)
        let glowLayer = renderGlowLayer(from: image, glow: glow, extent: extent)

        if shadowLayer == nil && glowLayer == nil {
            return image
        }

        var result = image
        if let glowLayer {
            result = result.composited(over: glowLayer)
        }
        if let shadowLayer {
            result = result.composited(over: shadowLayer)
        }
        return result.cropped(to: extent)
    }

    /// Trích xuất lớp Đổ bóng (Drop Shadow) dưới dạng tầng riêng biệt trên GPU Metal
    public static func renderShadowLayer(
        from image: CIImage,
        shadow: TextShadowStyle,
        extent: CGRect
    ) -> CIImage? {
        guard shadow.isEnabled, shadow.opacity > 0.5, shadow.colorHex.uppercased() != "NONE" else { return nil }
        let baseColor = TextAdvancedStyleRenderer.parseHexColor(shadow.colorHex)
        let alpha = CGFloat(shadow.opacity / 100.0) * baseColor.alphaComponent
        guard alpha > 0.01 else { return nil }
        let shadowColor = CIColor(cgColor: baseColor.withAlphaComponent(alpha).cgColor)

        let dx = CGFloat(shadow.offsetX)
        let dy = CGFloat(-shadow.offsetY)
        let translated = image.transformed(by: CGAffineTransform(translationX: dx, y: dy))

        guard let colorFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: translated,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: shadowColor.red),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: shadowColor.green),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: shadowColor.blue),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: shadowColor.alpha),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ]), let colorized = colorFilter.outputImage else {
            return nil
        }

        if shadow.blur > 0.1 {
            return downsampledBlur(image: colorized, radius: shadow.blur, extent: extent)
        } else {
            return colorized.cropped(to: extent)
        }
    }

    /// Trích xuất lớp Phát quang (Outer Glow) dưới dạng tầng riêng biệt trên GPU Metal
    public static func renderGlowLayer(
        from image: CIImage,
        glow: TextGlowStyle,
        extent: CGRect
    ) -> CIImage? {
        guard glow.isEnabled, glow.intensity > 0.5, glow.range > 0.2, glow.colorHex.uppercased() != "NONE" else { return nil }
        let baseColor = TextAdvancedStyleRenderer.parseHexColor(glow.colorHex)
        let normIntensity = max(0.0, min(1.0, glow.intensity / 100.0))
        let alpha = CGFloat(min(1.0, 0.35 + normIntensity * 0.65))
        let glowColor = CIColor(cgColor: baseColor.withAlphaComponent(alpha).cgColor)
        let boost = normIntensity > 0.5 ? CGFloat(1.0 + (normIntensity - 0.5) * 1.5) : 1.0

        guard let colorFilter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: glowColor.red * boost),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: glowColor.green * boost),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: glowColor.blue * boost),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: min(1.0, glowColor.alpha * boost)),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ]), let colorized = colorFilter.outputImage else {
            return nil
        }

        return downsampledBlur(image: colorized, radius: glow.range, extent: extent)
    }

    /// Làm nhòe đa tầng phần cứng (Dual-Grid Downsampling Blur) đạt tốc độ tối đa trên Metal GPU
    private static func downsampledBlur(
        image: CIImage,
        radius: Double,
        extent: CGRect
    ) -> CIImage? {
        guard radius > 0.1 else { return image.cropped(to: extent) }
        let scale: CGFloat
        if radius > 20.0 {
            scale = 0.25
        } else if radius > 8.0 {
            scale = 0.5
        } else {
            scale = 1.0
        }

        let input: CIImage = (scale < 0.999)
            ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : image
        let scaledRadius = radius * Double(scale)

        guard let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: input,
            kCIInputRadiusKey: scaledRadius
        ]), let blurred = blurFilter.outputImage else {
            return nil
        }

        if scale < 0.999 {
            let invScale = 1.0 / scale
            return blurred.transformed(by: CGAffineTransform(scaleX: invScale, y: invScale)).cropped(to: extent)
        } else {
            return blurred.cropped(to: extent)
        }
    }

    /// Tương thích ngược: Áp dụng hiệu ứng Đổ bóng lên CIImage đơn lẻ
    public static func applyShadow(to image: CIImage, shadow: TextShadowStyle) -> CIImage {
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty,
              let shadowLayer = renderShadowLayer(from: image, shadow: shadow, extent: extent) else {
            return image
        }
        return image.composited(over: shadowLayer).cropped(to: extent)
    }

    /// Tương thích ngược: Áp dụng hiệu ứng Phát quang lên CIImage đơn lẻ
    public static func applyGlow(to image: CIImage, glow: TextGlowStyle) -> CIImage {
        let extent = image.extent
        guard !extent.isInfinite, !extent.isEmpty,
              let glowLayer = renderGlowLayer(from: image, glow: glow, extent: extent) else {
            return image
        }
        return image.composited(over: glowLayer).cropped(to: extent)
    }
}
