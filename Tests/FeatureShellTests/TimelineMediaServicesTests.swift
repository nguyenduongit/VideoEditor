import Foundation
import CoreMedia
import Testing
import Domain
@testable import FeatureShell

private actor MockThumbnailService: TimelineThumbnailServiceProtocol {
    var requestedTimes: [CMTime] = []

    func generateThumbnail(for url: URL, at time: CMTime, targetHeight: CGFloat) async -> Data? {
        requestedTimes.append(time)
        return Data([0x89, 0x50, 0x4E, 0x47])
    }
}

private actor MockWaveformService: AudioWaveformServiceProtocol {
    var generatedCount: Int = 0

    func generateWaveformSamples(for url: URL, sampleCount: Int) async -> [Float] {
        generatedCount = sampleCount
        return Array(repeating: 0.5, count: sampleCount)
    }
}

struct TimelineMediaServicesTests {
    @Test @MainActor func testTimelineViewModelServicesInjection() {
        let mockThumb = MockThumbnailService()
        let mockWave = MockWaveformService()

        let vm = TimelineViewModel(
            thumbnailService: mockThumb,
            waveformService: mockWave,
            initialLayers: []
        )

        #expect(vm.thumbnailService != nil)
        #expect(vm.waveformService != nil)
    }

    @Test func testMockThumbnailServiceGeneratesData() async {
        let service = MockThumbnailService()
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        let time = CMTime(seconds: 2.5, preferredTimescale: 600)

        let data = await service.generateThumbnail(for: dummyURL, at: time, targetHeight: 50.0)
        #expect(data != nil)

        let count = await service.requestedTimes.count
        #expect(count == 1)
    }

    @Test func testMockWaveformServiceGeneratesSamples() async {
        let service = MockWaveformService()
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.mp3")

        let samples = await service.generateWaveformSamples(for: dummyURL, sampleCount: 100)
        #expect(samples.count == 100)
        #expect(samples.first == 0.5)

        let genCount = await service.generatedCount
        #expect(genCount == 100)
    }

    @Test func testClipTrimmingWithSourceStartTime() {
        var clip = TimelineClip(
            name: "Video 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 60, timescale: 1)),
            maxDuration: CMTime(value: 120, timescale: 1),
            sourceStartTime: .zero
        )

        // Trim left by 10s: moves timeline start to 10s, duration to 50s, source start to 10s
        clip.trim(
            newStart: CMTime(value: 10, timescale: 1),
            newDuration: CMTime(value: 50, timescale: 1),
            newSourceStart: CMTime(value: 10, timescale: 1)
        )
        #expect(clip.timeRange.start == CMTime(value: 10, timescale: 1))
        #expect(clip.timeRange.duration == CMTime(value: 50, timescale: 1))
        #expect(clip.sourceStartTime == CMTime(value: 10, timescale: 1))

        // Trim right by 20s: duration becomes 30s, source start remains 10s
        clip.trim(
            newStart: clip.timeRange.start,
            newDuration: CMTime(value: 30, timescale: 1)
        )
        #expect(clip.timeRange.start == CMTime(value: 10, timescale: 1))
        #expect(clip.timeRange.duration == CMTime(value: 30, timescale: 1))
        #expect(clip.sourceStartTime == CMTime(value: 10, timescale: 1))
    }

    @Test @MainActor func testTimelineViewModelTrimClipWithSourceStart() {
        let vm = TimelineViewModel(initialLayers: [])
        let layer = vm.createLayer(for: .video)
        let clip = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 60, timescale: 1)),
            maxDuration: CMTime(value: 120, timescale: 1)
        )
        vm.addClip(clip, to: layer.id)

        vm.trimClip(
            clipID: clip.id,
            in: layer.id,
            newStart: CMTime(value: 5, timescale: 1),
            newDuration: CMTime(value: 40, timescale: 1),
            newSourceStart: CMTime(value: 5, timescale: 1)
        )

        #expect(vm.layers[0].clips[0].timeRange.start == CMTime(value: 5, timescale: 1))
        #expect(vm.layers[0].clips[0].timeRange.duration == CMTime(value: 40, timescale: 1))
        #expect(vm.layers[0].clips[0].sourceStartTime == CMTime(value: 5, timescale: 1))
    }
}
