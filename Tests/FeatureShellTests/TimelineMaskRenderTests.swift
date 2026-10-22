import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreGraphics
import CoreImage
import AppKit
import AVKit
@testable import Domain
@testable import FeatureShell

@Suite("TimelineMaskRenderTests")
@MainActor
struct TimelineMaskRenderTests {
    @Test("TimelineMaskParameters extracts properties accurately with robust defaults")
    func testMaskParametersExtraction() {
        let emptyProps: [String: PropertyValue] = [:]
        let defaultParams = TimelineMaskParameters.extract(from: emptyProps)
        #expect(defaultParams.shape == .none)
        #expect(!defaultParams.isMaskActive)
        #expect(!defaultParams.invert)
        #expect(defaultParams.feather == 0.0)

        let customProps: [String: PropertyValue] = [
            "maskType": .string("circle"),
            "maskInvert": .bool(true),
            "maskFeather": .number(25.0),
            "maskPositionX": .number(50.0),
            "maskPositionY": .number(-30.0),
            "maskRotation": .number(45.0),
            "maskRadiusX": .number(180.0),
            "maskRadiusY": .number(120.0)
        ]
        let circleParams = TimelineMaskParameters.extract(from: customProps)
        #expect(circleParams.shape == .circle)
        #expect(circleParams.isMaskActive)
        #expect(circleParams.invert)
        #expect(circleParams.feather == 0.25)
        #expect(circleParams.positionX == 50.0)
        #expect(circleParams.positionY == -30.0)
        #expect(circleParams.rotation == 45.0)
        #expect(circleParams.radiusX == 180.0)
        #expect(circleParams.radiusY == 120.0)
    }

    @Test("TimelineMaskGenerator generates valid CIImages for every mask shape")
    func testTimelineMaskGeneratorProducesValidCIImageForEveryShape() {
        let canvas = CGSize(width: 1920, height: 1080)

        // 1. None
        let noneParams = TimelineMaskParameters(shape: .none)
        #expect(TimelineMaskGenerator.generateMask(for: noneParams, canvasSize: canvas) == nil)

        // 2. Split
        let splitParams = TimelineMaskParameters(shape: .split, invert: false, feather: 10.0, rotation: 30.0)
        let splitMask = TimelineMaskGenerator.generateMask(for: splitParams, canvasSize: canvas)
        #expect(splitMask != nil)
        #expect(splitMask?.extent.width == 1920.0)
        #expect(splitMask?.extent.height == 1080.0)

        // 3. Circle
        let circleParams = TimelineMaskParameters(shape: .circle, invert: true, feather: 15.0, radiusX: 250.0, radiusY: 180.0)
        let circleMask = TimelineMaskGenerator.generateMask(for: circleParams, canvasSize: canvas)
        #expect(circleMask != nil)
        #expect(circleMask?.extent.width == 1920.0)
        #expect(circleMask?.extent.height == 1080.0)

        // 4. Rectangle
        let rectParams = TimelineMaskParameters(shape: .rectangle, width: 600.0, height: 400.0, cornerRadius: 40.0)
        let rectMask = TimelineMaskGenerator.generateMask(for: rectParams, canvasSize: canvas)
        #expect(rectMask != nil)
        #expect(rectMask?.extent.width == 1920.0)
        #expect(rectMask?.extent.height == 1080.0)

        // 5. Filmstrip
        let filmParams = TimelineMaskParameters(shape: .filmstrip, offsetY: 20.0, filmHeight: 600.0)
        let filmMask = TimelineMaskGenerator.generateMask(for: filmParams, canvasSize: canvas)
        #expect(filmMask != nil)
        #expect(filmMask?.extent.width == 1920.0)
        #expect(filmMask?.extent.height == 1080.0)
    }

    @Test("TimelineMaskGenerator applyMask blends frame without modifying extent")
    func testTimelineMaskGeneratorApplyMask() {
        let canvas = CGSize(width: 1920, height: 1080)
        let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(origin: .zero, size: canvas))
        let rectParams = TimelineMaskParameters(shape: .rectangle, width: 400.0, height: 300.0)

