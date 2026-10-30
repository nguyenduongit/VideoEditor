import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Engine kết xuất các hiệu ứng thị giác toàn khung hình (Video Effects).
/// Sử dụng CoreImage và Metal tối ưu xử lý khung hình thời gian thực 60fps.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public final class EffectEngine: Sendable {
    public init() {}

    /// Áp dụng hiệu ứng lên khung hình `image` tại thời điểm `localTime` với thời lượng `duration`.
    public func applyEffect(
        to image: CIImage,
        config: EffectConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage {
        guard duration > 0, canvasSize.width > 0, canvasSize.height > 0 else { return image }
        let progress = min(1.0, max(0.0, localTime / duration))
        let canvasRect = CGRect(origin: .zero, size: canvasSize)

        switch config.type {
        case .fadeIn:
            return applyFadeIn(to: image, progress: progress, intensity: config.intensity, canvasRect: canvasRect)
        case .fadeOut:
            return applyFadeOut(to: image, progress: progress, intensity: config.intensity, canvasRect: canvasRect)
        case .whiteFlash:
            return applyWhiteFlash(to: image, progress: progress, speed: config.speed, intensity: config.intensity, canvasRect: canvasRect)
        case .cinematicBlur:
            return applyCinematicBlur(to: image, blurRadius: config.blurRadius, intensity: config.intensity, canvasRect: canvasRect)
        case .cameraShake:
            return applyCameraShake(to: image, localTime: localTime, speed: config.speed, intensity: config.intensity, canvasSize: canvasSize)
        }
    }

    private func applyFadeIn(to image: CIImage, progress: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let smoothT = sin(progress * .pi * 0.5)
        let blackAlpha = (1.0 - smoothT) * norm
        guard blackAlpha > 0.005 else { return image }

        let blackColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: CGFloat(blackAlpha))
        let overlay = CIImage(color: blackColor).cropped(to: canvasRect)
        return overlay.composited(over: image)
    }

    private func applyFadeOut(to image: CIImage, progress: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let smoothT = progress * progress
        let blackAlpha = smoothT * norm
        guard blackAlpha > 0.005 else { return image }

        let blackColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: CGFloat(blackAlpha))
        let overlay = CIImage(color: blackColor).cropped(to: canvasRect)
        return overlay.composited(over: image)
    }

    private func applyWhiteFlash(to image: CIImage, progress: Double, speed: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let decay = exp(-progress * 4.5 * speed)
        let whiteAlpha = decay * norm
        guard whiteAlpha > 0.005 else { return image }

        let whiteColor = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: CGFloat(whiteAlpha))
        let overlay = CIImage(color: whiteColor).cropped(to: canvasRect)
        return overlay.composited(over: image)
    }

    private func applyCinematicBlur(to image: CIImage, blurRadius: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let effectiveRadius = max(1.0, blurRadius * norm)
        guard effectiveRadius > 1.0 else { return image }

        return image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: effectiveRadius])
            .cropped(to: canvasRect)
    }

    private func applyCameraShake(to image: CIImage, localTime: Double, speed: Double, intensity: Double, canvasSize: CGSize) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        guard norm > 0.01 else { return image }
        let factor = localTime * speed * 30.0
        let amp = 14.0 * norm

        let dx = CGFloat(sin(factor) * amp)
        let dy = CGFloat(cos(factor * 1.15) * (amp * 0.75))
        let angle = CGFloat(sin(factor * 0.85) * (0.015 * norm))

        let cx = canvasSize.width / 2.0
        let cy = canvasSize.height / 2.0

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: cx + dx, y: cy + dy)
        transform = transform.rotated(by: angle)
        transform = transform.scaledBy(x: 1.05, y: 1.05)
        transform = transform.translatedBy(x: -cx, y: -cy)

        return image.clampedToExtent().transformed(by: transform).cropped(to: CGRect(origin: .zero, size: canvasSize))
    }
}
