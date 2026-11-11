import Foundation
import CoreImage
import CoreGraphics

extension TimelineVideoCompositor {
    func applyPerspective(
        to image: CIImage,
        width: CGFloat,
        height: CGFloat,
        pX: Double,
        pY: Double
    ) -> CIImage {
        guard abs(pX) > 0.001 || abs(pY) > 0.001 else { return image }
        var tl = CGPoint(x: 0, y: height)
        var tr = CGPoint(x: width, y: height)
        var br = CGPoint(x: width, y: 0)
        var bl = CGPoint(x: 0, y: 0)

        let factor: CGFloat = 0.45
        let dx = (width / 2.0) * CGFloat(pY) * factor
        let dy = (height / 2.0) * CGFloat(pX) * factor

        if pY >= 0 {
            tl.x += dx
            tr.x -= dx
        } else {
            bl.x -= dx
            br.x += dx
        }

        if pX >= 0 {
            tr.y -= dy
            br.y += dy
        } else {
            tl.y += dy
            bl.y -= dy
        }

        guard let filter = CIFilter(name: "CIPerspectiveTransform", parameters: [
            kCIInputImageKey: image,
            "inputTopLeft": CIVector(cgPoint: tl),
            "inputTopRight": CIVector(cgPoint: tr),
            "inputBottomRight": CIVector(cgPoint: br),
            "inputBottomLeft": CIVector(cgPoint: bl)
        ]), let out = filter.outputImage else {
            return image
        }
        return out
    }
}
