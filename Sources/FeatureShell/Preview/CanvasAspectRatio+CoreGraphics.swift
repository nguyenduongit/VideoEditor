import CoreGraphics
import Domain

extension CanvasAspectRatio {
    /// Canvas width converted to CGFloat for view layout and Metal/CoreImage rendering.
    public var width: CGFloat {
        CGFloat(pixelWidth)
    }

    /// Canvas height converted to CGFloat for view layout and Metal/CoreImage rendering.
    public var height: CGFloat {
        CGFloat(pixelHeight)
    }

    /// Canvas logical render size in CGSize for AVFoundation and UI composition.
    public var renderSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    /// Finds the closest supported aspect ratio for a given CGSize pixel dimension.
    public static func closest(for size: CGSize) -> CanvasAspectRatio {
        closest(width: Double(size.width), height: Double(size.height))
    }
}
