import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
import SwiftUI
#endif
import Domain
import DesignSystem

/// Bộ kết xuất và quản lý bộ nhớ đệm hình thu nhỏ (Thumbnail Cache) cho Thư viện Mẫu Chữ (Text Library).
/// Tự động phân tích màu chủ đạo, tính toán tương phản nền và render điểm ảnh chuẩn xác bằng `TextRendererEngine`.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R4.3 (đơn nhiệm).
@MainActor
public enum TextThumbnailRenderer {

    public struct ThumbnailTheme: Sendable, Equatable {
        public let isLightDominant: Bool
        public let dominantColorHex: String
        public let backgroundColors: [Color]
    }

    internal static let thumbnailCache = LRUCache<String, NSImage>(capacity: 128)
    internal static let liveFrameCache = LRUCache<String, NSImage>(capacity: 240)
    internal static let normalizedScaleCache = LRUCache<Int, Double>(capacity: 256)
    internal static let sharedEngine = TextRendererEngine()
    internal static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false
    ])

    // MARK: - Contrast & Theme Analysis

    public static func computeTheme(for config: TextConfiguration) -> ThumbnailTheme {
        let dominantHex = resolveDominantColorHex(for: config)
        let (r, g, b) = rgbComponents(of: dominantHex)
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let maxChannel = max(r, max(g, b))
        // Chỉ xem màu chủ đạo là Tối (cần nền Sáng) khi cả độ chói lẫn kênh màu mạnh nhất đều thấp (VD: Đen, Xám than, Xanh đen)
        let isDarkDominant = (lum < 0.25 && maxChannel < 0.42)
        let isLight = !isDarkDominant

        let bgColors: [Color] = isLight
            ? [Color(hex: "#14151A"), Color(hex: "#1E2028")]
            : [Color(hex: "#F1F5F9"), Color(hex: "#E2E8F0")]

        return ThumbnailTheme(
            isLightDominant: isLight,
            dominantColorHex: dominantHex,
            backgroundColors: bgColors
        )
    }

    private static func resolveDominantColorHex(for config: TextConfiguration) -> String {
        if config.background.isActive {
            switch config.background.sourceKind {
            case .solid:
                if config.background.solidColorHex.uppercased() != "NONE" && !config.background.solidColorHex.isEmpty {
                    return config.background.solidColorHex
                }
            case .linearGradient, .radialGradient:
                if let first = config.background.gradientColorsHex.first(where: { $0.uppercased() != "NONE" && !$0.isEmpty }) {
                    return first
                }
            case .inlineSVG, .animatedAsset:
                return "#38BDF8"
            }
        }

        if config.colorFillMode == .linearGradient {
            if let first = config.gradientColors.first(where: { $0.uppercased() != "NONE" && !$0.isEmpty }) {
                return first
            }
        } else if config.textColorHex.uppercased() != "NONE" && !config.textColorHex.isEmpty {
            return config.textColorHex
        }

        // Chữ rỗng (Hollow / No Fill) -> lấy màu viền
        if config.innerStroke.isActive && config.innerStroke.colorHex.uppercased() != "NONE" {
            return config.innerStroke.colorHex
        }
        if config.outerStroke.isActive && config.outerStroke.colorHex.uppercased() != "NONE" {
            return config.outerStroke.colorHex
        }
        return "#FFFFFF"
    }

    public static func luminance(of hex: String) -> Double {
        let (r, g, b) = rgbComponents(of: hex)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func rgbComponents(of hex: String) -> (Double, Double, Double) {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard clean.count >= 6, let num = UInt64(clean.prefix(6), radix: 16) else { return (1.0, 1.0, 1.0) }
        let r = Double((num & 0xFF0000) >> 16) / 255.0
        let g = Double((num & 0x00FF00) >> 8) / 255.0
        let b = Double(num & 0x0000FF) / 255.0
        return (r, g, b)
    }

    // MARK: - Snapshot & Live Animation Rendering

    public static func renderThumbnail(
        for preset: TextPreset,
        targetSize: CGSize = CGSize(width: 180, height: 180)
    ) -> NSImage? {
        let cacheKey = "\(preset.id)_\(preset.config.hashValue)_\(Int(targetSize.width))"
        if let cached = thumbnailCache[cacheKey] {
            return cached
        }

        var thumbConfig = normalizedThumbnailConfig(for: preset.config, targetSize: targetSize)
        thumbConfig.animation = TextAnimationConfiguration()

        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: thumbConfig,
            localTime: 0.0,
            duration: max(1.0, preset.defaultDuration),
            canvasSize: targetSize
        ),
        let cgImage = ciContext.createCGImage(ciImage, from: CGRect(origin: .zero, size: targetSize)) else {
            return nil
        }
        let nsImage = NSImage(cgImage: cgImage, size: targetSize)
        thumbnailCache[cacheKey] = nsImage
        return nsImage
    }

    public static func renderAnimatedFrame(
        for preset: TextPreset,
        localTime: Double,
        duration: Double,
        targetSize: CGSize = CGSize(width: 160, height: 160)
    ) -> NSImage? {
        let frameBucket = Int((localTime * 30.0).rounded())
        let quantizedTime = Double(frameBucket) / 30.0
        let frameKey = "thumb_\(preset.id)_\(preset.config.hashValue)_\(Int(targetSize.width))_\(frameBucket)"
        if let cached = liveFrameCache[frameKey] {
            return cached
        }

        let animConfig = normalizedThumbnailConfig(for: effectiveAnimatedConfig(for: preset), targetSize: targetSize)
        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: animConfig,
            localTime: quantizedTime,
            duration: max(0.5, duration),
            canvasSize: targetSize
        ),
        let cgImage = ciContext.createCGImage(ciImage, from: CGRect(origin: .zero, size: targetSize)) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: targetSize)
        liveFrameCache[frameKey] = image
        return image
    }

    public static func renderCanvasPreviewFrame(
        for preset: TextPreset,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize = CGSize(width: 960, height: 540)
    ) -> NSImage? {
        let frameBucket = Int((localTime * 30.0).rounded())
        let quantizedTime = Double(frameBucket) / 30.0
        let frameKey = "canvas_\(preset.id)_\(preset.config.hashValue)_\(Int(canvasSize.width))x\(Int(canvasSize.height))_\(frameBucket)"
        if let cached = liveFrameCache[frameKey] {
            return cached
        }

        var animConfig = effectiveAnimatedConfig(for: preset)
        let ratio = Double(min(canvasSize.width / 1920.0, canvasSize.height / 1080.0))
        animConfig.positionX = 0.0
        animConfig.positionY = 0.0
        animConfig.scale = max(0.1, animConfig.scale * max(0.25, ratio))
        guard let ciImage = sharedEngine.renderAnimatedImage(
            for: animConfig,
            localTime: quantizedTime,
            duration: max(0.5, duration),
            canvasSize: canvasSize
        ),
        let cgImage = ciContext.createCGImage(ciImage, from: CGRect(origin: .zero, size: canvasSize)) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: canvasSize)
        liveFrameCache[frameKey] = image
        return image
    }

    public static func effectiveAnimatedConfig(for preset: TextPreset) -> TextConfiguration {
        var cfg = preset.config
        if cfg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cfg.content = preset.name
        }
        if cfg.animation.isDefault {
            cfg.animation = TextAnimationConfiguration(
                inDuration: 0.75,
                inManifest: AnimationPreset.inElasticJellyDrop.manifest,
                loopManifest: AnimationPreset.loopHarmonicWave.manifest
            )
        }
        return cfg
    }

    private static func normalizedThumbnailConfig(
        for source: TextConfiguration,
        targetSize: CGSize
    ) -> TextConfiguration {
        var thumbConfig = source
        thumbConfig.positionX = 0.0
        thumbConfig.positionY = 0.0
        thumbConfig.rotation = 0.0
        thumbConfig.scale = 1.0
        thumbConfig.opacity = 1.0
        thumbConfig.background.offsetX = 0.0
        thumbConfig.background.offsetY = 0.0

        var hasher = Hasher()
        hasher.combine(thumbConfig)
        hasher.combine(Int(targetSize.width))
        hasher.combine(Int(targetSize.height))
        let scaleKey = hasher.finalize()

        if let cachedScale = normalizedScaleCache[scaleKey] {
            thumbConfig.scale = cachedScale
            return thumbConfig
        }

        let measured = sharedEngine.measureSize(for: thumbConfig, canvasSize: targetSize)
        let safeW = targetSize.width * 0.78
        let safeH = targetSize.height * 0.70
        let scaleFactor = Double(min(1.0, min(safeW / max(1.0, measured.width), safeH / max(1.0, measured.height))))
        normalizedScaleCache[scaleKey] = scaleFactor
        thumbConfig.scale = scaleFactor
        return thumbConfig
    }

    public static func clearCache() {
        thumbnailCache.removeAll()
        liveFrameCache.removeAll()
        normalizedScaleCache.removeAll()
    }
}
