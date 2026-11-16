import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Engine kết xuất các hiệu ứng thị giác toàn khung hình (Video Effects).
/// Sử dụng CoreImage và Metal tối ưu xử lý khung hình thời gian thực 60fps.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
public final class EffectEngine: Sendable {
    public static let shared = EffectEngine()

    public init() {}

    /// Tính toán xung nhịp dao động điều hòa (Harmonic Beat Pulse) tự động bắt nhịp âm thanh (120 BPM cơ sở).
    /// Sinh đỉnh nhọn tại đầu mỗi phách nhạc và suy giảm mũ mềm mại tạo hiệu ứng nảy / mini-zoom.
    public static func calculateBeatPulse(localTime: Double, speed: Double = 1.0) -> Double {
        let period = max(0.2, 0.5 / max(0.1, speed))
        let phase = localTime.truncatingRemainder(dividingBy: period) / period
        return pow(max(0.0, 1.0 - phase), 2.8)
    }

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
        if !config.filterPipeline.isEmpty {
            return DynamicShaderRuntimeEngine.shared.executePipeline(
                on: image,
                config: config,
                progress: progress,
                localTime: localTime,
                canvasSize: canvasSize
            )
        }
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
            return applyCameraShake(
                to: image,
                localTime: localTime,
                speed: config.speed,
                intensity: config.intensity,
                isBeatSynced: config.isBeatSynced,
                canvasSize: canvasSize
            )
        }
    }

    /// Tính toán độ mờ (alpha) của lớp phủ đen cho hiệu ứng Fade In:
    /// Bắt đầu màn hình đen hoàn toàn (alpha = 1), gia tốc tăng dần, sáng bừng ở cuối (alpha = 0).
    public static func calculateFadeInBlackAlpha(progress: Double, intensity: Double = 1.0) -> Double {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let p = min(1.0, max(0.0, progress))
        let blackAlpha = (1.0 - (p * p)) * norm
        return max(0.0, min(1.0, blackAlpha))
    }

    /// Tính toán độ mờ (alpha) của lớp phủ đen cho hiệu ứng Fade Out:
    /// Bắt đầu sáng (alpha = 0), gia tốc giảm dần khi tối và đạt đen hoàn toàn ở cuối (alpha = 1).
    public static func calculateFadeOutBlackAlpha(progress: Double, intensity: Double = 1.0) -> Double {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        let p = min(1.0, max(0.0, progress))
        let blackAlpha = (p * (2.0 - p)) * norm
        return max(0.0, min(1.0, blackAlpha))
    }

    private func applyFadeIn(to image: CIImage, progress: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let blackAlpha = Self.calculateFadeInBlackAlpha(progress: progress, intensity: intensity)
        guard blackAlpha > 0.005 else { return image }

        let blackColor = CIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: CGFloat(blackAlpha))
        let overlay = CIImage(color: blackColor).cropped(to: canvasRect)
        return overlay.composited(over: image)
    }

    private func applyFadeOut(to image: CIImage, progress: Double, intensity: Double, canvasRect: CGRect) -> CIImage {
        let blackAlpha = Self.calculateFadeOutBlackAlpha(progress: progress, intensity: intensity)
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

    private func applyCameraShake(
        to image: CIImage,
        localTime: Double,
        speed: Double,
        intensity: Double,
        isBeatSynced: Bool = false,
        canvasSize: CGSize
    ) -> CIImage {
        let norm = intensity > 1.0 ? (intensity / 100.0) : intensity
        guard norm > 0.01 else { return image }
        let beatPulse = isBeatSynced ? Self.calculateBeatPulse(localTime: localTime, speed: speed) : 0.0
        let factor = localTime * speed * 30.0
        let amp = 14.0 * norm * (1.0 + 0.8 * beatPulse)

        let dx = CGFloat(sin(factor) * amp)
        let dy = CGFloat(cos(factor * 1.15) * (amp * 0.75))
        let angle = CGFloat(sin(factor * 0.85) * (0.015 * norm))

        let cx = canvasSize.width / 2.0
        let cy = canvasSize.height / 2.0

        let zoomBase = 1.05 + 0.10 * beatPulse * norm
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: cx + dx, y: cy + dy)
        transform = transform.rotated(by: angle)
        transform = transform.scaledBy(x: zoomBase, y: zoomBase)
        transform = transform.translatedBy(x: -cx, y: -cy)

        return image.clampedToExtent().transformed(by: transform).cropped(to: CGRect(origin: .zero, size: canvasSize))
    }
}
