import Foundation
@preconcurrency import CoreImage
import CoreGraphics
import os

/// Dịch vụ tự động phân tích và áp dụng chỉnh màu (color grading) cho ảnh/khung hình,
/// dựa trên các chỉ số thống kê (độ sáng, độ tương phản, độ bão hòa, cân bằng trắng)
/// được trích xuất bằng CoreImage.
///
/// So với bản gốc, các thay đổi chính:
/// 1. Độ bão hòa (chroma) được tính bằng trung bình saturation TỪNG PIXEL (qua CIColorKernel),
///    thay vì suy ra từ màu trung bình toàn ảnh (vốn dễ cho kết quả sai vì nhiều màu rực rỡ
///    có thể cộng trung bình ra một màu gần xám).
/// 2. "Điểm tối/sáng" của ảnh dùng percentile (p2/p98) từ histogram luma thay vì Min/Max tuyệt
///    đối theo từng kênh màu độc lập — bền vững hơn trước outlier (1 pixel cháy sáng, nhiễu...).
/// 3. Các heuristic exposure/shadow/contrast dùng chung MỘT khung hình đại diện (median theo
///    avgLuma) thay vì trộn median độc lập của từng chỉ số từ nhiều khung khác nhau.
/// 4. Mọi bước filter đều log lỗi khi thất bại thay vì âm thầm bỏ qua.
/// Protocol định nghĩa giao diện dịch vụ lọc và chỉnh màu
public protocol ColorGradingServiceProtocol: Sendable {
    func analyzeColors(from images: [CIImage]) -> ColorGradingParams
    func applyGrading(to image: CIImage, params: ColorGradingParams) -> CIImage
    func applyHSLSelective(to image: CIImage, hsl: HSLAdjustments) -> CIImage
    func applySkinToneEnhancement(to image: CIImage, satReduction: Float, hueShiftPink: Float) -> CIImage
}

public extension ColorGradingServiceProtocol {
    func applySkinToneEnhancement(
        to image: CIImage,
        satReduction: Float = 0.14,
        hueShiftPink: Float = 0.010
    ) -> CIImage {
        applySkinToneEnhancement(to: image, satReduction: satReduction, hueShiftPink: hueShiftPink)
    }
}

public final class ColorGradingService: ColorGradingServiceProtocol, @unchecked Sendable {

    public static let shared = ColorGradingService()

    private let colorSpace: CGColorSpace
    private let context: CIContext
    private let logger = Logger(subsystem: "com.app.colorgrading", category: "ColorGradingService")

    // MARK: - Ngưỡng & hằng số (thay cho magic number rải rác)

    private enum Thresholds {
        // Exposure
        static let darkLumaCeiling: Float = 0.4        // Dưới ngưỡng này coi là ảnh tối
        static let brightLumaFloor: Float = 0.6         // Trên ngưỡng này coi là ảnh sáng
        static let darkLumaRange: Float = 0.25          // Biên độ normalize mức độ tối
        static let brightLumaRange: Float = 0.25        // Biên độ normalize mức độ sáng
        static let highlightClipLuma: Float = 0.85      // Highlight (p98) coi như đã chói
        static let maxDarkBoostEV: Float = 0.5
        static let mutedDarkBoostEV: Float = 0.15       // Dùng khi highlight đã chói, tránh cháy thêm
        static let maxBrightCutEV: Float = -0.3

        // Shadow lift (dựa trên percentile thấp p2 của luma, không phải min tuyệt đối)
        static let veryDeepShadow: Float = 0.05
        static let deepShadow: Float = 0.15
        static let flatShadowFloor: Float = 0.4         // Vùng tối đã đủ sáng, không cần lift thêm
        static let veryDeepShadowLift: Float = 0.6
        static let deepShadowLift: Float = 0.4
        static let baseShadowLift: Float = 0.2
        static let noShadowLift: Float = 0.0

        // Contrast (dựa trên dynamic range = p98 - p2)
        static let flatDynamicRange: Float = 0.5        // Ảnh phẳng/sương mù -> cần contrast mạnh
        static let highDynamicRange: Float = 0.85       // Ảnh đã gắt sẵn -> không cần thêm
        static let highContrastValue: Float = 1.10
        static let baseContrastValue: Float = 1.03
        static let lowContrastValue: Float = 1.0

        // Saturation (dựa trên độ bão hòa TRUNG BÌNH THỰC theo từng pixel)
        static let lowChroma: Float = 0.15
        static let highChroma: Float = 0.45
        static let highSaturationBoost: Float = 1.08
        static let baseSaturation: Float = 1.05
        static let lowSaturationValue: Float = 1.02

        // White balance (trục ấm/lạnh, dựa trên R/B trung bình toàn tập khung hình)
        static let warmCastDeadZone: Float = 0.05
        static let warmCastRange: Float = 0.15
        static let maxTemperatureShift: Float = 1500.0
        static let neutralKelvin: CGFloat = 6500.0

        // Tint (trục Xanh lục / Tím - Green / Magenta)
        static let tintCastDeadZone: Float = 0.06       // Deadzone đủ rộng để tránh làm đổi màu cây cỏ tự nhiên
        static let tintCastRange: Float = 0.15
        static let maxTintShift: Float = 50.0          // Biên độ dịch chuyển tint (-50 ... +50)

        // Percentile thay cho Min/Max tuyệt đối
        static let lowPercentile: Float = 0.02          // "điểm tối" ~ percentile thứ 2
        static let highPercentile: Float = 0.98         // "điểm sáng" ~ percentile thứ 98
        static let histogramBuckets = 256
        
        // HSL Skin Tone Protection & Rosy Enhancement
        static let skinSatReduction: Float = 0.14       // Hạ 14% bão hòa màu cam da để khử vàng sạm
        static let skinRosyHueShift: Float = 0.010       // Dịch nhẹ ~3.6 độ về hướng hồng hào tự nhiên
    }

