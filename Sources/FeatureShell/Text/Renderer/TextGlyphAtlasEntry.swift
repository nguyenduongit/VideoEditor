import Foundation
import CoreGraphics
import CoreImage
import Metal

/// Cached GPU typography raster + Jump-Flooding Signed Distance Field (`.rgba16Float`) baked at `rasterScale`.
public struct TextGlyphAtlasEntry: @unchecked Sendable {
    public let colorTexture: MTLTexture
    public let sdfTexture: MTLTexture
    public let pixelSize: CGSize
    public let rasterScale: CGFloat
    public let toLogicalTransform: CGAffineTransform
    /// Unshifted GPU texture image covering `(0, 0, pixelSize.width, pixelSize.height)` at full `rasterScale`.
    public let rawPixelCIImage: CIImage
    /// Logical extent of `colorCIImage` centered around glyph origin `(0, 0)` after `toLogicalTransform`.
    public let localExtent: CGRect
    /// Tight CoreText shaped bounds around `(0, 0)` before SDF padding (in logical points).
    public let shapedBounds: CGRect
    public let padding: CGFloat
    public let colorCIImage: CIImage

    public init(
        colorTexture: MTLTexture,
        sdfTexture: MTLTexture,
        pixelSize: CGSize,
        rasterScale: CGFloat,
        toLogicalTransform: CGAffineTransform,
        rawPixelCIImage: CIImage,
        localExtent: CGRect,
        shapedBounds: CGRect,
        padding: CGFloat,
        colorCIImage: CIImage
    ) {
        self.colorTexture = colorTexture
        self.sdfTexture = sdfTexture
        self.pixelSize = pixelSize
        self.rasterScale = rasterScale
        self.toLogicalTransform = toLogicalTransform
        self.rawPixelCIImage = rawPixelCIImage
        self.localExtent = localExtent
        self.shapedBounds = shapedBounds
        self.padding = padding
        self.colorCIImage = colorCIImage
    }
}
