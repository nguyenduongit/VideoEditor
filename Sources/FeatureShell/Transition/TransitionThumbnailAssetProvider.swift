import AppKit
import CoreGraphics
import CoreImage
import Domain
import SwiftUI

/// Nhà cung cấp hình ảnh thật & kết xuất khung hình chuyển cảnh GPU dùng cho Thumbnail động khi hover.
/// Nạp và lưu cache các cặp hình ảnh demo đã crop vuông 1:1 theo danh mục trong bộ nhớ RAM một lần duy nhất,
/// đồng thời gọi trực tiếp `DynamicShaderRuntimeEngine.shared.executeTransition` (cùng thuật toán Metal Compute Kernel với Timeline).
/// Tuân thủ AGENTS.md R1 (File <= 300 dòng, Hàm <= 50 dòng), R6 (Sendable, Concurrency Safe).
public final class TransitionThumbnailAssetProvider: @unchecked Sendable {
    public static let shared = TransitionThumbnailAssetProvider()

    public static let thumbnailPixelSize = CGSize(width: 180, height: 180)

    private let pairsByID: [String: TransitionDemoAssetPair]
    private let defaultPair: TransitionDemoAssetPair

    // MARK: - Backward Compatibility Properties (Defaults to Nature Pair)

    public var imageA: Image { defaultPair.imageA }
    public var imageB: Image { defaultPair.imageB }
    public var nsImageA: NSImage? { defaultPair.nsImageA }
    public var nsImageB: NSImage? { defaultPair.nsImageB }
    public var ciImageA: CIImage { defaultPair.ciImageA }
    public var ciImageB: CIImage { defaultPair.ciImageB }

    private init() {
        var loaded: [String: TransitionDemoAssetPair] = [:]
        for desc in TransitionDemoAssetCatalog.builtInDescriptors {
            let pair = Self.loadAssetPair(descriptor: desc, targetSize: Self.thumbnailPixelSize)
            loaded[desc.id] = pair
        }
        self.pairsByID = loaded
        self.defaultPair = loaded[TransitionDemoAssetCatalog.naturePairID]
            ?? loaded.values.first
            ?? Self.makeFallbackSolidPair(id: "fallback", name: "Fallback")
    }

    /// Lấy cặp ảnh demo được gán cho một danh mục chuyển cảnh cụ thể.
    public func assetPair(for category: TransitionCategory) -> TransitionDemoAssetPair {
        let id = TransitionDemoAssetCatalog.pairID(for: category)
        return pairsByID[id] ?? defaultPair
    }

    /// Lấy ảnh tĩnh Cảnh A đại diện ban đầu cho thumbnail của một danh mục.
    public func imageA(for category: TransitionCategory) -> Image {
        assetPair(for: category).imageA
    }

    /// Lấy cặp ảnh theo ID trực tiếp (phục vụ kiểm thử hoặc tùy biến đặc thù).
    public func assetPair(id: String) -> TransitionDemoAssetPair? {
        pairsByID[id]
    }

    /// Executes the GPU Metal Compute Kernel transition algorithm of `item` at `rawProgress` (0.0 -> 1.0)
    /// between Scene A and Scene B of its category demo pair.
    public func renderTransitionFrame(for item: TransitionLibraryItem, rawProgress: Double) -> CGImage? {
        let pair = assetPair(for: item.category)
        let size = Self.thumbnailPixelSize
        let rect = CGRect(origin: .zero, size: size)
        let clampedRaw = max(0.0, min(1.0, rawProgress))
        let easedProgress = item.defaultEasing.apply(to: clampedRaw)

        let outCI: CIImage
        if MetalComputeRuntimeEngine.shared.isAvailable {
            let params = TimelineVideoCompositor.resolveTransitionUniformSlots(
                shaderType: item.shaderType,
                parameterValues: item.parameterValues,
                customMetalSource: item.customMetalSource
            )
            outCI = DynamicShaderRuntimeEngine.shared.executeTransition(
                from: pair.ciImageA,
                to: pair.ciImageB,
                kernelName: item.shaderType.metalKernelName,
                customSource: item.customMetalSource,
                progress: easedProgress,
                parameters: params,
                canvasSize: size
            ).cropped(to: rect)
        } else {
            let fadedFrom = TextSVGAndAssetCache.applyPremultipliedOpacity(1.0 - easedProgress, to: pair.ciImageA)
            let fadedTo = TextSVGAndAssetCache.applyPremultipliedOpacity(easedProgress, to: pair.ciImageB)
            outCI = fadedTo.composited(over: fadedFrom).cropped(to: rect)
        }

        return MetalComputeRuntimeEngine.shared.renderCGImage(from: outCI, rect: rect)
    }

    // MARK: - Asset Pair Loader

    private static func loadAssetPair(
        descriptor: TransitionDemoPairDescriptor,
        targetSize: CGSize
    ) -> TransitionDemoAssetPair {
        let (nsA, imgA) = loadSquareAsset(
            named: descriptor.squareNameA,
            fallbackOriginal: descriptor.originalNameA,
            verticalFocus: descriptor.verticalFocusA,
            fallbackColor: descriptor.fallbackColorA.swiftUIColor
        )
        let (nsB, imgB) = loadSquareAsset(
            named: descriptor.squareNameB,
            fallbackOriginal: descriptor.originalNameB,
            verticalFocus: descriptor.verticalFocusB,
            fallbackColor: descriptor.fallbackColorB.swiftUIColor
        )
        let ciA = makeScaledCIImage(from: nsA, targetSize: targetSize, fallbackColor: descriptor.fallbackColorA.ciColor)
        let ciB = makeScaledCIImage(from: nsB, targetSize: targetSize, fallbackColor: descriptor.fallbackColorB.ciColor)

        return TransitionDemoAssetPair(
            id: descriptor.id,
            displayName: descriptor.displayName,
            imageA: imgA,
            imageB: imgB,
            nsImageA: nsA,
            nsImageB: nsB,
            ciImageA: ciA,
            ciImageB: ciB
        )
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

    private static func makeFallbackSolidPair(id: String, name: String) -> TransitionDemoAssetPair {
        let ns = createSolidSquare(color: .indigo)
        let img = Image(nsImage: ns)
        let rect = CGRect(origin: .zero, size: thumbnailPixelSize)
        let ci = CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.7)).cropped(to: rect)
        return TransitionDemoAssetPair(
            id: id,
            displayName: name,
            imageA: img,
            imageB: img,
            nsImageA: ns,
            nsImageB: ns,
            ciImageA: ci,
            ciImageB: ci
        )
    }
}
