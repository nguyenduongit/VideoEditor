import CoreGraphics
import Domain

extension ExportResolution {
    /// Computes even pixel dimensions as CGSize for AVAssetWriter and video encoding.
    public func dimensions(for aspect: CanvasAspectRatio) -> CGSize {
        let dims = pixelDimensions(for: aspect)
        return CGSize(width: dims.width, height: dims.height)
    }
}