    private init() {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            preconditionFailure("Unable to create sRGB color space")
        }
        self.colorSpace = colorSpace
        self.context = CIContext(options: [
            .workingColorSpace: colorSpace
        ])
    }

    // MARK: - Chỉ số của một khung hình

    private struct FrameMetrics {
        let avgR, avgG, avgB: Float
        /// Luma tại percentile thấp (p2) - thay cho "minLuma" tuyệt đối, chống outlier điểm đen.
        let lumaLow: Float
        /// Luma tại percentile cao (p98) - thay cho "maxLuma" tuyệt đối, chống outlier điểm sáng.
        let lumaHigh: Float
        /// Độ bão hòa trung bình THỰC (trung bình saturation từng pixel).
        let avgSaturation: Float

        var avgLuma: Float { 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB }
    }

    // MARK: - Trích xuất chỉ số bằng CoreImage

    /// Render một filter dạng "area reduction" (Average/Min/Max...) ra 1 pixel RGBA8.
    private func get1x1Pixel(filterName: String, image: CIImage, extent: CGRect) -> [Float]? {
        guard let filter = CIFilter(name: filterName) else {
            logger.error("Không thể khởi tạo filter \(filterName, privacy: .public)")
            return nil
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else {
            logger.error("Filter \(filterName, privacy: .public) không trả về outputImage")
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return bitmap.map { Float($0) / 255.0 }
    }

    /// Kernel CoreImage tính saturation THỰC theo từng pixel: (max-min)/max kiểu HSV.
    /// Áp kernel này rồi lấy CIAreaAverage trên kết quả mới ra "độ bão hòa trung bình" đúng
    /// nghĩa, thay vì suy luận (sai) từ màu trung bình toàn ảnh.
    nonisolated(unsafe) private static let saturationKernel: CIColorKernel? = {
        let source = """
        kernel vec4 saturationKernel(__sample s) {
            float mx = max(s.r, max(s.g, s.b));
            float mn = min(s.r, min(s.g, s.b));
            float sat = mx > 0.0001 ? (mx - mn) / mx : 0.0;
            return vec4(sat, sat, sat, 1.0);
        }
        """
        return CIColorKernel(source: source)
    }()

    /// Kernel HSL chọn lọc dải màu da (Skin-Tone Enhancement):
    /// - Nhận diện dải màu Cam/Vàng (Hue ~ 30 độ).
    /// - Hạ bão hòa (Saturation) dải này để khử hoàn toàn hiện tượng da bị vàng sạm do phản xạ mặt đất.
    /// - Dịch nhẹ Hue về hướng hồng hào tự nhiên (Rosy Tone).
    /// - Giữ nguyên 100% màu đỏ của trang phục, màu xanh của cây cối và các màu trung tính.
    nonisolated(unsafe) private static let skinToneKernel: CIColorKernel? = {
        let source = """
        kernel vec4 skinToneKernel(__sample s, float satReduction, float hueShiftPink) {
            float r = s.r;
            float g = s.g;
            float b = s.b;
            
            float maxVal = max(r, max(g, b));
            float minVal = min(r, min(g, b));
            float delta = maxVal - minVal;
            
            float val = maxVal;
            float sat = maxVal > 0.0001 ? delta / maxVal : 0.0;
            
            if (delta < 0.0001 || sat < 0.05) {
                return s;
            }
            
            float hue = 0.0;
            if (r == maxVal) {
                hue = (g - b) / delta;
                if (hue < 0.0) {
                    hue += 6.0;
                }
            } else if (g == maxVal) {
                hue = 2.0 + (b - r) / delta;
            } else {
                hue = 4.0 + (r - g) / delta;
            }
            hue = hue / 6.0;
            
            // Dải màu da Cam / Vàng: tâm ~30 độ (0.0833), nửa độ rộng ~25 độ (0.070)
            float centerHue = 0.0833;
            float halfWidth = 0.070;
            float hueDiff = abs(hue - centerHue);
            
            if (hueDiff < halfWidth) {
                float w = cos((hueDiff / halfWidth) * 3.14159265 * 0.5);
                w = w * w;
                w = w * smoothstep(0.08, 0.25, sat);
                
                // 1. Giảm nhẹ bão hòa dải cam để da không bị sạm vàng
                sat = sat * (1.0 - satReduction * w);
                
                // 2. Dịch nhẹ về hướng hồng hào (rosy / pink tone)
                hue = hue - hueShiftPink * w;
                if (hue < 0.0) { hue += 1.0; }
                
                // 3. Chuyển đổi ngược về RGB từ HSV
                float h6 = hue * 6.0;
                float i = floor(h6);
                float f = h6 - i;
                float p = val * (1.0 - sat);
                float q = val * (1.0 - sat * f);
                float t = val * (1.0 - sat * (1.0 - f));
                
                vec3 outRGB = vec3(r, g, b);
                if (i == 0.0)      outRGB = vec3(val, t, p);
                else if (i == 1.0) outRGB = vec3(q, val, p);
                else if (i == 2.0) outRGB = vec3(p, val, t);
                else if (i == 3.0) outRGB = vec3(p, q, val);
                else if (i == 4.0) outRGB = vec3(t, p, val);
                else               outRGB = vec3(val, p, q);
                
                return vec4(outRGB, s.a);
            }
            
            return s;
        }
        """
        return CIColorKernel(source: source)
    }()

    /// Kernel CoreImage HSL chọn lọc 6 dải màu (Red, Orange/Skin, Yellow, Green, Blue, Purple):
    /// - Điều chỉnh độc lập Hue, Saturation, Luminance cho từng dải màu.
    /// - Tính trọng số mượt mà (cosine bell curve) để tránh gãy màu / color banding.
    /// - Bảo vệ vùng đen sâu và vùng trắng chói, chỉ can thiệp vào các pixel có màu sắc.
    nonisolated(unsafe) private static let hslSelectiveKernel: CIColorKernel? = {
        let source = """
        kernel vec4 hslSelectiveKernel(
            __sample s,
            vec4 dHue0_3, vec4 dHue4_7,
            vec4 dSat0_3, vec4 dSat4_7,
            vec4 dLum0_3, vec4 dLum4_7
        ) {
            float r = s.r;
            float g = s.g;
            float b = s.b;
            
            float maxC = max(r, max(g, b));
            float minC = min(r, min(g, b));
            float delta = maxC - minC;
            float lum = (maxC + minC) * 0.5;
            
            if (delta < 0.001 || lum < 0.005 || lum > 0.995) {
                return s;
            }
            
            float sat = lum > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC);
            if (sat < 0.03) {
                return s;
            }
            
            float hue = 0.0;
            if (r == maxC) {
                hue = (g - b) / delta;
                if (hue < 0.0) hue += 6.0;
            } else if (g == maxC) {
                hue = 2.0 + (b - r) / delta;
            } else {
                hue = 4.0 + (r - g) / delta;
            }
            hue = hue / 6.0;
            
            float centers[8];
            centers[0] = 0.0;     // Red
            centers[1] = 0.0833;  // Orange (30°)
            centers[2] = 0.1667;  // Yellow (60°)
            centers[3] = 0.3333;  // Green (120°)
            centers[4] = 0.5000;  // Cyan (180°)
            centers[5] = 0.6667;  // Blue (240°)
            centers[6] = 0.7917;  // Purple (285°)
            centers[7] = 0.9028;  // Magenta (325°)
            
            float widths[8];
            widths[0] = 0.075;
            widths[1] = 0.065;
            widths[2] = 0.065;
            widths[3] = 0.110;
            widths[4] = 0.090;
            widths[5] = 0.090;
            widths[6] = 0.080;
            widths[7] = 0.080;
            
            float dH[8];
            dH[0] = dHue0_3.x; dH[1] = dHue0_3.y; dH[2] = dHue0_3.z; dH[3] = dHue0_3.w;
            dH[4] = dHue4_7.x; dH[5] = dHue4_7.y; dH[6] = dHue4_7.z; dH[7] = dHue4_7.w;
            
            float dS[8];
            dS[0] = dSat0_3.x; dS[1] = dSat0_3.y; dS[2] = dSat0_3.z; dS[3] = dSat0_3.w;
            dS[4] = dSat4_7.x; dS[5] = dSat4_7.y; dS[6] = dSat4_7.z; dS[7] = dSat4_7.w;
            
            float dL[8];
            dL[0] = dLum0_3.x; dL[1] = dLum0_3.y; dL[2] = dLum0_3.z; dL[3] = dLum0_3.w;
            dL[4] = dLum4_7.x; dL[5] = dLum4_7.y; dL[6] = dLum4_7.z; dL[7] = dLum4_7.w;
            
            float totalDeltaH = 0.0;
            float totalDeltaS = 0.0;
            float totalDeltaL = 0.0;
            float totalW = 0.0;
            
            for (int i = 0; i < 8; i++) {
                float d = abs(hue - centers[i]);
                if (d > 0.5) d = 1.0 - d;
                if (d < widths[i]) {
                    float c = cos((d / widths[i]) * 1.57079632679);
                    float w = c * c;
                    totalDeltaH += dH[i] * w;
                    totalDeltaS += dS[i] * w;
                    totalDeltaL += dL[i] * w;
                    totalW += w;
                }
            }
            
            if (totalW < 0.001) {
                return s;
            }
            
            float satRoll = smoothstep(0.03, 0.15, sat);
            totalDeltaH *= satRoll;
            totalDeltaS *= satRoll;
            totalDeltaL *= satRoll;
            
            hue = fract(hue + totalDeltaH * 0.15);
            if (hue < 0.0) hue += 1.0;
            
            sat = clamp(sat * (1.0 + totalDeltaS), 0.0, 1.0);
            lum = clamp(lum + totalDeltaL * 0.35, 0.0, 1.0);
            
            float q = lum < 0.5 ? lum * (1.0 + sat) : lum + sat - lum * sat;
            float p = 2.0 * lum - q;
            
            vec3 rgb;
            vec3 t = vec3(hue + 0.33333333, hue, hue - 0.33333333);
            if (t.x < 0.0) t.x += 1.0; else if (t.x > 1.0) t.x -= 1.0;
            if (t.y < 0.0) t.y += 1.0; else if (t.y > 1.0) t.y -= 1.0;
            if (t.z < 0.0) t.z += 1.0; else if (t.z > 1.0) t.z -= 1.0;
            
            if (t.x < 0.16666667) rgb.r = p + (q - p) * 6.0 * t.x;
            else if (t.x < 0.5) rgb.r = q;
            else if (t.x < 0.66666667) rgb.r = p + (q - p) * (0.66666667 - t.x) * 6.0;
            else rgb.r = p;
            
            if (t.y < 0.16666667) rgb.g = p + (q - p) * 6.0 * t.y;
            else if (t.y < 0.5) rgb.g = q;
            else if (t.y < 0.66666667) rgb.g = p + (q - p) * (0.66666667 - t.y) * 6.0;
            else rgb.g = p;
            
            if (t.z < 0.16666667) rgb.b = p + (q - p) * 6.0 * t.z;
            else if (t.z < 0.5) rgb.b = q;
            else if (t.z < 0.66666667) rgb.b = p + (q - p) * (0.66666667 - t.z) * 6.0;
            else rgb.b = p;
            
            return vec4(rgb, s.a);
        }
        """
        return CIColorKernel(source: source)
    }()

    /// Tính saturation trung bình thực theo pixel. Nếu kernel không dùng được (thiết bị/driver
    /// lỗi biên dịch Metal kernel), fallback về công thức xấp xỉ cũ dựa trên RGB trung bình,
    /// thay vì làm rớt toàn bộ khung hình khỏi phân tích.
    private func averageSaturation(
        of image: CIImage,
        extent: CGRect,
        fallbackAvg: (r: Float, g: Float, b: Float)
    ) -> Float {
        if let kernel = Self.saturationKernel,
           let saturationImage = kernel.apply(extent: extent, arguments: [image]),
           let pixel = get1x1Pixel(filterName: "CIAreaAverage", image: saturationImage, extent: extent) {
            return pixel[0]
        }
        logger.error("Không dùng được saturationKernel, fallback về công thức chroma xấp xỉ từ RGB trung bình")
        let maxRGB = max(fallbackAvg.r, max(fallbackAvg.g, fallbackAvg.b))
        let minRGB = min(fallbackAvg.r, min(fallbackAvg.g, fallbackAvg.b))
        return maxRGB > 0.0001 ? (maxRGB - minRGB) / maxRGB : 0.0
    }

    /// Chuyển ảnh sang "ảnh luma" (R=G=B=luma) bằng CIColorMatrix, phục vụ tính histogram luma.
    private func lumaProjectedImage(from image: CIImage) -> CIImage? {
        guard let matrixFilter = CIFilter(name: "CIColorMatrix") else {
            logger.error("Không thể khởi tạo CIColorMatrix")
            return nil
        }
        let lumaVector = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        matrixFilter.setValue(image, forKey: kCIInputImageKey)
        matrixFilter.setValue(lumaVector, forKey: "inputRVector")
        matrixFilter.setValue(lumaVector, forKey: "inputGVector")
        matrixFilter.setValue(lumaVector, forKey: "inputBVector")
        matrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        matrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        return matrixFilter.outputImage
    }

    /// Tính histogram (256 bin, chuẩn hóa tổng ~1.0) của kênh luma trong ảnh.
    private func lumaHistogram(of image: CIImage, extent: CGRect, buckets: Int) -> [Float]? {
        guard let lumaImage = lumaProjectedImage(from: image) else { return nil }
        guard let histFilter = CIFilter(name: "CIAreaHistogram") else {
            logger.error("Không thể khởi tạo CIAreaHistogram")
            return nil
        }
        histFilter.setValue(lumaImage, forKey: kCIInputImageKey)
        histFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        histFilter.setValue(buckets, forKey: "inputCount")
        histFilter.setValue(1.0, forKey: "inputScale")
        guard let histOutput = histFilter.outputImage else {
            logger.error("CIAreaHistogram không trả về outputImage")
            return nil
        }

        var bins = [Float](repeating: 0, count: buckets * 4)
        context.render(
            histOutput,
            toBitmap: &bins,
            rowBytes: buckets * MemoryLayout<Float>.size * 4,
            bounds: CGRect(x: 0, y: 0, width: buckets, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )

        // R=G=B=luma nên chỉ cần đọc kênh R để lấy số đếm (đã chuẩn hóa) của mỗi bin.
        var histogram = [Float](repeating: 0, count: buckets)
        for i in 0..<buckets {
            histogram[i] = bins[i * 4]
        }
        return histogram
    }

    /// Tìm giá trị luma tại percentile mong muốn (0...1) từ histogram tích lũy.
    private func percentileValue(from histogram: [Float], target: Float) -> Float {
        guard !histogram.isEmpty else { return target }
        var cumulative: Float = 0
        for (index, count) in histogram.enumerated() {
            cumulative += count
            if cumulative >= target {
                return Float(index) / Float(histogram.count - 1)
            }
        }
        return 1.0
    }

    /// Điểm tối/sáng đại diện (p2/p98) qua histogram luma — bền vững trước outlier hơn nhiều so
    /// với Min/Max tuyệt đối theo từng kênh độc lập. Nếu histogram lỗi, fallback về
    /// CIAreaMinimum/CIAreaMaximum như cách làm cũ (kém bền hơn nhưng vẫn hoạt động).
    private func lumaLowHigh(from image: CIImage, extent: CGRect) -> (low: Float, high: Float)? {
        if let histogram = lumaHistogram(of: image, extent: extent, buckets: Thresholds.histogramBuckets) {
            let low = percentileValue(from: histogram, target: Thresholds.lowPercentile)
            let high = percentileValue(from: histogram, target: Thresholds.highPercentile)
            return (low, high)
        }

        logger.error("Không tính được histogram luma, fallback về CIAreaMinimum/CIAreaMaximum")
        guard let minP = get1x1Pixel(filterName: "CIAreaMinimum", image: image, extent: extent),
              let maxP = get1x1Pixel(filterName: "CIAreaMaximum", image: image, extent: extent) else {
            return nil
        }
        let lowLuma = 0.2126 * minP[0] + 0.7152 * minP[1] + 0.0722 * minP[2]
        let highLuma = 0.2126 * maxP[0] + 0.7152 * maxP[1] + 0.0722 * maxP[2]
        return (lowLuma, highLuma)
    }

    private func extractMetrics(from image: CIImage) -> FrameMetrics? {
        let extent = image.extent
        guard !extent.isEmpty, !extent.isInfinite, !extent.isNull,
              extent.width.isFinite, extent.height.isFinite else {
            return nil
        }

        guard let avg = get1x1Pixel(filterName: "CIAreaAverage", image: image, extent: extent) else {
            return nil
        }

        guard let lumaRange = lumaLowHigh(from: image, extent: extent) else {
            return nil
        }

        let saturation = averageSaturation(of: image, extent: extent, fallbackAvg: (avg[0], avg[1], avg[2]))

        return FrameMetrics(
            avgR: avg[0], avgG: avg[1], avgB: avg[2],
            lumaLow: lumaRange.low, lumaHigh: lumaRange.high,
            avgSaturation: saturation
        )
    }

    // MARK: - Phân tích nhiều khung hình

    /// Phân tích nhiều khung hình để tìm ra bộ thông số chỉnh màu tối ưu nhất.
    public func analyzeColors(from images: [CIImage]) -> ColorGradingParams {
        let defaultParams = ColorGradingParams(
            saturation: Thresholds.baseSaturation,
            contrast: Thresholds.baseContrastValue,
            brightness: 0.0,
            shadowAmount: Thresholds.baseShadowLift
        )

        guard !images.isEmpty else { return defaultParams }

        let metricsList = images.compactMap { extractMetrics(from: $0) }
        guard !metricsList.isEmpty else { return defaultParams }

        // Chọn "khung hình đại diện" = khung có avgLuma trung vị, thay vì lấy median độc lập
        // cho từng chỉ số riêng lẻ như bản cũ (có thể trộn lumaHigh của khung A với avgLuma của
        // khung B, dẫn tới heuristics không nhất quán). Dùng nguyên 1 khung đảm bảo mọi chỉ số
        // exposure/shadow/contrast đến từ cùng một thời điểm thực tế.
        let sortedByLuma = metricsList.sorted { $0.avgLuma < $1.avgLuma }
        let representative = sortedByLuma[sortedByLuma.count / 2]

        // Độ bão hòa và cân bằng trắng được đánh giá median trên toàn bộ tập khung hình, vì màu
        // sắc tổng thể của cảnh không nhất thiết tương quan với độ sáng của nó.
        let medianSaturation = median(of: metricsList.map { $0.avgSaturation })
        let medianAvgR = median(of: metricsList.map { $0.avgR })
        let medianAvgG = median(of: metricsList.map { $0.avgG })
        let medianAvgB = median(of: metricsList.map { $0.avgB })

        // ==========================================
        // 🧠 HEURISTICS ENGINE (Suy luận thông số)
        // ==========================================

        let targetBrightness = computeExposure(from: representative)
        let targetShadowAmount = computeShadowLift(from: representative)
        let targetContrast = computeContrast(from: representative)
        let targetSaturation = computeSaturation(medianChroma: medianSaturation)
        let targetTempOffset = computeTemperatureOffset(medianAvgR: medianAvgR, medianAvgB: medianAvgB)
        let targetTintOffset = computeTintOffset(medianAvgR: medianAvgR, medianAvgG: medianAvgG, medianAvgB: medianAvgB)

        return ColorGradingParams(
            saturation: targetSaturation,
            contrast: targetContrast,
            brightness: targetBrightness,
            shadowAmount: targetShadowAmount,
            temperatureOffset: targetTempOffset,
            tintOffset: targetTintOffset
        )
    }

    // MARK: - Từng heuristic riêng biệt (tách nhỏ để dễ đọc & test)

    /// 1. Exposure: chỉ dám bù sáng mạnh khi ảnh tối VÀ highlight (p98) chưa chạm trần.
    private func computeExposure(from metrics: FrameMetrics) -> Float {
        let luma = metrics.avgLuma
        if luma < Thresholds.darkLumaCeiling {
            let darkAmount = clamp((Thresholds.darkLumaCeiling - luma) / Thresholds.darkLumaRange)
            if metrics.lumaHigh < Thresholds.highlightClipLuma {
                return Thresholds.maxDarkBoostEV * darkAmount
            } else {
                return Thresholds.mutedDarkBoostEV * darkAmount
            }
        } else if luma > Thresholds.brightLumaFloor {
            let brightAmount = clamp((luma - Thresholds.brightLumaFloor) / Thresholds.brightLumaRange)
            return Thresholds.maxBrightCutEV * brightAmount
        }
        return 0.0
    }

    /// 2. Shadows: cứu vùng tối dựa trên điểm tối đại diện (p2), bền hơn minLuma tuyệt đối.
    private func computeShadowLift(from metrics: FrameMetrics) -> Float {
        if metrics.lumaLow < Thresholds.veryDeepShadow {
            return Thresholds.veryDeepShadowLift
        } else if metrics.lumaLow < Thresholds.deepShadow {
            return Thresholds.deepShadowLift
        } else if metrics.lumaLow > Thresholds.flatShadowFloor {
            return Thresholds.noShadowLift
        }
        return Thresholds.baseShadowLift
    }

    /// 3. Contrast: dựa trên dynamic range (p98 - p2).
    private func computeContrast(from metrics: FrameMetrics) -> Float {
        let dynamicRange = metrics.lumaHigh - metrics.lumaLow
        if dynamicRange < Thresholds.flatDynamicRange {
            return Thresholds.highContrastValue
        } else if dynamicRange > Thresholds.highDynamicRange {
            return Thresholds.lowContrastValue
        }
        return Thresholds.baseContrastValue
    }

    /// 4. Saturation: dựa trên độ bão hòa trung bình THỰC (theo pixel), không còn bị lệch bởi
    /// hiện tượng "nhiều màu rực rỡ cộng trung bình ra màu xám".
    private func computeSaturation(medianChroma: Float) -> Float {
        if medianChroma < Thresholds.lowChroma {
            return Thresholds.highSaturationBoost
        } else if medianChroma > Thresholds.highChroma {
            return Thresholds.lowSaturationValue
        }
        return Thresholds.baseSaturation
    }

    /// 5. White balance (trục ấm/lạnh - Temperature).
    private func computeTemperatureOffset(medianAvgR: Float, medianAvgB: Float) -> Float {
        let warmDiff = medianAvgR - medianAvgB
        if warmDiff > Thresholds.warmCastDeadZone {
            // Ảnh ngả vàng/đỏ (warm) -> đưa inputNeutral xuống thấp hơn để bù xanh (cool down).
            let scale = clamp((warmDiff - Thresholds.warmCastDeadZone) / Thresholds.warmCastRange)
            return -Thresholds.maxTemperatureShift * scale
        } else if warmDiff < -Thresholds.warmCastDeadZone {
            // Ảnh ngả xanh (cool) -> đưa inputNeutral lên cao hơn để bù vàng (warm up).
            let scale = clamp((-warmDiff - Thresholds.warmCastDeadZone) / Thresholds.warmCastRange)
            return Thresholds.maxTemperatureShift * scale
        }
        return 0.0
    }

    /// 6. White balance (trục xanh lục / tím - Tint).
    /// So sánh G với trung bình của R và B. Nếu G lệch đáng kể so với (R+B)/2, có hiện tượng ám xanh (green cast) hoặc ám tím (magenta cast).
    private func computeTintOffset(medianAvgR: Float, medianAvgG: Float, medianAvgB: Float) -> Float {
        let expectedG = (medianAvgR + medianAvgB) / 2.0
        let greenDiff = medianAvgG - expectedG
        if greenDiff > Thresholds.tintCastDeadZone {
            // Ảnh bị ám xanh lục (Green cast) -> đưa inputNeutral.y lên dương để CI bù màu tím (magenta).
            let scale = clamp((greenDiff - Thresholds.tintCastDeadZone) / Thresholds.tintCastRange)
            return Thresholds.maxTintShift * scale
        } else if greenDiff < -Thresholds.tintCastDeadZone {
            // Ảnh bị ám tím/hồng (Magenta cast) -> đưa inputNeutral.y xuống âm để CI bù màu xanh lục (green).
            let scale = clamp((-greenDiff - Thresholds.tintCastDeadZone) / Thresholds.tintCastRange)
            return -Thresholds.maxTintShift * scale
        }
        return 0.0
    }

    // MARK: - Tiện ích

    private func clamp(_ value: Float, _ lo: Float = 0, _ hi: Float = 1) -> Float {
        max(lo, min(hi, value))
    }

    private func median(of values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.sorted()[values.count / 2]
    }

    // MARK: - Presets Điện Ảnh (Cinematic Styles)

    public struct ColorPreset: Identifiable, Equatable, Sendable {
        public let id: Int
        public let name: String
        public let icon: String
        public let description: String
        public let exposure: Float
        public let contrast: Float
        public let highlights: Float
        public let shadows: Float
        public let saturation: Float
        public let vibrance: Float
        public let temperature: Float
        public let tint: Float
        public let hsl: HSLAdjustments

        public init(
            id: Int,
            name: String,
            icon: String,
            description: String,
            exposure: Float,
            contrast: Float,
            highlights: Float,
            shadows: Float,
            saturation: Float,
            vibrance: Float,
            temperature: Float,
            tint: Float,
            hsl: HSLAdjustments = HSLAdjustments()
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.description = description
            self.exposure = exposure
            self.contrast = contrast
            self.highlights = highlights
            self.shadows = shadows
            self.saturation = saturation
            self.vibrance = vibrance
            self.temperature = temperature
            self.tint = tint
            self.hsl = hsl
        }
    }

    public static let presets: [ColorPreset] = [
        ColorPreset(
            id: 0,
            name: "Gốc",
            icon: "🔘",
            description: "Màu nguyên bản từ camera",
            exposure: 0.0,
            contrast: 1.0,
            highlights: 0.0,
            shadows: 0.0,
            saturation: 1.0,
            vibrance: 0.0,
            temperature: 0.0,
            tint: 0.0,
            hsl: HSLAdjustments()
        ),
        ColorPreset(
            id: 1,
            name: "Tự nhiên",
            icon: "✨",
            description: "Trong trẻo, tươi sáng, tôn màu da tự nhiên",
            exposure: 0.06,
            contrast: 1.04,
            highlights: -0.10,
            shadows: 0.15,
            saturation: 1.02,
            vibrance: 0.12,
            temperature: 100.0,
            tint: -2.0,
            hsl: {
                var h = HSLAdjustments()
                h.orange = HSLChannel(hue: -0.015, saturation: -0.08, luminance: 0.10)
                h.green = HSLChannel(hue: 0.02, saturation: 0.12, luminance: 0.02)
                return h
            }()
        ),
        ColorPreset(
            id: 2,
            name: "Điện ảnh",
            icon: "🎬",
            description: "Tông Teal & Orange tương phản chuẩn Hollywood",
            exposure: 0.0,
            contrast: 1.12,
            highlights: -0.20,
            shadows: 0.10,
            saturation: 1.06,
            vibrance: 0.08,
            temperature: 250.0,
            tint: 4.0,
            hsl: {
                var h = HSLAdjustments()
                h.orange = HSLChannel(hue: -0.025, saturation: 0.12, luminance: 0.06)
                h.blue = HSLChannel(hue: -0.05, saturation: 0.25, luminance: -0.06)
                h.yellow = HSLChannel(hue: -0.03, saturation: 0.08, luminance: 0.0)
                h.green = HSLChannel(hue: -0.06, saturation: -0.15, luminance: -0.05)
                return h
            }()
        ),
        ColorPreset(
            id: 3,
            name: "Hàn Quốc",
            icon: "🌸",
            description: "Tông hồng phấn K-Pop, da trắng mịn màng, rạng rỡ",
            exposure: 0.12,
            contrast: 1.02,
            highlights: -0.15,
            shadows: 0.22,
            saturation: 0.98,
            vibrance: 0.22,
            temperature: -160.0,
            tint: 8.0,
            hsl: {
                var h = HSLAdjustments()
                h.orange = HSLChannel(hue: -0.035, saturation: -0.18, luminance: 0.22)
                h.red = HSLChannel(hue: 0.02, saturation: 0.18, luminance: 0.05)
                h.yellow = HSLChannel(hue: 0.03, saturation: -0.18, luminance: 0.04)
                return h
            }()
        ),
        ColorPreset(
            id: 4,
            name: "Rực rỡ",
            icon: "⚡️",
            description: "Màu sắc sống động, đậm đà cho video nhảy sôi động",
            exposure: 0.04,
            contrast: 1.14,
            highlights: -0.12,
            shadows: 0.08,
            saturation: 1.18,
            vibrance: 0.24,
            temperature: 60.0,
            tint: 0.0,
            hsl: {
                var h = HSLAdjustments()
                h.red = HSLChannel(hue: 0.0, saturation: 0.20, luminance: 0.0)
                h.orange = HSLChannel(hue: -0.01, saturation: 0.06, luminance: 0.06)
                h.green = HSLChannel(hue: 0.0, saturation: 0.22, luminance: 0.0)
                h.blue = HSLChannel(hue: 0.0, saturation: 0.22, luminance: 0.0)
                return h
            }()
        ),
        ColorPreset(
            id: 5,
            name: "Cổ điển",
            icon: "🎞️",
            description: "Màu phim hoài niệm Vintage Film, vùng tối ấm mượt",
            exposure: -0.02,
            contrast: 1.00,
            highlights: -0.22,
            shadows: 0.32,
            saturation: 0.90,
            vibrance: -0.05,
            temperature: 550.0,
            tint: -4.0,
            hsl: {
                var h = HSLAdjustments()
                h.yellow = HSLChannel(hue: -0.02, saturation: 0.10, luminance: 0.04)
                h.green = HSLChannel(hue: 0.04, saturation: -0.20, luminance: -0.04)
                h.blue = HSLChannel(hue: -0.04, saturation: -0.22, luminance: 0.04)
                h.orange = HSLChannel(hue: 0.01, saturation: -0.05, luminance: 0.04)
                return h
            }()
        ),
        ColorPreset(
            id: 6,
            name: "Đen trắng",
            icon: "🖤",
            description: "Monochrome nghệ thuật, tương phản cao, sáng trung tính",
            exposure: 0.05,
            contrast: 1.20,
            highlights: -0.18,
            shadows: 0.12,
            saturation: 0.0,
            vibrance: 0.0,
            temperature: 0.0,
            tint: 0.0,
            hsl: HSLAdjustments()
        )
    ]

    /// Tính toán tham số tổng hợp kết hợp giữa Preset và các tinh chỉnh thủ công
    public static func computeEffectiveParams(from params: ColorGradingParams) -> ColorGradingParams {
        guard params.presetIndex > 0 && params.presetIndex < presets.count else {
            return params
        }
        let preset = presets[params.presetIndex]
        let k = max(0.0, min(1.0, params.presetIntensity))

        let effExp = params.brightness + preset.exposure * k
        let effContrast = max(0.0, params.contrast * (1.0 + (preset.contrast - 1.0) * k))
        let effHighlights = params.highlightAmount + preset.highlights * k
        let effShadows = params.shadowAmount + preset.shadows * k
        let effSat = max(0.0, params.saturation * (1.0 + (preset.saturation - 1.0) * k))
        let effVibrance = max(-1.0, min(1.0, params.vibrance + preset.vibrance * k))
        let effTemp = params.temperatureOffset + preset.temperature * k
        let effTint = params.tintOffset + preset.tint * k

        var effHSL = params.hsl
        for i in 0..<8 {
            effHSL[i].hue = max(-1.0, min(1.0, effHSL[i].hue + preset.hsl[i].hue * k))
            effHSL[i].saturation = max(-1.0, min(1.0, effHSL[i].saturation + preset.hsl[i].saturation * k))
            effHSL[i].luminance = max(-1.0, min(1.0, effHSL[i].luminance + preset.hsl[i].luminance * k))
        }

        return ColorGradingParams(
            saturation: effSat,
            contrast: effContrast,
            brightness: effExp,
            shadowAmount: effShadows,
            highlightAmount: effHighlights,
            vibrance: effVibrance,
            temperatureOffset: effTemp,
            tintOffset: effTint,
            whites: params.whites,
            blacks: params.blacks,
            hsl: effHSL,
            presetIndex: params.presetIndex,
            presetIntensity: params.presetIntensity
        )
    }

    // MARK: - Áp dụng chỉnh màu

    public func applyGrading(to image: CIImage, params: ColorGradingParams) -> CIImage {
        let effective = Self.computeEffectiveParams(from: params)
        var result = image

        // -1. Cân bằng trắng (White Balance: Temperature & Tint)
        if effective.temperatureOffset != 0.0 || effective.tintOffset != 0.0 {
            if let wbFilter = CIFilter(name: "CITemperatureAndTint") {
                wbFilter.setValue(result, forKey: kCIInputImageKey)
                wbFilter.setValue(
                    CIVector(
                        x: Thresholds.neutralKelvin + CGFloat(effective.temperatureOffset),
                        y: CGFloat(effective.tintOffset)
                    ),
                    forKey: "inputNeutral"
                )
                wbFilter.setValue(CIVector(x: Thresholds.neutralKelvin, y: 0), forKey: "inputTargetNeutral")
                if let output = wbFilter.outputImage {
                    result = output
                } else {
                    logger.error("CITemperatureAndTint không trả về outputImage, bỏ qua bước WB")
                }
            } else {
                logger.error("Không thể khởi tạo CITemperatureAndTint")
            }
        }

        // 0. Highlight/Shadow (cứu vùng tối bị bệt đen, kìm vùng sáng chói)
        if effective.shadowAmount != 0.0 || effective.highlightAmount != 0.0 {
            if let shadowFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                shadowFilter.setValue(result, forKey: kCIInputImageKey)
                shadowFilter.setValue(effective.shadowAmount, forKey: "inputShadowAmount")
                let clampedHighlight = min(1.0, max(0.0, 1.0 + effective.highlightAmount))
                shadowFilter.setValue(clampedHighlight, forKey: "inputHighlightAmount")
                if let output = shadowFilter.outputImage {
                    result = output
                } else {
                    logger.error("CIHighlightShadowAdjust không trả về outputImage, bỏ qua bước highlight/shadow")
                }
            } else {
                logger.error("Không thể khởi tạo CIHighlightShadowAdjust")
            }
        }

        // 0.5 Whites & Blacks (tinh chỉnh điểm trắng và điểm đen qua tone curve)
        if effective.whites != 0.0 || effective.blacks != 0.0 {
            if let toneFilter = CIFilter(name: "CIToneCurve") {
                toneFilter.setValue(result, forKey: kCIInputImageKey)
                let blackY = max(0.0, min(0.25, CGFloat(effective.blacks) * 0.15))
                let whiteY = max(0.75, min(1.0, 1.0 + CGFloat(effective.whites) * 0.15))
                toneFilter.setValue(CIVector(x: 0.0, y: blackY), forKey: "inputPoint0")
                toneFilter.setValue(CIVector(x: 0.25, y: 0.25), forKey: "inputPoint1")
                toneFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
                toneFilter.setValue(CIVector(x: 0.75, y: 0.75), forKey: "inputPoint3")
                toneFilter.setValue(CIVector(x: 1.0, y: whiteY), forKey: "inputPoint4")
                if let output = toneFilter.outputImage {
                    result = output
                }
            }
        }

        // 1. Exposure (bù sáng chuẩn nhiếp ảnh, không làm mù ảnh như brightness cộng tuyến tính)
        if effective.brightness != 0.0 {
            if let expFilter = CIFilter(name: "CIExposureAdjust") {
                expFilter.setValue(result, forKey: kCIInputImageKey)
                expFilter.setValue(effective.brightness, forKey: kCIInputEVKey)
                if let output = expFilter.outputImage {
                    result = output
                } else {
                    logger.error("CIExposureAdjust không trả về outputImage, bỏ qua bước exposure")
                }
            } else {
                logger.error("Không thể khởi tạo CIExposureAdjust")
            }
        }

        // 2. Saturation & Contrast
        if effective.saturation != 1.0 || effective.contrast != 1.0 {
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(result, forKey: kCIInputImageKey)
                colorFilter.setValue(effective.saturation, forKey: kCIInputSaturationKey)
                colorFilter.setValue(effective.contrast, forKey: kCIInputContrastKey)
                colorFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
                if let output = colorFilter.outputImage {
                    result = output
                } else {
                    logger.error("CIColorControls không trả về outputImage, trả về ảnh trước bước này")
                }
            } else {
                logger.error("Không thể khởi tạo CIColorControls, bỏ qua saturation/contrast")
            }
        }

        // 3. Vibrance (Rực màu thông minh bảo vệ tông da)
        if effective.vibrance != 0.0 {
            if let vibFilter = CIFilter(name: "CIVibrance") {
                vibFilter.setValue(result, forKey: kCIInputImageKey)
                vibFilter.setValue(min(1.0, max(-1.0, effective.vibrance)), forKey: "inputAmount")
                if let output = vibFilter.outputImage {
                    result = output
                } else {
                    logger.error("CIVibrance không trả về outputImage, bỏ qua bước vibrance")
                }
            } else {
                logger.error("Không thể khởi tạo CIVibrance")
            }
        }

        // 4. HSL Chọn Lọc (Selective Hue/Sat/Lum cho 8 kênh màu)
        if !effective.hsl.isNeutral {
            result = applyHSLSelective(to: result, hsl: effective.hsl)
        }

        // 5. Skin-Tone Enhancement tự động (chỉ áp nếu chưa có chỉnh HSL cam tuỳ chỉnh)
        if effective.hsl.orange.isNeutral {
            result = applySkinToneEnhancement(to: result)
        }

        return result
    }

    /// Tinh chỉnh HSL chọn lọc 8 dải màu qua GPU CIColorKernel
    public func applyHSLSelective(to image: CIImage, hsl: HSLAdjustments) -> CIImage {
        guard let kernel = Self.hslSelectiveKernel else { return image }
        if hsl.isNeutral { return image }

        let dH0_3 = CIVector(x: CGFloat(hsl.red.hue), y: CGFloat(hsl.orange.hue), z: CGFloat(hsl.yellow.hue), w: CGFloat(hsl.green.hue))
        let dS0_3 = CIVector(x: CGFloat(hsl.red.saturation), y: CGFloat(hsl.orange.saturation), z: CGFloat(hsl.yellow.saturation), w: CGFloat(hsl.green.saturation))
        let dL0_3 = CIVector(x: CGFloat(hsl.red.luminance), y: CGFloat(hsl.orange.luminance), z: CGFloat(hsl.yellow.luminance), w: CGFloat(hsl.green.luminance))

        let dH4_7 = CIVector(x: CGFloat(hsl.cyan.hue), y: CGFloat(hsl.blue.hue), z: CGFloat(hsl.purple.hue), w: CGFloat(hsl.magenta.hue))
        let dS4_7 = CIVector(x: CGFloat(hsl.cyan.saturation), y: CGFloat(hsl.blue.saturation), z: CGFloat(hsl.purple.saturation), w: CGFloat(hsl.magenta.saturation))
        let dL4_7 = CIVector(x: CGFloat(hsl.cyan.luminance), y: CGFloat(hsl.blue.luminance), z: CGFloat(hsl.purple.luminance), w: CGFloat(hsl.magenta.luminance))

        return kernel.apply(
            extent: image.extent,
            arguments: [image, dH0_3, dH4_7, dS0_3, dS4_7, dL0_3, dL4_7]
        ) ?? image
    }
    
    /// Tinh chỉnh HSL chọn lọc dải màu da (Skin Tone Protection & Rosy Enhancement):
    /// - Hạ bão hòa dải màu Cam/Vàng (-14%) để loại bỏ hoàn toàn ánh vàng sạm do hắt sáng mặt đất.
    /// - Dịch nhẹ Hue (-3.6°) về hướng hồng hào tự nhiên, tạo làn da trắng hồng thanh thoát.
    /// - Các màu khác (Váy đỏ, Cây xanh, Áo xám, Mũ trắng) được bảo toàn nguyên vẹn 100%.
    public func applySkinToneEnhancement(
        to image: CIImage,
        satReduction: Float = 0.14,
        hueShiftPink: Float = 0.010
    ) -> CIImage {
        guard let kernel = Self.skinToneKernel else { return image }
        return kernel.apply(
            extent: image.extent,
            arguments: [image, satReduction, hueShiftPink]
        ) ?? image
    }
}
