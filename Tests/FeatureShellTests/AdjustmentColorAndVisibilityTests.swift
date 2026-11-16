import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import CoreImage
import CoreVideo
import CoreGraphics
@testable import Domain
@testable import FeatureShell

@Suite("AdjustmentColorAndVisibilityTests")
@MainActor
struct AdjustmentColorAndVisibilityTests {
    @Test("Default Adjustment preserves Rec.709 pixel values without gamma shift")
    func testDefaultAdjustmentPreservesRec709PixelValues() throws {
        let width = 16
        let height = 16
        let extent = CGRect(x: 0, y: 0, width: width, height: height)

        let srcBuffer = try makeBGRA32Buffer(width: width, height: height, fillByte: 128)
        attachRec709ColorProfile(to: srcBuffer)
        let dstBuffer = try makeBGRA32Buffer(width: width, height: height, fillByte: 0)

        let neutralConfig = AdjustmentConfiguration()
        #expect(neutralConfig.isNeutral)

        let baseImage = CIImage(cvPixelBuffer: srcBuffer)
        let finalCanvas = baseImage.composited(over: CIImage(color: CIColor.black).cropped(to: extent))
        let ciContext = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])

        TimelineVideoCompositor.renderPreservingColorSpace(
            ciContext: ciContext,
            image: finalCanvas,
            sourcePixelBuffer: srcBuffer,
            destinationPixelBuffer: dstBuffer,
            bounds: extent
        )

        let pixel = try readFirstBGRAPixel(from: dstBuffer)
        #expect(abs(Int(pixel.b) - 128) <= 1)
        #expect(abs(Int(pixel.g) - 128) <= 1)
        #expect(abs(Int(pixel.r) - 128) <= 1)
        #expect(CVImageBufferGetColorSpace(dstBuffer)?.takeUnretainedValue().name == CGColorSpace.itur_709)
    }

    @Test("Toggling Hide on Adjustment layer keeps TimelineVideoCompositor active and updates instructions")
    func testHidingAdjustmentLayerPreservesCustomCompositorAndUpdatesInstructions() throws {
        let composition = AVMutableComposition()
        let videoTrack = try #require(
            composition.addMutableTrack(withMediaType: .video, preferredTrackID: 301)
        )
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        let videoClip = TimelineClip(name: "Video 1", kind: .video, timeRange: range)
        let adjClip = TimelineClip(name: "Default Adjustment", kind: .adjustment, timeRange: range)

        let videoLayer = TimelineLayer(name: "V1", kind: .video, clips: [videoClip])
        var adjLayer = TimelineLayer(name: "Adj 1", kind: .adjustment, clips: [adjClip])

        #expect(TimelineCompositionBuilder.hasActiveMask(in: [adjLayer, videoLayer]))
        let visibleComp = try #require(
            TimelineCompositionBuilder.buildVideoComposition(
                for: [adjLayer, videoLayer],
                composition: composition,
                layerTrackIDs: [videoLayer.id: videoTrack.trackID],
                aspectRatio: .ratio16x9,
                duration: range.duration
            )
        )
        #expect(visibleComp.customVideoCompositorClass == TimelineVideoCompositor.self)
        let visibleInst = try #require(visibleComp.instructions.first as? TimelineCustomVideoCompositionInstruction)
        #expect(visibleInst.layerInfos.contains { $0.isAdjustment })

        adjLayer.isHidden = true
        #expect(TimelineCompositionBuilder.hasActiveMask(in: [adjLayer, videoLayer]))
        let hiddenComp = try #require(
            TimelineCompositionBuilder.buildVideoComposition(
                for: [adjLayer, videoLayer],
                composition: composition,
                layerTrackIDs: [videoLayer.id: videoTrack.trackID],
                aspectRatio: .ratio16x9,
                duration: range.duration
            )
        )
        #expect(hiddenComp.customVideoCompositorClass == TimelineVideoCompositor.self)
        let hiddenInst = try #require(hiddenComp.instructions.first as? TimelineCustomVideoCompositionInstruction)
        #expect(!hiddenInst.layerInfos.contains { $0.isAdjustment })
    }

    private func makeBGRA32Buffer(width: Int, height: Int, fillByte: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary,
            &buffer
        )
        let pixelBuffer = try #require(buffer, "CVPixelBufferCreate failed with status \(status)")
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return pixelBuffer
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                ptr[offset] = fillByte
                ptr[offset + 1] = fillByte
                ptr[offset + 2] = fillByte
                ptr[offset + 3] = 255
            }
        }
        return pixelBuffer
    }

    private func attachRec709ColorProfile(to buffer: CVPixelBuffer) {
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        if let rec709Space = CGColorSpace(name: CGColorSpace.itur_709) {
            CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, rec709Space, .shouldPropagate)
        }
    }

    private func readFirstBGRAPixel(from buffer: CVPixelBuffer) throws -> (b: UInt8, g: UInt8, r: UInt8, a: UInt8) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let baseAddress = try #require(CVPixelBufferGetBaseAddress(buffer))
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        return (ptr[0], ptr[1], ptr[2], ptr[3])
    }
}
