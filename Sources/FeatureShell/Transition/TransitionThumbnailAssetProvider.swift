import AppKit
import CoreGraphics
import CoreImage
import Domain
import SwiftUI

/// Nhà cung cấp hình ảnh thật & kết xuất khung hình chuyển cảnh GPU dùng cho Thumbnail động khi hover.
/// Nạp và lưu cache 2 hình ảnh (Biển Đảo & Núi Hoa) đã crop vuông 1:1 trong bộ nhớ RAM một lần duy nhất,
/// đồng thời gọi trực tiếp `DynamicShaderRuntimeEngine.shared.executeTransition` (cùng thuật toán Metal Compute Kernel với Timeline).
/// Tuân thủ AGENTS.md R1 (File <= 300 dòng, Hàm <= 50 dòng), R6 (Sendable, Concurrency Safe).
public final class TransitionThumbnailAssetProvider: @unchecked Sendable {
    public static let shared = TransitionThumbnailAssetProvider()

    public static let thumbnailPixelSize = CGSize(width: 180, height: 180)

    public let imageA: Image
    public let imageB: Image
    public let nsImageA: NSImage?
    public let nsImageB: NSImage?
    public let ciImageA: CIImage
    public let ciImageB: CIImage

    private init() {
        let (nsA, imgA) = Self.loadSquareAsset(
            named: "scene_a_sea_square",
            fallbackOriginal: "scene_a_sea",
            verticalFocus: 0.5,
            fallbackColor: .indigo
        )
        let (nsB, imgB) = Self.loadSquareAsset(
            named: "scene_b_mountain_square",
            fallbackOriginal: "scene_b_mountain",
            verticalFocus: 0.55,
            fallbackColor: .orange
        )
        self.nsImageA = nsA
        self.imageA = imgA
        self.nsImageB = nsB
        self.imageB = imgB
        self.ciImageA = Self.makeScaledCIImage(from: nsA, targetSize: Self.thumbnailPixelSize, fallbackColor: CIColor(red: 0.15, green: 0.45, blue: 0.85))
        self.ciImageB = Self.makeScaledCIImage(from: nsB, targetSize: Self.thumbnailPixelSize, fallbackColor: CIColor(red: 0.35, green: 0.65, blue: 0.25))
    }

    /// Thực thi chính thuật toán chuyển cảnh GPU Metal Compute Kernel của `preset` tại tiến độ `rawProgress` (0.0 -> 1.0)
    /// giữa Ảnh 1 (`ciImageA`) và Ảnh 2 (`ciImageB`).
    public func renderTransitionFrame(for preset: TransitionPreset, rawProgress: Double) -> CGImage? {
        let size = Self.thumbnailPixelSize
        let rect = CGRect(origin: .zero, size: size)
        let clampedRaw = max(0.0, min(1.0, rawProgress))
        let easedProgress = preset.defaultEasing.apply(to: clampedRaw)

        let outCI: CIImage
        if MetalComputeRuntimeEngine.shared.isAvailable {
            let params = TimelineVideoCompositor.resolveTransitionUniformSlots(
                shaderType: preset.shaderType,
                parameterValues: preset.parameterValues,
                customMetalSource: preset.customMetalSource
            )
            outCI = DynamicShaderRuntimeEngine.shared.executeTransition(
                from: ciImageA,
                to: ciImageB,
                kernelName: preset.shaderType.metalKernelName,
                customSource: preset.customMetalSource,
                progress: easedProgress,
                parameters: params,
                canvasSize: size
            ).cropped(to: rect)
        } else {
            let fadedFrom = TextSVGAndAssetCache.applyPremultipliedOpacity(1.0 - easedProgress, to: ciImageA)
            let fadedTo = TextSVGAndAssetCache.applyPremultipliedOpacity(easedProgress, to: ciImageB)
            outCI = fadedTo.composited(over: fadedFrom).cropped(to: rect)
        }

        return MetalComputeRuntimeEngine.shared.renderCGImage(from: outCI, rect: rect)
    }

    // MARK: - Asset Loading & Pre-scaling Helpers

    private static func makeScaledCIImage(from nsImage: NSImage?, targetSize: CGSize, fallbackColor: CIColor) -> CIImage {
        let rect = CGRect(origin: .zero, size: targetSize)
        guard let nsImage,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CIImage(color: fallbackColor).cropped(to: rect)
        }
        let baseCI = CIImage(cgImage: cgImage)
        let ext = baseCI.extent
        guard ext.width > 0, ext.height > 0 else {
            return CIImage(color: fallbackColor).cropped(to: rect)
        }
        let sx = targetSize.width / ext.width
        let sy = targetSize.height / ext.height
        let scaled = baseCI
            .transformed(by: CGAffineTransform(translationX: -ext.origin.x, y: -ext.origin.y))
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .cropped(to: rect)
        if let baked = MetalComputeRuntimeEngine.shared.renderCGImage(from: scaled, rect: rect) {
            return CIImage(cgImage: baked)
        }
        return scaled
    }

    private static func loadSquareAsset(
        named squareName: String,
        fallbackOriginal originalName: String,
        verticalFocus: CGFloat,
        fallbackColor: Color
    ) -> (NSImage?, Image) {
        if let url = resolveAssetURL(named: squareName, ext: "jpg"),
           let img = NSImage(contentsOf: url) {
            return (img, Image(nsImage: img))
        }
        if let origUrl = resolveAssetURL(named: originalName, ext: "jpg"),
           let cropped = cropSquare(from: origUrl, verticalFocus: verticalFocus) {
            return (cropped, Image(nsImage: cropped))
        }
        let fallbackNS = createSolidSquare(color: fallbackColor)
        return (fallbackNS, Image(nsImage: fallbackNS))
    }

    private static func resolveAssetURL(named name: String, ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let bundleUrl = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "TransitionThumbnails"
        ) {
            return bundleUrl
        }
        if let bundleUrl = Bundle.module.url(forResource: name, withExtension: ext) {
            return bundleUrl
        }
        #endif

        let paths = [
            "Sources/FeatureShell/Resources/TransitionThumbnails/\(name).\(ext)",
            "Resources/TransitionThumbnails/\(name).\(ext)",
            "\(name).\(ext)"
        ]
        for p in paths {
            let u = URL(fileURLWithPath: p)
            if FileManager.default.fileExists(atPath: u.path) {
                return u
            }
        }
        return nil
    }

    private static func cropSquare(from url: URL, verticalFocus: CGFloat) -> NSImage? {
        guard let source = NSImage(contentsOf: url),
              let rep = source.representations.first else { return nil }
        let w = CGFloat(rep.pixelsWide)
        let h = CGFloat(rep.pixelsHigh)
        guard w > 0, h > 0 else { return nil }
        var side = min(w, h)
        if Int(side) % 2 != 0 { side -= 1 }
        let x = floor((w - side) * 0.5)
        let y = floor((h - side) * verticalFocus)
        let cropRect = CGRect(x: x, y: y, width: side, height: side)
        guard let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: cropped, size: CGSize(width: side, height: side))
    }

    private static func createSolidSquare(color: Color) -> NSImage {
        let size = NSSize(width: 200, height: 200)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor(color).setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        return img
    }
}
