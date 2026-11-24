import Foundation
import CoreGraphics
import CoreImage
import AppKit
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("Text Preview Sharpness & 60fps Pixelation Regression")
struct TextPreviewSharpnessRegressionTests {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false, .highQualityDownsample: true])
    private let canvasSize = CGSize(width: 1280, height: 720)

    @Test("Scaled-up text uses supersampled GPU glyph atlas rather than stretching a blurry 1x bitmap")
    func testUpscaledTextDoesNotPixelate() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        var cfg = TextConfiguration(
            content: "T",
            fontName: "Helvetica",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
        cfg.scale = 6.0

        guard let img = engine.renderImage(for: cfg, canvasSize: canvasSize) else {
            Issue.record("Expected rendered image")
            return
        }

        let bytes = renderRGBABytes(img, size: canvasSize)
        let w = Int(canvasSize.width)
        let h = Int(canvasSize.height)
        let midX = w / 2

        var transitionPixels = 0
        for y in (h / 3)..<(2 * h / 3) {
            let alpha = bytes[(y * w + midX) * 4 + 3]
            if alpha > 8 && alpha < 247 {
                transitionPixels += 1
            }
        }
        #expect(transitionPixels <= 6, "Expected crisp vector edge (<= 6 semi-transparent pixels across edges), got \(transitionPixels)")
    }

    @Test("Auto-fitted 8x scaled text keeps full GPU atlas resolution without pixelation")
    func testAutoFitLargeScaleStaysSharp() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        var cfg = TextConfiguration(
            content: "T",
            fontName: "Helvetica",
            fontSize: 24.0,
            textColorHex: "#FFFFFF",
            isBold: true
        )
        cfg.scale = 8.0

        guard let img = engine.renderImage(for: cfg, canvasSize: canvasSize) else {
            Issue.record("Expected 8x scaled rendered image")
            return
        }
        let bytes = renderRGBABytes(img, size: canvasSize)
        let w = Int(canvasSize.width)
        let h = Int(canvasSize.height)
        let midX = w / 2
        var transitionPixels = 0
        for y in (h / 3)..<(2 * h / 3) {
            let alpha = bytes[(y * w + midX) * 4 + 3]
            if alpha > 8 && alpha < 247 {
                transitionPixels += 1
            }
        }
        #expect(transitionPixels <= 6, "Expected crisp 8x glyph edges (<= 6), got \(transitionPixels)")
    }

    @Test("Segmented per-character text stays sharp at 4x preview scale")
    func testSegmentedUpscaledTextStaysSharp() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        var cfg = TextConfiguration(
            content: "I I",
            fontName: "Helvetica",
            fontSize: 48.0,
            textColorHex: "#FFFFFF",
            isBold: true,
            animation: TextAnimationConfiguration(scriptId: "title_wave_float", scopeOverride: .perCharacter)
        )
        cfg.scale = 4.0

        guard let img = engine.renderAnimatedImage(for: cfg, localTime: 2.0, duration: 5.0, canvasSize: canvasSize) else {
            Issue.record("Expected segmented rendered image")
            return
        }

        let bytes = renderRGBABytes(img, size: canvasSize)
        let w = Int(canvasSize.width)
        let h = Int(canvasSize.height)
        let midY = h / 2
        var transitionPixels = 0
        for x in (w / 3)..<(2 * w / 3) {
            let alpha = bytes[(midY * w + x) * 4 + 3]
            if alpha > 8 && alpha < 247 {
                transitionPixels += 1
            }
        }
        #expect(transitionPixels <= 10, "Expected crisp segmented edges across vertical glyph bars, got \(transitionPixels)")
    }

    @Test("Default frame rate stays tuned to 60fps for crisp GPU preview headroom")
    func testDefaultFPSIs60() {
        #expect(TimeRational.defaultFPS == 60)
    }

    private func renderRGBABytes(_ image: CIImage, size: CGSize) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        ciContext.render(
            image, toBitmap: &bytes, rowBytes: w * 4,
            bounds: CGRect(origin: .zero, size: size),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return bytes
    }
}
