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

        // Bắt đầu từ chính ảnh gốc đã crop theo canvas thay vì nền trong suốt clear/black.
        // Điều này đảm bảo triệt tiêu hoàn toàn bất kỳ khe hở subpixel nào ở ranh giới slice.
        var output = image.cropped(to: CGRect(origin: .zero, size: canvasSize))

        for r in 0..<config.rows {
            let rowBounds = config.rowBounds(for: r)
            let baseRowH = rowBounds.bottom - rowBounds.top

            // Trong CoreImage, trục Y=0 là cạnh dưới:
            let srcY = CGFloat(1.0 - rowBounds.bottom) * canvasH
            let srcH = CGFloat(baseRowH) * canvasH

            let isTopRow = (r == 0)
            let isBottomRow = (r == config.rows - 1)

            let rawDstH = CGFloat(config.rowHeights[r]) * canvasH
            let rawDstY = (1.0 - CGFloat(config.rowOffsets[r]) - CGFloat(config.rowHeights[r])) * canvasH

            // Mở rộng thêm 1 pixel ở các ranh giới nội bộ để phủ kín hoàn toàn mép slice
            let bleedBottom: CGFloat = isBottomRow ? 0.0 : 1.0
            let bleedTop: CGFloat = isTopRow ? 0.0 : 1.0

            let dstY = rawDstY - bleedBottom
            let dstH = rawDstH + bleedBottom + bleedTop

            for c in 0..<config.columns {
                let colBounds = config.colBounds(for: c)
                let baseColW = colBounds.right - colBounds.left

                let srcX = CGFloat(colBounds.left) * canvasW
                let srcW = CGFloat(baseColW) * canvasW

                let isLeftCol = (c == 0)
                let isRightCol = (c == config.columns - 1)

                let rawDstW = CGFloat(config.colWidths[c]) * canvasW
                let rawDstX = CGFloat(config.colOffsets[c]) * canvasW

                let bleedLeft: CGFloat = isLeftCol ? 0.0 : 1.0
                let bleedRight: CGFloat = isRightCol ? 0.0 : 1.0

                let dstX = rawDstX - bleedLeft
                let dstW = rawDstW + bleedLeft + bleedRight

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
        // Biến đổi trực tiếp từ ảnh gốc (không pre-crop trước khi transform).
        // Nếu pre-crop trước transform, GPU bilinear interpolation sẽ sample vào vùng đen trong suốt (alpha=0) ngoài biên,
        // tạo ra một đường viền đen mờ 1-pixel tại mép đường cắt (đặc biệt là đường thắt lưng).
        let toOrigin = CGAffineTransform(translationX: -srcRect.origin.x, y: -srcRect.origin.y)
        let scale = CGAffineTransform(
            scaleX: dstRect.width / srcRect.width,
            y: dstRect.height / srcRect.height
        )
        let toDest = CGAffineTransform(translationX: dstRect.origin.x, y: dstRect.origin.y)

        let transform = toOrigin.concatenating(scale).concatenating(toDest)
        return image.transformed(by: transform).cropped(to: dstRect)
    }
}