        let maskedImage = TimelineMaskGenerator.applyMask(to: testImage, params: rectParams, canvasSize: canvas)
        #expect(maskedImage.extent.width == 1920.0)
        #expect(maskedImage.extent.height == 1080.0)
    }

    @Test("Split mask feather only fades across the split axis and preserves 100% white on outer edges")
    func testSplitFeatherDoesNotFadeOuterEdges() {
        let canvas = CGSize(width: 1920, height: 1080)
        let splitParams = TimelineMaskParameters(shape: .split, invert: false, feather: 50.0, rotation: 0.0)
        guard let mask = TimelineMaskGenerator.generateMask(for: splitParams, canvasSize: canvas) else {
            Issue.record("Failed to generate split mask")
            return
        }
        let rep = NSCIImageRep(ciImage: mask)
        let nsImage = NSImage(size: canvas)
        nsImage.addRepresentation(rep)
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            Issue.record("Failed to read split mask pixels")
            return
        }
        let bpp = cgImage.bitsPerPixel / 8
        let bpr = cgImage.bytesPerRow

        func isWhite(x: Int, y: Int) -> Bool {
            let offset = y * bpr + x * bpp
            return ptr[offset] > 250 && ptr[offset + 1] > 250 && ptr[offset + 2] > 250
        }

        #expect(isWhite(x: 1800, y: 540), "Right side should be solid white")
        #expect(isWhite(x: 1800, y: 1070), "Top right edge should be solid white")
        #expect(isWhite(x: 1800, y: 10), "Bottom right edge should be solid white")
        #expect(isWhite(x: 1910, y: 540), "Far right border should be solid white")
        #expect(isWhite(x: 1910, y: 1070), "Top right corner should be solid white")
        #expect(isWhite(x: 1910, y: 10), "Bottom right corner should be solid white")

        // Also test high feather value (200.0) as shown in user screenshot
        let highFeatherParams = TimelineMaskParameters(shape: .split, invert: false, feather: 200.0, rotation: 0.0)
        guard let highMask = TimelineMaskGenerator.generateMask(for: highFeatherParams, canvasSize: canvas) else {
            Issue.record("Failed to generate high feather split mask")
            return
        }
        let highRep = NSCIImageRep(ciImage: highMask)
        let highNSImage = NSImage(size: canvas)
        highNSImage.addRepresentation(highRep)
        guard let highCGImage = highNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let highData = highCGImage.dataProvider?.data,
              let highPtr = CFDataGetBytePtr(highData) else {
            Issue.record("Failed to read high feather mask pixels")
            return
        }
        let highBpp = highCGImage.bitsPerPixel / 8
        let highBpr = highCGImage.bytesPerRow
        func isHighWhite(x: Int, y: Int) -> Bool {
            let offset = y * highBpr + x * highBpp
            return highPtr[offset] > 250 && highPtr[offset + 1] > 250 && highPtr[offset + 2] > 250
        }
        #expect(isHighWhite(x: 1600, y: 1070), "Top edge at x=1600 should be solid white even with 200% feather")
        #expect(isHighWhite(x: 1600, y: 10), "Bottom edge at x=1600 should be solid white even with 200% feather")
        #expect(isHighWhite(x: 1910, y: 540), "Far right edge should be solid white even with 200% feather")
        #expect(isHighWhite(x: 1910, y: 1070), "Top right corner should be solid white even with 200% feather")
    }

    @Test("Split mask rotates clockwise matching on-screen overlay orientation")
    func testSplitMaskClockwiseRotationOrientation() {
        let canvas = CGSize(width: 1920, height: 1080)
        // 90° clockwise rotation turns vertical split into horizontal split (bottom visible, top masked)
        let split90 = TimelineMaskParameters(shape: .split, invert: false, feather: 0.0, rotation: 90.0)
        guard let mask = TimelineMaskGenerator.generateMask(for: split90, canvasSize: canvas) else {
            Issue.record("Failed to generate rotated split mask")
            return
        }
        let ciCtx = CIContext()
        var botPixel = [UInt8](repeating: 0, count: 4)
        var topPixel = [UInt8](repeating: 0, count: 4)
        ciCtx.render(mask, toBitmap: &botPixel, rowBytes: 4, bounds: CGRect(x: 960, y: 200, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        ciCtx.render(mask, toBitmap: &topPixel, rowBytes: 4, bounds: CGRect(x: 960, y: 900, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let botIsWhite = botPixel[0] > 250
        let topIsBlack = topPixel[0] < 5
        #expect(botIsWhite, "Bottom half (y=200 in CI coords) should be visible when rotated 90° clockwise")
        #expect(topIsBlack, "Top half (y=900 in CI coords) should be masked out when rotated 90° clockwise")
    }

    @Test("Filmstrip mask ignores legacy rotation and horizontal position when switching from split")
    func testFilmstripMaskIgnoresLegacyRotationAndPosition() {
        let legacyProps: [String: PropertyValue] = [
            "maskType": .string("filmstrip"),
            "maskRotation": .number(43.14),
            "maskPositionX": .number(8.0),
            "maskPositionY": .number(0.0),
            "maskOffsetY": .number(0.0),
            "maskFilmHeight": .number(500.0),
            "maskFeather": .number(0.0)
        ]
        let params = TimelineMaskParameters.extract(from: legacyProps)
        #expect(params.shape == .filmstrip)
        #expect(params.rotation == 0.0)
        #expect(params.positionX == 0.0)
        #expect(params.positionY == 0.0)
        #expect(params.offsetY == 0.0)
        #expect(params.filmHeight == 500.0)

        let canvas = CGSize(width: 1920, height: 1080)
        guard let mask = TimelineMaskGenerator.generateMask(for: params, canvasSize: canvas) else {
            Issue.record("Failed to generate filmstrip mask")
            return
        }
        let ciCtx = CIContext()
        var centerPixel = [UInt8](repeating: 0, count: 4)
        var leftPixel = [UInt8](repeating: 0, count: 4)
        var rightPixel = [UInt8](repeating: 0, count: 4)
        var topPixel = [UInt8](repeating: 0, count: 4)

        // Across Y = 540 (middle of filmstrip): should be solid white across all X (left, center, right)
        ciCtx.render(mask, toBitmap: &centerPixel, rowBytes: 4, bounds: CGRect(x: 960, y: 540, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        ciCtx.render(mask, toBitmap: &leftPixel, rowBytes: 4, bounds: CGRect(x: 100, y: 540, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        ciCtx.render(mask, toBitmap: &rightPixel, rowBytes: 4, bounds: CGRect(x: 1800, y: 540, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        // Outside filmstrip at top Y = 900: should be black
        ciCtx.render(mask, toBitmap: &topPixel, rowBytes: 4, bounds: CGRect(x: 960, y: 900, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        #expect(centerPixel[0] > 250, "Center of filmstrip should be white")
        #expect(leftPixel[0] > 250, "Left side of filmstrip should be horizontal and white")
        #expect(rightPixel[0] > 250, "Right side of filmstrip should be horizontal and white")
        #expect(topPixel[0] < 5, "Above filmstrip should be black")
    }

    @Test("Mask feather backward compatibility: handles both 0.0...1.0 and legacy 0...100")
    func testMaskFeatherBackwardCompatibility() {
        let normalizedProps: [String: PropertyValue] = [
            "maskType": .string("split"),
            "maskFeather": .number(0.42)
        ]
        let p1 = TimelineMaskParameters.extract(from: normalizedProps)
        #expect(abs(p1.feather - 0.42) < 0.001)

        let legacyProps: [String: PropertyValue] = [
            "maskType": .string("split"),
            "maskFeather": .number(42.0)
        ]
        let p2 = TimelineMaskParameters.extract(from: legacyProps)
        #expect(abs(p2.feather - 0.42) < 0.001)
    }
}

