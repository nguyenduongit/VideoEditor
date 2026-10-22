import Foundation
import CoreImage
import CoreGraphics

struct LegLengtheningGeometry: Sendable {
    let lowerRow: CGFloat
    let upperRow: CGFloat
    let sourceMiddleRows: CGFloat
    let targetMiddleRows: CGFloat
    let deltaRows: CGFloat

    var upperDestinationRow: CGFloat { upperRow + deltaRows }
}

public final class LegLengtheningService: @unchecked Sendable {
    
    public static let shared = LegLengtheningService()
    
    // Ba vùng dùng hàng pixel nguyên:
    // - y <= lower_row: giữ nguyên
    // - lower_row < y < upper_dest_row: chỉ vùng giữa được scale
    // - y >= upper_dest_row: giữ nguyên kích thước, chỉ dịch lên delta_rows
    private let warpKernel: CIWarpKernel? = {
        let kernelCode = """
        kernel vec2 legWarp(float lower_row, float upper_row, float upper_dest_row,
                            float source_middle_rows, float target_middle_rows,
                            float delta_rows) {
            float y = destCoord().y;
            float src_y = y;
            if (y >= upper_dest_row) {
                src_y = y - delta_rows;
            } else if (y > lower_row) {
                float first_middle_row = lower_row + 1.0;
                float position = y - first_middle_row;
                src_y = first_middle_row
                    + ((position + 0.5) * source_middle_rows / target_middle_rows - 0.5);
                src_y = clamp(src_y, first_middle_row, upper_row - 1.0);
            } else {
                src_y = y;
            }
            return vec2(destCoord().x, src_y);
        }
        """
        return CIWarpKernel(source: kernelCode)
    }()
    
    private init() {}

    func geometry(
        imageHeight: CGFloat,
        hipYNorm: Double,
        ankleYNorm: Double,
        scaleFactor: Double
    ) -> LegLengtheningGeometry? {
        guard imageHeight >= 3.0 else { return nil }
        let maxRow = imageHeight - 1.0
        let lowerRow = round(CGFloat(ankleYNorm) * maxRow)
        let upperRow = round(CGFloat(hipYNorm) * maxRow)
        let sourceMiddleRows = upperRow - lowerRow - 1.0
        guard sourceMiddleRows >= 1.0,
              lowerRow >= 0.0, upperRow <= maxRow else {
            return nil
        }

        let targetMiddleRows = max(sourceMiddleRows,
                                   round(sourceMiddleRows * CGFloat(scaleFactor)))
        return LegLengtheningGeometry(
            lowerRow: lowerRow,
            upperRow: upperRow,
            sourceMiddleRows: sourceMiddleRows,
            targetMiddleRows: targetMiddleRows,
            deltaRows: targetMiddleRows - sourceMiddleRows
        )
    }
    
    /// Chỉ scale vùng giữa hai hàng pixel; vùng dưới đứng yên và vùng trên chỉ tịnh tiến.
    public func applyLegLengthening(
        to inputImage: CIImage,
        proportion: BodyProportionResult
    ) -> CIImage {
        guard proportion.isApplied && proportion.scaleFactor > 1.01,
              let kernel = warpKernel else {
            return inputImage
        }
        
        let extent = inputImage.extent
        let width = extent.width
        let height = extent.height
        guard width > 0 && height > 0 else { return inputImage }
        
        // Tọa độ chuẩn hóa được chốt vào hàng pixel thật. Đường dưới thuộc khối dưới;
        // đường trên thuộc khối trên. Chỉ các hàng nằm giữa hai đường được scale.
        guard let geometry = geometry(
            imageHeight: height,
            hipYNorm: proportion.hipYNorm,
            ankleYNorm: proportion.ankleYNorm,
            scaleFactor: proportion.scaleFactor
        ) else {
            return inputImage
        }
        guard geometry.deltaRows >= 1.0 else { return inputImage }
        let outputExtent = CGRect(x: extent.minX, y: extent.minY, width: width, height: height)
        
        // 2. Chạy CIWarpKernel trên 1 texture duy nhất -> Triệt tiêu hoàn toàn đường kẻ đen vết ghép
        guard let warpedImage = kernel.apply(
            extent: outputExtent,
            roiCallback: { index, rect in
                return extent
            },
            image: inputImage,
            arguments: [
                extent.minY + geometry.lowerRow,
                extent.minY + geometry.upperRow,
                extent.minY + geometry.upperDestinationRow,
                geometry.sourceMiddleRows,
                geometry.targetMiddleRows,
                geometry.deltaRows
            ]
        ) else {
            return inputImage
        }

        // Khung giữ nguyên và neo tuyệt đối ở đáy. Phần khối trên vượt quá mép trên
        // sẽ bị cắt; không được dịch crop vì như vậy sẽ làm khối dưới di chuyển.
        return warpedImage.cropped(to: outputExtent)
    }
}
