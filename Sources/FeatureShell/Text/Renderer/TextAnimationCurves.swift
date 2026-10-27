import Foundation
import Domain

/// Cung cấp các đường cong gia tốc (Motion Easing), vật lý Squash & Stretch và thứ tự Stagger cho Text Animation.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum TextAnimationCurves: Sendable {
    /// Áp dụng đường cong gia tốc (Easing) dựa trên `TextMotionEasing`.
    public static func apply(progress: Double, easing: TextMotionEasing) -> Double {
        let p = min(1.0, max(0.0, progress))
        switch easing {
        case .smooth:
            return 1.0 - pow(1.0 - p, 3.0)
        case .spring:
            return springOvershoot(p)
        case .bounce:
            return bounceEaseOut(p)
        case .elastic:
            return elasticEaseOut(p)
        }
    }

    /// Đường cong làm mượt cơ bản (Cubic Ease-Out).
    public static func smoothEase(_ p: Double) -> Double {
        let clamped = min(1.0, max(0.0, p))
        return 1.0 - pow(1.0 - clamped, 3.0)
    }

    /// Đường cong nảy (Bounce Ease-Out).
    public static func bounceEaseOut(_ p: Double) -> Double {
        let n1 = 7.5625
        let d1 = 2.75
        var x = p
        if x < 1.0 / d1 {
            return n1 * x * x
        } else if x < 2.0 / d1 {
            x -= 1.5 / d1
            return n1 * x * x + 0.75
        } else if x < 2.5 / d1 {
            x -= 2.25 / d1
            return n1 * x * x + 0.9375
        } else {
            x -= 2.625 / d1
            return n1 * x * x + 0.984375
        }
    }

    /// Đường cong đàn hồi (Elastic Ease-Out).
    public static func elasticEaseOut(_ p: Double) -> Double {
        if p <= 0.0 { return 0.0 }
        if p >= 1.0 { return 1.0 }
        let c4 = (2.0 * .pi) / 3.0
        return pow(2.0, -10.0 * p) * sin((p * 10.0 - 0.75) * c4) + 1.0
    }

    /// Đường cong lò xo tự nhiên (Spring with Overshoot) chuẩn UI hiện đại
    public static func springOvershoot(_ p: Double, tension: Double = 1.7) -> Double {
        let clamped = min(1.0, max(0.0, p))
        if clamped <= 0.0 { return 0.0 }
        if clamped >= 1.0 { return 1.0 }
        let t = clamped - 1.0
        return t * t * ((tension + 1.0) * t + tension) + 1.0
    }

    /// Tính hệ số co giãn đàn hồi 2 trục ngược pha (Squash & Stretch) bảo toàn diện tích
    public static func jellySquashStretch(progress: Double, amplitude: Double = 0.38, frequency: Double = 3.5) -> (scaleX: Double, scaleY: Double) {
        let p = min(1.0, max(0.0, progress))
        if p >= 1.0 { return (1.0, 1.0) }
        let damping = exp(-p * 4.2)
        let wave = sin(p * .pi * frequency) * amplitude * damping
        let sx = max(0.25, 1.0 + wave)
        let sy = max(0.25, 1.0 - wave * 0.85)
        return (sx, sy)
    }

    /// Tính biến dạng bẹp chân chữ khi tiếp đất từ trên cao (Impact Squash)
    public static func impactSquash(progress: Double) -> (scaleX: Double, scaleY: Double) {
        let p = min(1.0, max(0.0, progress))
        if p < 0.32 {
            // Đang lao xuống nhanh: kéo dài theo trục dọc (Stretch)
            let stretch = (0.32 - p) / 0.32 * 0.22
            return (1.0 - stretch * 0.6, 1.0 + stretch)
        } else if p < 0.65 {
            // Chạm đất: bẹp ngang (Squash)
            let local = sin(((p - 0.32) / 0.33) * .pi)
            return (1.0 + local * 0.24, 1.0 - local * 0.20)
        } else {
            // Dư chấn đàn hồi nhẹ về 1.0
            let tail = sin(((p - 0.65) / 0.35) * .pi * 2.0) * (1.0 - p) * 0.12
            return (1.0 - tail, 1.0 + tail)
        }
    }

    /// Tính chỉ số thứ tự trễ (Stagger Index) theo hướng `TextStaggerDirection`
    public static func staggerOrderIndex(index: Int, count: Int, direction: TextStaggerDirection) -> Double {
        guard count > 1 else { return 0.0 }
        let maxIdx = Double(count - 1)
        let idx = Double(max(0, min(count - 1, index)))
        switch direction {
        case .forward:
            return idx
        case .backward:
            return maxIdx - idx
        case .centerOut:
            let mid = maxIdx / 2.0
            return abs(idx - mid)
        case .edgesIn:
            let mid = maxIdx / 2.0
            return mid - abs(idx - mid)
        case .random:
            // Hàm băm tất định (deterministic hash) để không bị nhấp nháy giữa các frame
            let hash = UInt64((index + 1) * 2654435761) % 1024
            return (Double(hash) / 1024.0) * maxIdx
        }
    }
}
