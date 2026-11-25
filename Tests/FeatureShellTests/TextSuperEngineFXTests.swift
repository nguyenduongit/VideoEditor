import Foundation
import CoreGraphics
import CoreImage
import AppKit
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("Text Super Engine Next-Gen GPU Shaders & Flagship Graphs")
struct TextSuperEngineFXTests {
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let canvasSize = CGSize(width: 640, height: 360)

    @Test("All Phase 3 SuperFX Metal kernels compile on GPU")
    func testSuperFXKernelsCompile() {
        let engine = MetalComputeRuntimeEngine.shared
        guard engine.isAvailable else { return }
        for kernel in BuiltInMetalShaders.textSuperFXKernelNames {
            #expect(engine.hasCompiledKernel(named: kernel), "Missing SuperFX kernel: \(kernel)")
        }
    }

    @Test("SDF PBR Bevel & Extrusion alters surface lighting and adds extruded silhouette depth")
    func testSDFBevelPBREffect() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        let plainCfg = TextConfiguration(content: "STEEL", fontSize: 88, textColorHex: "#FFFFFF", isBold: true)
        let plain = engine.renderImage(for: plainCfg, canvasSize: canvasSize)

        let bevelGraph = TextAnimationGraphLibrary.chromeBevelStudio3D
        let bevelCfg = TextConfiguration(
            content: "STEEL", fontSize: 88, textColorHex: "#FFFFFF", isBold: true,
            animation: TextAnimationConfiguration(graph: bevelGraph)
        )
        let lit = engine.renderAnimatedImage(for: bevelCfg, localTime: 1.3, duration: 5.0, canvasSize: canvasSize)

