import Foundation
import CoreMedia
import CoreGraphics
import AVFoundation
import Testing
import Domain
@testable import FeatureShell

@Suite("ExportIntegrationTests")
@MainActor
struct ExportIntegrationTests {

    @Test func testExportResolutionEvenDimensions() {
        for aspect in CanvasAspectRatio.allCases {
            for res in ExportResolution.allCases {
                let size = res.dimensions(for: aspect)
                // Width and Height must be positive even integers for H.264 / HEVC video encoders
                #expect(Int(size.width) % 2 == 0)
                #expect(Int(size.height) % 2 == 0)
                #expect(size.width > 0)
                #expect(size.height > 0)
            }
        }
    }

    @Test func testExportResolutionDimensionValues() {
        // 16:9 Standard
        let s16x9_1080 = ExportResolution.res1080p.dimensions(for: .ratio16x9)
        #expect(s16x9_1080.width == 1920)
        #expect(s16x9_1080.height == 1080)

        let s16x9_720 = ExportResolution.res720p.dimensions(for: .ratio16x9)
        #expect(s16x9_720.width == 1280)
        #expect(s16x9_720.height == 720)

        let s16x9_4k = ExportResolution.res4k.dimensions(for: .ratio16x9)
        #expect(s16x9_4k.width == 3840)
        #expect(s16x9_4k.height == 2160)

        // 9:16 Portrait
        let s9x16_1080 = ExportResolution.res1080p.dimensions(for: .ratio9x16)
        #expect(s9x16_1080.width == 1080)
        #expect(s9x16_1080.height == 1920)

        let s9x16_720 = ExportResolution.res720p.dimensions(for: .ratio9x16)
        #expect(s9x16_720.width == 720)
        #expect(s9x16_720.height == 1280)

        let s9x16_4k = ExportResolution.res4k.dimensions(for: .ratio9x16)
        #expect(s9x16_4k.width == 2160)
        #expect(s9x16_4k.height == 3840)

        // 1:1 Square
        let s1x1_1080 = ExportResolution.res1080p.dimensions(for: .ratio1x1)
        #expect(s1x1_1080.width == 1080)
        #expect(s1x1_1080.height == 1080)
    }

    @Test func testExportViewModelDurationFormatting() {
        let vm = ExportViewModel()

        let t0 = CMTime.zero
        #expect(vm.formattedDuration(duration: t0) == "00:00")

        let t65s = CMTime(seconds: 65, preferredTimescale: 600)
        #expect(vm.formattedDuration(duration: t65s) == "01:05")

        let t3665s = CMTime(seconds: 3665, preferredTimescale: 600)
        #expect(vm.formattedDuration(duration: t3665s) == "01:01:05")
    }

    @Test func testExportViewModelEstimatedFileSize() {
        let vm = ExportViewModel()
        let t60s = CMTime(seconds: 60, preferredTimescale: 600)

        vm.resolution = .res1080p
        vm.codec = .h264
        let sizeH264 = vm.estimatedFileSize(duration: t60s)
        #expect(sizeH264.contains("MB"))

        vm.codec = .hevc
        let sizeHEVC = vm.estimatedFileSize(duration: t60s)
        #expect(sizeHEVC.contains("MB"))

        // Verify 4K 30fps H.264 for 93.53s matches actual ~301 MB output closely
        vm.resolution = .res4k
        vm.frameRate = .fps30
        vm.codec = .h264
        let t93s = CMTime(seconds: 93.5333, preferredTimescale: 600)
        let mb4K = vm.estimatedFileSizeMB(duration: t93s, aspectRatio: .ratio9x16)
        #expect(abs(mb4K - 301.1) < 2.0)
    }

    @Test func testExportViewModelStateFlow() {
        let vm = ExportViewModel()
        #expect(vm.isPresented == false)
        #expect(vm.isExporting == false)

        vm.openDialog()
        #expect(vm.isPresented == true)
        #expect(vm.status == .idle)

        vm.closeDialog()
        #expect(vm.isPresented == false)
    }

    @Test func testBuildAudioMixMutedLayer() {
        let layerID = UUID()
        let clip = TimelineClip(
            id: UUID(),
            name: "Audio Clip",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)),
            sourceStartTime: .zero
        )
        var layer = TimelineLayer(id: layerID, name: "Audio Track", kind: .audio, clips: [clip])
        layer.isMuted = true

        let audioTrackID: CMPersistentTrackID = 101
        let audioMix = TimelineCompositionBuilder.buildAudioMix(
            for: [layer],
            layerAudioTrackIDs: [layerID: [audioTrackID]]
        )

        #expect(audioMix.inputParameters.count == 1)
        #expect(audioMix.inputParameters.first?.trackID == audioTrackID)
    }

    @Test func testActualExportSessionSuccess() async throws {
        let videoURL = URL(fileURLWithPath: "/Users/nguyenquocduong/Library/Mobile Documents/com~apple~CloudDocs/Chim/IMG_5660.MOV")
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            return
        }

        let asset = AVURLAsset(url: videoURL)
        guard let dur = try? await asset.load(.duration) else {
            return
        }

        let clip = TimelineClip(
            id: UUID(),
            name: "IMG_5660.MOV",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1)),
            maxDuration: dur,
            mediaURL: videoURL
        )

        let adjClip = TimelineClip(
            id: UUID(),
            name: "Mặc định",
            kind: .adjustment,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 2, timescale: 1))
        )

        let videoLayer = TimelineLayer(id: UUID(), name: "Video", kind: .video, clips: [clip])
        let adjLayer = TimelineLayer(id: UUID(), name: "Adj", kind: .adjustment, clips: [adjClip])

        let layers = [videoLayer, adjLayer]
        let aspectRatio = CanvasAspectRatio.ratio9x16
        let totalDuration = CMTime(value: 2, timescale: 1)
        let config = ExportConfiguration(resolution: .res1080p, frameRate: .fps30, codec: .h264)
        let outputURL = URL(fileURLWithPath: "/tmp/test_export_916.mp4")

        let engine = ProjectExportEngine()
        var reportedProgress: [Double] = []

        try await engine.export(
            layers: layers,
            aspectRatio: aspectRatio,
            totalDuration: totalDuration,
            config: config,
            outputURL: outputURL
        ) { progress in
            reportedProgress.append(progress)
        }

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(reportedProgress.contains(1.0))
        try? FileManager.default.removeItem(at: outputURL)
    }
}
