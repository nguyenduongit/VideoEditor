import Foundation
import CoreGraphics
import Domain

/// Động cơ thực thi Phương Trình Chuyển Động Toán Học Mở (Open Creative Animation Runtime Engine) ở 60fps.
/// Giải mã các biểu thức vật lý (`$p`, `$inv`, `$springInv`, `$bounceInv`, `$wave`, `$pulse`, `$param.<id>`)
/// để biến đổi trực tiếp ma trận 2D/3D và kênh Shader quang học cho từng ký tự / từ / khối chữ.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public enum OpenAnimationRuntimeEngine: Sendable {

    public struct Variables: Sendable {
        public var progress: Double
        public var phase: Double
        public var blend: Double
        public var anim: TextAnimationConfiguration
        public var manifest: CreativeAnimationManifest

        public init(
            progress: Double,
            phase: Double = 0.0,
            blend: Double = 1.0,
            anim: TextAnimationConfiguration,
            manifest: CreativeAnimationManifest
        ) {
            self.progress = min(1.0, max(0.0, progress))
            self.phase = phase
            self.blend = min(1.0, max(0.0, blend))
            self.anim = anim
            self.manifest = manifest
        }
    }

    /// Thực thi một `CreativeAnimationManifest` lên `TextConfiguration` và `TextTransformOverlay`
    public static func applyManifest(
        _ manifest: CreativeAnimationManifest,
        variables: Variables,
        config: inout TextConfiguration,
        overlay: inout TextTransformOverlay,
        blur: inout Double,
        pixelate: inout Double,
        rgbSplit: inout Double
    ) {
        if let expr = manifest.offsetXExpr {
            config.positionX += evaluate(expr, vars: variables)
        }
        if let expr = manifest.offsetYExpr {
            config.positionY += evaluate(expr, vars: variables)
        }
        if let expr = manifest.scaleXExpr {
            overlay.scaleX *= max(0.02, evaluate(expr, vars: variables))
        }
        if let expr = manifest.scaleYExpr {
            overlay.scaleY *= max(0.02, evaluate(expr, vars: variables))
        }
        if let expr = manifest.rotationExpr {
            config.rotation += evaluate(expr, vars: variables)
        }
        if let expr = manifest.skewXExpr {
            overlay.skewX += evaluate(expr, vars: variables)
        }
        if let expr = manifest.perspectiveXExpr {
            overlay.perspectiveX += evaluate(expr, vars: variables)
        }
        if let expr = manifest.perspectiveYExpr {
            overlay.perspectiveY += evaluate(expr, vars: variables)
        }
        if let expr = manifest.opacityExpr {
            let alpha = min(1.0, max(0.0, evaluate(expr, vars: variables)))
            config.opacity *= alpha
        }
        if let expr = manifest.blurExpr {
            let b = max(0.0, evaluate(expr, vars: variables))
            blur = max(blur, b)
            overlay.motionBlurRadius = max(overlay.motionBlurRadius, b)
        }
        if let expr = manifest.rgbSplitExpr {
            rgbSplit = max(rgbSplit, max(0.0, evaluate(expr, vars: variables)))
        }
        if let expr = manifest.pixelateExpr {
            pixelate = max(pixelate, max(0.0, evaluate(expr, vars: variables)))
        }
    }

    /// Giải mã biểu thức đại số dạng tổng các tích (`A * B + C * D - E * F`)
    public static func evaluate(_ expression: String, vars: Variables) -> Double {
        let normalized = expression.replacingOccurrences(of: " - ", with: " + -1.0 * ")
        let sumTerms = normalized.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !sumTerms.isEmpty else { return 0.0 }

        var sum = 0.0
        for term in sumTerms where !term.isEmpty {
            let factors = term.split(separator: "*").map { $0.trimmingCharacters(in: .whitespaces) }
            var product = 1.0
            for factor in factors {
                product *= resolveToken(factor, vars: vars)
            }
            sum += product
        }
        return sum
    }

    private static func resolveToken(_ token: String, vars: Variables) -> Double {
        if let literal = Double(token) { return literal }
        let p = vars.progress
        let inv = 1.0 - p

        switch token {
        case "$p": return p
        case "$inv", "$exit": return inv
        case "$exitQuad": return inv * inv
        case "$smooth": return TextAnimationCurves.smoothEase(p)
        case "$fadeFast": return min(1.0, p * 2.6)
        case "$springInv": return 1.0 - TextAnimationCurves.springOvershoot(p)
        case "$bounceInv": return 1.0 - TextAnimationCurves.bounceEaseOut(p)
        case "$jellyWave": return sin(p * .pi * 3.5) * exp(-p * 4.2)
        case "$glitchWave":
            let seed = vars.phase != 0.0 ? vars.phase : p * 18.0
            return sin(seed * 7.0) * cos(seed * 3.5)
        case "$wave": return sin(vars.phase)
        case "$cosWave": return cos(vars.phase)
        case "$pulse": return pow(sin(vars.phase), 4.0)
        case "$blend": return vars.blend
        default:
            if token.hasPrefix("$param.") {
                let paramID = String(token.dropFirst("$param.".count))
                return vars.anim.value(forParameter: paramID, in: vars.manifest)
            }
            return 0.0
        }
    }
}