        #expect(plain != nil && lit != nil)
        if let plain, let lit {
            #expect(lit.extent.size == canvasSize)
            #expect(imageDifference(plain, lit) > 0.004)
        }
    }

    @Test("Pure-motion graphs and scripts strictly preserve custom Appearance text color")
    func testPureMotionPreservesAppearanceColor() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        var orangeCfg = TextConfiguration(content: "PURE", fontSize: 76, textColorHex: "#FF5500", isBold: true)

        for script in TextAnimationScriptRegistry.shared.scripts {
            orangeCfg.animation = TextAnimationConfiguration(scriptId: script.id)
            if let img = engine.renderAnimatedImage(for: orangeCfg, localTime: 1.5, duration: 5.0, canvasSize: canvasSize) {
                assertPreservesWarmOrangeTone(img, label: "script \(script.id)")
            }
        }
        for graph in TextAnimationGraphLibrary.allGraphs {
            orangeCfg.animation = TextAnimationConfiguration(graph: graph)
            if let img = engine.renderAnimatedImage(for: orangeCfg, localTime: 1.5, duration: 5.0, canvasSize: canvasSize) {
                assertPreservesWarmOrangeTone(img, label: "graph \(graph.id)")
            }
        }

        // Karaoke Glow must preserve original Appearance orange color without color tinting.
        var multiWordOrange = TextConfiguration(content: "TWO WORDS", fontSize: 64, textColorHex: "#FF5500", isBold: true)
        multiWordOrange.animation = TextAnimationConfiguration(scriptId: "karaoke_glow_flow")
        if let img = engine.renderAnimatedImage(for: multiWordOrange, localTime: 1.35, duration: 5.0, canvasSize: canvasSize) {
            assertPreservesWarmOrangeTone(img, label: "karaoke_glow_flow")
        }
    }

    @Test("GPU Particle Scatter, 3D Bevel Sculpt, and Audio Beat Kinetic graphs render cleanly")
    func testAllSuperGraphPresetsAndAudioBeatPulse() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }

        let engine = TextRendererEngine()
        #expect(TextAnimationGraphLibrary.allGraphs.count == 21)
        for graph in TextAnimationGraphLibrary.allGraphs {
            let cfg = TextConfiguration(
                content: "SUPER ENGINE",
                fontSize: 64,
                textColorHex: "#FFFFFF",
                animation: TextAnimationConfiguration(isBeatSyncEnabled: true, graph: graph)
            )
            let imgIntro = engine.renderAnimatedImage(for: cfg, localTime: 0.35, duration: 5.0, canvasSize: canvasSize)
            let imgLoop = engine.renderAnimatedImage(for: cfg, localTime: 2.0, duration: 5.0, canvasSize: canvasSize)
            #expect(imgIntro?.extent.size == canvasSize, "Graph \(graph.id) intro extent mismatch")
            #expect(imgLoop?.extent.size == canvasSize, "Graph \(graph.id) loop extent mismatch")
        }

        let audioCfg = TextConfiguration(
            content: "BASS DROP",
            fontSize: 68,
            textColorHex: "#FFFFFF",
            animation: TextAnimationConfiguration(isBeatSyncEnabled: true, graph: TextAnimationGraphLibrary.audioBeatKineticPulse)
        )
        let quiet = engine.renderAnimatedImage(
            for: audioCfg, localTime: 2.0, duration: 5.0, canvasSize: canvasSize,
            animationInputs: [TextAnimationChannel.audioRMS: 0.05, TextAnimationChannel.audioBass: 0.05, TextAnimationChannel.audioBeat: 0.0]
        )
        let hit = engine.renderAnimatedImage(
            for: audioCfg, localTime: 2.0, duration: 5.0, canvasSize: canvasSize,
            animationInputs: [TextAnimationChannel.audioRMS: 0.95, TextAnimationChannel.audioBass: 0.95, TextAnimationChannel.audioBeat: 1.0]
        )
        #expect(quiet != nil && hit != nil)
        if let quiet, let hit {
            #expect(imageDifference(quiet, hit) > 0.005)
        }
    }

    @Test("Metal mesh warp kernel compiles and renders bend and wave ribbon visibly while keeping colors")
    func testMetalMeshWarpKernelAndPresets() {
        let metal = MetalComputeRuntimeEngine.shared
        guard metal.isAvailable else { return }
        #expect(metal.hasCompiledKernel(named: "metal_text_mesh_warp"))

        let engine = TextRendererEngine()
        let plain = engine.renderImage(
            for: TextConfiguration(content: "WARP", fontSize: 72, textColorHex: "#FFFFFF", isBold: true),
            canvasSize: canvasSize
        )
        let waveCfg = TextConfiguration(
            content: "WARP", fontSize: 72, textColorHex: "#FFFFFF", isBold: true,
            animation: TextAnimationConfiguration(graph: TextAnimationGraphLibrary.flagMeshFlutter)
        )
        let waveImg = engine.renderAnimatedImage(for: waveCfg, localTime: 1.25, duration: 5.0, canvasSize: canvasSize)
        #expect(plain != nil && waveImg != nil)
        if let plain, let waveImg {
            #expect(waveImg.extent.size == canvasSize)
            #expect(imageDifference(plain, waveImg) > 0.003)
        }
    }

    private func imageDifference(_ a: CIImage, _ b: CIImage) -> Double {
        let rect = CGRect(origin: .zero, size: canvasSize)
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode", parameters: [
            kCIInputImageKey: a.cropped(to: rect),
            kCIInputBackgroundImageKey: b.cropped(to: rect)
        ])?.outputImage,
        let avg = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: diffFilter,
            kCIInputExtentKey: CIVector(cgRect: rect)
        ])?.outputImage else {
            return 0.0
        }
        var px = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avg, toBitmap: &px, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(px[0]) + Double(px[1]) + Double(px[2]) + Double(px[3])) / (4.0 * 255.0)
    }

    private func assertPreservesWarmOrangeTone(_ image: CIImage, label: String) {
        let w = Int(canvasSize.width), h = Int(canvasSize.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        ciContext.render(
            image, toBitmap: &bytes, rowBytes: w * 4,
            bounds: CGRect(origin: .zero, size: canvasSize),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        var solidPixels = 0
        for idx in stride(from: 0, to: bytes.count, by: 4) {
            let a = Int(bytes[idx + 3])
            guard a > 200 else { continue }
            solidPixels += 1
            let r = Int(bytes[idx]), g = Int(bytes[idx + 1]), b = Int(bytes[idx + 2])
            #expect(r >= g && g * 4 <= r * 3 && r > b + 40, "Appearance orange drifted for \(label): r=\(r), g=\(g), b=\(b), a=\(a)")
        }
        #expect(solidPixels > 20, "Expected visible opaque text pixels for \(label)")
    }
}
