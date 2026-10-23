import Foundation
import CoreImage
import CoreGraphics
import Domain

/// GPU-accelerated video grid slicing and block composition using CoreImage.
/// Complies with R2.3, R3.1, and R9.4 of AGENTS.md.
public enum GridSliceCompositor {
    public static func applyGrid(
        to image: CIImage,
        config: GridConfiguration,
        canvasSize: CGSize
    ) -> CIImage {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return image }
        guard config.rows > 0, config.columns > 0 else { return image }
        guard config.rowHeights.count == config.rows,
              config.colWidths.count == config.columns,
              config.rowOffsets.count == config.rows,
              config.colOffsets.count == config.columns else {
            return image
        }

        let canvasW = canvasSize.width
        let canvasH = canvasSize.height
        let defaultRowH = canvasH / CGFloat(config.rows)
        let defaultColW = canvasW / CGFloat(config.columns)

        var output = CIImage(color: CIColor.clear).cropped(to: CGRect(origin: .zero, size: canvasSize))

        for r in 0..<config.rows {
            // CoreImage Y=0 is bottom
            let srcY = CGFloat(config.rows - 1 - r) * defaultRowH
            let srcH = defaultRowH

            let dstH = CGFloat(config.rowHeights[r]) * canvasH
            let dstY = (1.0 - CGFloat(config.rowOffsets[r]) - CGFloat(config.rowHeights[r])) * canvasH

            for c in 0..<config.columns {
                let srcX = CGFloat(c) * defaultColW
                let srcW = defaultColW

                let dstW = CGFloat(config.colWidths[c]) * canvasW
                let dstX = CGFloat(config.colOffsets[c]) * canvasW

                guard srcW > 0, srcH > 0, dstW > 0, dstH > 0 else { continue }

                let srcRect = CGRect(x: srcX, y: srcY, width: srcW, height: srcH)
                let dstRect = CGRect(x: dstX, y: dstY, width: dstW, height: dstH)

                let slice = sliceBlock(
                    from: image,
                    srcRect: srcRect,
                    dstRect: dstRect
                )
                output = slice.composited(over: output)
            }
        }

        return output.cropped(to: CGRect(origin: .zero, size: canvasSize))
    }

    private static func sliceBlock(
        from image: CIImage,
        srcRect: CGRect,
        dstRect: CGRect
    ) -> CIImage {
        let cropped = image.cropped(to: srcRect)
        let toOrigin = CGAffineTransform(translationX: -srcRect.origin.x, y: -srcRect.origin.y)
        let scale = CGAffineTransform(
            scaleX: dstRect.width / srcRect.width,
            y: dstRect.height / srcRect.height
        )
        let toDest = CGAffineTransform(translationX: dstRect.origin.x, y: dstRect.origin.y)

        let transform = toOrigin.concatenating(scale).concatenating(toDest)
        return cropped.transformed(by: transform).cropped(to: dstRect)
    }
}
