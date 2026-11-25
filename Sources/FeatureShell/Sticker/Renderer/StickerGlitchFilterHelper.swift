import Foundation
import CoreGraphics
import CoreImage

/// CoreImage RGB Split and Horizontal Glitch Slice filters isolated for Sticker animations.
internal enum StickerGlitchFilterHelper: Sendable {
    internal static func applyGlitchSlices(to image: CIImage, intensity: Double) -> CIImage {
        let extent = image.extent
        guard extent.width > 4, extent.height > 12 else { return image }
        let sliceCount = 5
        let sliceH = extent.height / CGFloat(sliceCount)
        var acc = CIImage.empty()
        for i in 0..<sliceCount {
            let sliceRect = CGRect(
                x: extent.minX,
                y: extent.minY + CGFloat(i) * sliceH,
                width: extent.width,
                height: sliceH
            )
            let dir: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let weight: CGFloat = (i == 1 || i == 3) ? 1.0 : 0.35
            let sliced = image.cropped(to: sliceRect)
                .transformed(by: CGAffineTransform(translationX: dir * weight * CGFloat(intensity) * 24.0, y: 0))
                .cropped(to: extent)
            acc = sliced.composited(over: acc)
        }
        return acc.cropped(to: extent)
    }

    internal static func applyRGBSplit(to image: CIImage, offset: Double) -> CIImage {
        let dx = CGFloat(offset)
        let redShift = image.transformed(by: CGAffineTransform(translationX: -dx, y: 0))
        let blueShift = image.transformed(by: CGAffineTransform(translationX: dx, y: 0))
        let rMat = CIVector(x: 1, y: 0, z: 0, w: 0)
        let bMat = CIVector(x: 0, y: 0, z: 1, w: 0)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let redOnly = CIFilter(
            name: "CIColorMatrix",
            parameters: [kCIInputImageKey: redShift, "inputRVector": rMat, "inputGVector": zero, "inputBVector": zero]
        )?.outputImage,
        let blueOnly = CIFilter(
            name: "CIColorMatrix",
            parameters: [kCIInputImageKey: blueShift, "inputRVector": zero, "inputGVector": zero, "inputBVector": bMat]
        )?.outputImage,
        let m1 = CIFilter(
            name: "CIScreenBlendMode",
            parameters: [kCIInputImageKey: redOnly, kCIInputBackgroundImageKey: image]
        )?.outputImage,
        let finalImg = CIFilter(
            name: "CIScreenBlendMode",
            parameters: [kCIInputImageKey: blueOnly, kCIInputBackgroundImageKey: m1]
        )?.outputImage else {
            return image
        }
        return finalImg.cropped(to: image.extent.insetBy(dx: -dx * 2, dy: 0))
    }
}
