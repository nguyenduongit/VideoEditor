import Foundation

/// Bộ tính toán nội suy 60fps thuần túy (pure, thread-safe) cho mọi thông số Keyframe.
/// Hỗ trợ 6 đường cong: Linear, Smooth (Cubic Ease In-Out), Ease In, Ease Out, Spring, và Hold.
/// Tuân thủ quy tắc R3.1 và R4.1 của AGENTS.md.
public enum KeyframeEvaluator {
    /// Tính toán giá trị nội suy của một thuộc tính tại thời điểm nội bộ `localTime` (giây).
    public static func evaluate(
        propertyKey: String,
        baseValue: Double,
        atLocalTime localTime: Double,
        map: ClipKeyframeMap
    ) -> Double {
        let points = map.points(for: propertyKey)
        guard !points.isEmpty else { return baseValue }
        if points.count == 1 {
            return points[0].value
        }

        let t = max(0.0, localTime)
        if let first = points.first, t <= first.timeOffset.seconds {
            return first.value
        }
        if let last = points.last, t >= last.timeOffset.seconds {
            return last.value
        }

        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let t0 = p0.timeOffset.seconds
            let t1 = p1.timeOffset.seconds
            if t >= t0 && t <= t1 {
                let span = t1 - t0
                guard span > 0.00001 else { return p1.value }
                let rawProgress = max(0.0, min(1.0, (t - t0) / span))
                let easedProgress = applyCurve(rawProgress, mode: p0.interpolation)
                return p0.value + (p1.value - p0.value) * easedProgress
            }
        }
        return points.last?.value ?? baseValue
    }

    /// Trả về bộ `properties` đã được ghi đè các giá trị số (`number`) tại `localTime` nếu thuộc tính đó có Keyframe.
    public static func resolvedProperties(
        baseProperties: [String: PropertyValue],
        atLocalTime localTime: Double
    ) -> [String: PropertyValue] {
        guard let map = ClipKeyframeMap.from(properties: baseProperties), !map.isEmpty else {
            return baseProperties
        }
        var resolved = baseProperties
        for (key, points) in map.tracks where !points.isEmpty {
            let fallback = baseProperties[key]?.asNumber ?? points[0].value
            let interpolated = evaluate(
                propertyKey: key,
                baseValue: fallback,
                atLocalTime: localTime,
                map: map
            )
            resolved[key] = .number(interpolated)
        }
        return resolved
    }

    /// Hàm ánh xạ tiến trình `t` (0.0 ... 1.0) theo đường cong nội suy `KeyframeInterpolation`.
    public static func applyCurve(_ t: Double, mode: KeyframeInterpolation) -> Double {
        let x = max(0.0, min(1.0, t))
        switch mode {
        case .linear:
            return x
        case .smooth:
            // Smoothstep / Cubic Hermite (3x^2 - 2x^3)
            return x * x * (3.0 - 2.0 * x)
        case .easeIn:
            // Cubic Ease-In
            return x * x * x
        case .easeOut:
            // Cubic Ease-Out
            let inv = 1.0 - x
            return 1.0 - (inv * inv * inv)
        case .spring:
            // Under-damped spring curve with subtle overshoot settling at 1.0
            if x >= 0.999 { return 1.0 }
            let damping = 5.5
            let frequency = 2.2 * Double.pi
            return 1.0 - exp(-damping * x) * cos(frequency * x)
        case .hold:
            return x >= 0.9999 ? 1.0 : 0.0
        }
    }
}

// MARK: - Timeline Surgery Helpers (Trim & Split)

extension ClipKeyframeMap {
    /// Điều chỉnh các mốc Keyframe khi Clip bị cắt ngắn/kéo dài (Trim) đầu trái hoặc đầu phải.
    public func trimmed(leftDeltaSeconds: Double, newDurationSeconds: Double) -> ClipKeyframeMap {
        guard !isEmpty else { return self }
        let safeDuration = max(0.05, newDurationSeconds)
        var newTracks: [String: [KeyframePoint]] = [:]

        for (key, pts) in tracks where !pts.isEmpty {
            var adjusted: [KeyframePoint] = []
            for pt in pts {
                let shiftedSec = pt.timeOffset.seconds - leftDeltaSeconds
                if shiftedSec >= -0.005 && shiftedSec <= safeDuration + 0.005 {
                    let clampedSec = max(0.0, min(safeDuration, shiftedSec))
                    adjusted.append(
                        KeyframePoint(
                            id: pt.id,
                            seconds: clampedSec,
                            value: pt.value,
                            interpolation: pt.interpolation
                        )
                    )
                }
            }
            if adjusted.isEmpty, let first = pts.first {
                // Giữ lại giá trị nội suy tại điểm cắt đầu clip nếu toàn bộ keyframe bị cắt khuất
                let boundaryVal = KeyframeEvaluator.evaluate(
                    propertyKey: key,
                    baseValue: first.value,
                    atLocalTime: max(0.0, leftDeltaSeconds),
                    map: self
                )
                adjusted.append(KeyframePoint(seconds: 0.0, value: boundaryVal, interpolation: first.interpolation))
            }
            newTracks[key] = adjusted
        }
        return ClipKeyframeMap(tracks: newTracks)
    }

    /// Tách bản đồ Keyframe thành 2 nửa Trái và Phải tại `splitOffsetSeconds` (tính từ đầu Clip),
    /// đồng thời tự động lấy mẫu (sample) giá trị nội suy ngay tại vết cắt để đường cong không bị gãy!
    public func split(atOffsetSeconds splitOffsetSeconds: Double) -> (left: ClipKeyframeMap, right: ClipKeyframeMap) {
        guard !isEmpty, splitOffsetSeconds > 0 else { return (self, self) }
        var leftTracks: [String: [KeyframePoint]] = [:]
        var rightTracks: [String: [KeyframePoint]] = [:]

        for (key, pts) in tracks where !pts.isEmpty {
            let boundaryVal = KeyframeEvaluator.evaluate(
                propertyKey: key,
                baseValue: pts[0].value,
                atLocalTime: splitOffsetSeconds,
                map: self
            )
            let activeInterp = pts.last(where: { $0.timeOffset.seconds <= splitOffsetSeconds })?.interpolation
                ?? pts.first?.interpolation ?? .smooth

            var leftPts = pts.filter { $0.timeOffset.seconds <= splitOffsetSeconds + 0.005 }
            if !leftPts.contains(where: { abs($0.timeOffset.seconds - splitOffsetSeconds) <= 0.02 }) {
                leftPts.append(KeyframePoint(seconds: splitOffsetSeconds, value: boundaryVal, interpolation: activeInterp))
            }

            var rightPts: [KeyframePoint] = []
            for pt in pts where pt.timeOffset.seconds >= splitOffsetSeconds - 0.005 {
                let shiftedSec = max(0.0, pt.timeOffset.seconds - splitOffsetSeconds)
                rightPts.append(
                    KeyframePoint(
                        id: UUID(),
                        seconds: shiftedSec,
                        value: pt.value,
                        interpolation: pt.interpolation
                    )
                )
            }
            if !rightPts.contains(where: { $0.timeOffset.seconds <= 0.02 }) {
                rightPts.insert(KeyframePoint(seconds: 0.0, value: boundaryVal, interpolation: activeInterp), at: 0)
            }

            leftTracks[key] = leftPts
            rightTracks[key] = rightPts
        }

        return (ClipKeyframeMap(tracks: leftTracks), ClipKeyframeMap(tracks: rightTracks))
    }
}

