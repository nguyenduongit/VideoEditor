import Testing
import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("GridCompositorOrientationTests")
@MainActor
struct GridCompositorOrientationTests {
    private static func coreImageTransform(
        avTransform: CGAffineTransform,
        sourceHeight: CGFloat,
        canvasHeight: CGFloat
    ) -> CGAffineTransform {
        let fSrc = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: sourceHeight)
        let fDst = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: -1.0, tx: 0.0, ty: canvasHeight)
        return fSrc.concatenating(avTransform).concatenating(fDst)
    }

    @Test("Test CVPixelBuffer and CoreImage orientation")
    func testPixelBufferOrientation() {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            100,
            100,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard let pb = pixelBuffer else { return }
        CVPixelBufferLockBaseAddress(pb, [])
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let bpr = CVPixelBufferGetBytesPerRow(pb)

        for x in 0..<100 {
            let offsetTop = 10 * bpr + x * 4
            ptr[offsetTop + 0] = 0
            ptr[offsetTop + 1] = 0
            ptr[offsetTop + 2] = 255
            ptr[offsetTop + 3] = 255

            let offsetBottom = 90 * bpr + x * 4
            ptr[offsetBottom + 0] = 255
            ptr[offsetBottom + 1] = 0
            ptr[offsetBottom + 2] = 0
            ptr[offsetBottom + 3] = 255
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        let ci = CIImage(cvPixelBuffer: pb)
        var dstBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            100,
            100,
            kCVPixelFormatType_32BGRA,
            nil,
            &dstBuffer
        )
        guard let dst = dstBuffer else { return }
        let ctx = CIContext()
        ctx.render(ci, to: dst)

        CVPixelBufferLockBaseAddress(dst, .readOnly)
        guard let dstBase = CVPixelBufferGetBaseAddress(dst) else { return }
        let dstPtr = dstBase.assumingMemoryBound(to: UInt8.self)
        let dstBpr = CVPixelBufferGetBytesPerRow(dst)

        let topRed = dstPtr[10 * dstBpr + 50 * 4 + 2]
        let topBlue = dstPtr[10 * dstBpr + 50 * 4 + 0]
        let botRed = dstPtr[90 * dstBpr + 50 * 4 + 2]
        let botBlue = dstPtr[90 * dstBpr + 50 * 4 + 0]
        CVPixelBufferUnlockBaseAddress(dst, .readOnly)

        #expect(topRed == 255, "Row 10 should be RED, but was blue=\(topBlue)")
        #expect(botBlue == 255, "Row 90 should be BLUE, but was red=\(botRed)")
    }

    @Test("Test iPhone portrait preferredTransform in CoreImage")
    func testPortraitPhoneTransform() {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 192, 108, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard let pb = pixelBuffer else { return }
        CVPixelBufferLockBaseAddress(pb, [])
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let bpr = CVPixelBufferGetBytesPerRow(pb)

        for y in 0..<108 {
            for x in 0..<192 {
                let off = y * bpr + x * 4
                if x < 20 {
                    ptr[off + 0] = 0; ptr[off + 1] = 0; ptr[off + 2] = 255; ptr[off + 3] = 255
                } else if x > 170 {
                    ptr[off + 0] = 255; ptr[off + 1] = 0; ptr[off + 2] = 0; ptr[off + 3] = 255
                } else {
                    ptr[off + 0] = 128; ptr[off + 1] = 128; ptr[off + 2] = 128; ptr[off + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 108, ty: 0)
        let naturalSize = CGSize(width: 192, height: 108)
        let canvasSize = CGSize(width: 108, height: 192)

        let clip = TimelineClip(name: "Test", kind: .video, timeRange: .zero)
        let computed = TimelineCompositionBuilder.computeTransform(
            transform: transform,
            naturalSize: naturalSize,
            clip: clip,
            canvasSize: canvasSize
        )

        let ciTransform = Self.coreImageTransform(
            avTransform: computed.transform,
            sourceHeight: naturalSize.height,
            canvasHeight: canvasSize.height
        )

        var ci = CIImage(cvPixelBuffer: pb)
        ci = ci.transformed(by: ciTransform)

        var dstBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 108, 192, kCVPixelFormatType_32BGRA, nil, &dstBuffer)
        guard let dst = dstBuffer else { return }
        let ctx = CIContext()
        ctx.render(ci, to: dst)

        CVPixelBufferLockBaseAddress(dst, .readOnly)
        guard let dstBase = CVPixelBufferGetBaseAddress(dst) else { return }
        let dstPtr = dstBase.assumingMemoryBound(to: UInt8.self)
        let dstBpr = CVPixelBufferGetBytesPerRow(dst)

        let topRed = dstPtr[10 * dstBpr + 54 * 4 + 2]
        let topBlue = dstPtr[10 * dstBpr + 54 * 4 + 0]
        let botRed = dstPtr[180 * dstBpr + 54 * 4 + 2]
        let botBlue = dstPtr[180 * dstBpr + 54 * 4 + 0]
        CVPixelBufferUnlockBaseAddress(dst, .readOnly)

        #expect(topRed == 255, "Row 10 (top) should be RED, but was blue=\(topBlue)")
        #expect(botBlue == 255, "Row 180 (bottom) should be BLUE, but was red=\(botRed)")
    }

    @Test("Test landscape identity transform in CoreImage")
    func testLandscapeIdentityTransform() {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 192, 108, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard let pb = pixelBuffer else { return }
        CVPixelBufferLockBaseAddress(pb, [])
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let bpr = CVPixelBufferGetBytesPerRow(pb)

        for y in 0..<108 {
            for x in 0..<192 {
                let off = y * bpr + x * 4
                if y < 15 {
                    ptr[off + 0] = 0; ptr[off + 1] = 0; ptr[off + 2] = 255; ptr[off + 3] = 255
                } else if y > 90 {
                    ptr[off + 0] = 255; ptr[off + 1] = 0; ptr[off + 2] = 0; ptr[off + 3] = 255
                } else {
                    ptr[off + 0] = 128; ptr[off + 1] = 128; ptr[off + 2] = 128; ptr[off + 3] = 255
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])

        let transform = CGAffineTransform.identity
        let naturalSize = CGSize(width: 192, height: 108)
        let canvasSize = CGSize(width: 192, height: 108)

        let clip = TimelineClip(name: "Test", kind: .video, timeRange: .zero)
        let computed = TimelineCompositionBuilder.computeTransform(
            transform: transform,
            naturalSize: naturalSize,
            clip: clip,
            canvasSize: canvasSize
        )

        let ciTransform = Self.coreImageTransform(
            avTransform: computed.transform,
            sourceHeight: naturalSize.height,
            canvasHeight: canvasSize.height
        )

        var ci = CIImage(cvPixelBuffer: pb)
        ci = ci.transformed(by: ciTransform)

        var dstBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 192, 108, kCVPixelFormatType_32BGRA, nil, &dstBuffer)
        guard let dst = dstBuffer else { return }
        let ctx = CIContext()
        ctx.render(ci, to: dst)

        CVPixelBufferLockBaseAddress(dst, .readOnly)
        guard let dstBase = CVPixelBufferGetBaseAddress(dst) else { return }
        let dstPtr = dstBase.assumingMemoryBound(to: UInt8.self)
        let dstBpr = CVPixelBufferGetBytesPerRow(dst)

        let topRed = dstPtr[10 * dstBpr + 96 * 4 + 2]
        let topBlue = dstPtr[10 * dstBpr + 96 * 4 + 0]
        let botRed = dstPtr[100 * dstBpr + 96 * 4 + 2]
        let botBlue = dstPtr[100 * dstBpr + 96 * 4 + 0]
        CVPixelBufferUnlockBaseAddress(dst, .readOnly)

        #expect(topRed == 255, "Row 10 (top) should be RED, but was blue=\(topBlue)")
        #expect(botBlue == 255, "Row 100 (bottom) should be BLUE, but was red=\(botRed)")
    }
}
