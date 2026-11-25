import Foundation
import CoreGraphics
import CoreImage
import AppKit
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("Text GPU Glyph & SDF Atlas Pipeline")
struct TextGPUGlyphAtlasTests {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let canvasSize = CGSize(width: 640, height: 360)

    @Test("Glyph & SDF JFA Metal kernels compile cleanly")
    func testSDFKernelsCompile() {
        let engine = MetalComputeRuntimeEngine.shared
        guard engine.isAvailable else { return }
        for kernel in BuiltInMetalShaders.textSDFKernelNames {
            #expect(engine.hasCompiledKernel(named: kernel), "Missing kernel: \(kernel)")
        }
    }

    @Test("Glyph atlas caches entry across multiple animation timestamps without reallocating")
    func testAtlasCacheReuseAcrossFrames() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        let config = TextConfiguration(
            content: "NOVA",
            fontSize: 72,
            textColorHex: "#FFFFFF",
            animation: TextAnimationConfiguration(scriptId: "title_wave_float", scopeOverride: .perCharacter)
        )

        #expect(engine.glyphAtlasCache.cachedCount == 0)
        let f1 = engine.renderAnimatedImage(for: config, localTime: 1.1, duration: 5.0, canvasSize: canvasSize)
        #expect(f1 != nil)
        let countAfterFirstFrame = engine.glyphAtlasCache.cachedCount
        #expect(countAfterFirstFrame == 4)

        for t in [1.3, 1.5, 1.7, 1.9, 2.2] {
            let img = engine.renderAnimatedImage(for: config, localTime: t, duration: 5.0, canvasSize: canvasSize)
            #expect(img != nil)
        }
        #expect(engine.glyphAtlasCache.cachedCount == countAfterFirstFrame)
    }

    @Test("JFA Signed Distance Field encodes interior negative distance, exterior positive distance, and normals")
    func testSignedDistanceFieldEncoding() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let cache = TextGlyphAtlasCache()
        let config = TextConfiguration(content: "I", fontSize: 110, textColorHex: "#FFFFFF", isBold: true)
        let font = NSFont.boldSystemFont(ofSize: 110)
        guard let entry = cache.entry(forText: "I", font: font, config: config) else {
            Issue.record("Expected TextGlyphAtlasCache to build entry")
            return
        }

        let w = entry.sdfTexture.width
        let h = entry.sdfTexture.height
        guard let sdfCI = CIImage(mtlTexture: entry.sdfTexture, options: [.colorSpace: NSNull()]) else {
            Issue.record("Unable to wrap sdfTexture in CIImage")
            return
        }

        var floats = [Float](repeating: 0.0, count: w * h * 4)
        ciContext.render(
            sdfCI,
            toBitmap: &floats,
            rowBytes: w * 4 * MemoryLayout<Float>.stride,
            bounds: CGRect(x: 0, y: 0, width: w, height: h),
            format: .RGBAf,
            colorSpace: nil
        )

        var minInteriorDist = Float.greatestFiniteMagnitude
        var maxExteriorDist: Float = -1000.0
        var hasUnitNormal = false
        for idx in stride(from: 0, to: floats.count, by: 4) {
            let d = floats[idx]
            let nx = floats[idx + 1]
            let ny = floats[idx + 2]
            let a = floats[idx + 3]
            if a > 0.9 { minInteriorDist = min(minInteriorDist, d) }
            if a < 0.05 { maxExteriorDist = max(maxExteriorDist, d) }
            let nLen = hypot(nx, ny)
            if abs(d) < 4.0 && abs(nLen - 1.0) < 0.25 {
                hasUnitNormal = true
            }
        }
        #expect(minInteriorDist < -1.0)
        #expect(maxExteriorDist > 5.0)
        #expect(hasUnitNormal)
    }

    @Test("Batched Metal transparent effect chain executes multi-pass filters in one submission")
    func testBatchedTransparentEffectChain() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        let cfg = TextConfiguration(content: "FX", fontSize: 80, textColorHex: "#FFFFFF")
        guard let raw = engine.renderImage(for: cfg, canvasSize: canvasSize) else {
            Issue.record("Expected initial rendered image")
            return
        }

        let rect = CGRect(origin: .zero, size: canvasSize)
        let w = Float(canvasSize.width), h = Float(canvasSize.height)
        let chained = metal.dispatchTransparentEffectChain(
            passes: [
                MetalTransparentPass(
                    kernelName: "metal_text_liquid_morph",
                    uniforms: MetalEffectUniforms(time: 0.6, intensity: 0.85, width: w, height: h, p0: 8.0, p1: 1.0, p2: 0.0)
                ),
                MetalTransparentPass(
                    kernelName: "metal_text_directional_blur",
                    uniforms: MetalEffectUniforms(width: w, height: h, p0: 12.0, p1: 0.0)
                )
            ],
            on: raw,
            canvasRect: rect
        )
        #expect(chained.extent == rect)
    }
}
