import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Bộ máy sinh hình ảnh thời gian thực cho video thuật toán (Procedural Render Engine).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Func <= 50 dòng) và R8.3 (Sendable).
public final class ProceduralRenderEngine: @unchecked Sendable {
    public static let shared = ProceduralRenderEngine()

    public init() {}

    public func render(
        config: ProceduralConfiguration,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize
    ) -> CIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let canvasRect = CGRect(origin: .zero, size: canvasSize)

        switch config.type {
        case .blackScreen:
            return ProceduralGenerators.renderSolid(hex: "#000000", canvasRect: canvasRect)
        case .chromaStudio:
            return ProceduralGenerators.renderSolid(hex: config.primaryColorHex, canvasRect: canvasRect)
        case .colorBars:
            return ProceduralGenerators.renderColorBars(canvasSize: canvasSize)
        case .filmCountdown:
            return ProceduralGenerators.renderFilmCountdown(localTime: localTime, duration: duration, canvasSize: canvasSize)
        case .meshAurora:
            return ProceduralGenerators.renderMeshAurora(config: config, localTime: localTime, canvasSize: canvasSize)
        case .topographicLines:
            return ProceduralGenerators.renderTopographic(config: config, localTime: localTime, canvasSize: canvasSize)
        case .retroGrid:
            return ProceduralGenerators.renderRetroGrid(config: config, localTime: localTime, canvasSize: canvasSize)
        case .filmGrain:
            return ProceduralGenerators.renderFilmGrain(config: config, localTime: localTime, canvasSize: canvasSize)
        case .floatingBokeh:
            return ProceduralGenerators.renderFloatingBokeh(config: config, localTime: localTime, canvasSize: canvasSize)
        case .lightLeaks:
            return ProceduralGenerators.renderLightLeaks(config: config, localTime: localTime, canvasSize: canvasSize)
        case .hypnoticTunnel:
            return ProceduralGenerators.renderHypnoticTunnel(config: config, localTime: localTime, canvasSize: canvasSize)
        case .matrixRain:
            return ProceduralGenerators.renderMatrixRain(config: config, localTime: localTime, canvasSize: canvasSize)
        }
    }

    public static func applyBlend(
        foreground: CIImage,
        over background: CIImage,
        blendMode: String,
        opacity: Float
    ) -> CIImage {
        var blendedFg = foreground
        let safeOpacity = CGFloat(max(0.0, min(1.0, opacity)))

        if safeOpacity < 1.0 {
            let alphaVector = CIVector(x: 0, y: 0, z: 0, w: safeOpacity)
            if let matrix = CIFilter(name: "CIColorMatrix", parameters: ["inputAVector": alphaVector, kCIInputImageKey: blendedFg]) {
                blendedFg = matrix.outputImage ?? blendedFg
            }
        }

        switch blendMode.lowercased() {
        case "screen":
            if let filter = CIFilter(name: "CIScreenBlendMode", parameters: [
                kCIInputImageKey: blendedFg,
                kCIInputBackgroundImageKey: background
            ]) {
                return filter.outputImage ?? blendedFg.composited(over: background)
            }
        case "add", "lineardodge":
            if let filter = CIFilter(name: "CIAdditionCompositing", parameters: [
                kCIInputImageKey: blendedFg,
                kCIInputBackgroundImageKey: background
            ]) {
                return filter.outputImage ?? blendedFg.composited(over: background)
            }
        case "multiply":
            if let filter = CIFilter(name: "CIMultiplyBlendMode", parameters: [
                kCIInputImageKey: blendedFg,
                kCIInputBackgroundImageKey: background
            ]) {
                return filter.outputImage ?? blendedFg.composited(over: background)
            }
        default:
            break
        }
        return blendedFg.composited(over: background)
    }

    public static func parseCIColor(hex: String, alpha: CGFloat = 1.0) -> CIColor {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        var rgbValue: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgbValue)

        let r, g, b: CGFloat
        if clean.count == 6 {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
        } else {
            r = 0.5; g = 0.5; b = 0.5
        }
        return CIColor(red: r, green: g, blue: b, alpha: alpha)
    }
}
