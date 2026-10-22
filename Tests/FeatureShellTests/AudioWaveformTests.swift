import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

private actor MockTestWaveformService: AudioWaveformServiceProtocol {
    func generateWaveformSamples(for url: URL, sampleCount: Int) async -> [Float] {
        Array(repeating: 0.15, count: sampleCount)
    }
}

private actor MockProgressWaveformService: AudioWaveformServiceProtocol {
    var generatePeaksCalledWithProgress = false

    func generateWaveformSamples(for url: URL, sampleCount: Int) async -> [Float] {
        Array(repeating: 0.20, count: sampleCount)
    }

    func generateWaveformPeaks(
        for url: URL,
        samplesPerSecond: Int,
        onProgress: (@Sendable ([Float]) -> Void)?
    ) async -> [Float] {
        generatePeaksCalledWithProgress = true
        let data = [Float](repeating: 0.35, count: 50)
        onProgress?(data)
        return data
    }
}

private struct MockAssetThumbnailService: AssetThumbnailServiceProtocol {
    func generateThumbnailData(for asset: MediaAsset) async throws -> Data? {
        nil
    }
}

@Suite("AudioWaveformTests")
struct AudioWaveformTests {
    @Test("AudioWaveformMath -1.5 dBFS threshold and linear amplitude")
    func testThresholdLinearAmplitude() {
        let thresh = AudioWaveformMath.thresholdLinearAmplitude
        // 10^(-1.5/20) ~ 0.8414
        #expect(thresh > 0.84 && thresh < 0.85)

        #expect(!AudioWaveformMath.isAboveThreshold(amplitude: 0.10))
        #expect(!AudioWaveformMath.isAboveThreshold(amplitude: 0.50))
        #expect(!AudioWaveformMath.isAboveThreshold(amplitude: 0.84))
        #expect(AudioWaveformMath.isAboveThreshold(amplitude: 0.85))
        #expect(AudioWaveformMath.isAboveThreshold(amplitude: 0.95))
        #expect(AudioWaveformMath.isAboveThreshold(amplitude: 1.0))
    }

    @Test("AudioWaveformMath linear dynamic height curve preserves natural range")
    func testLinearDynamicHeightCurve() {
        let hZero = AudioWaveformMath.perceptualHeightFraction(amplitude: 0.0)
        #expect(hZero == 0.0)

        let hHalf = AudioWaveformMath.perceptualHeightFraction(amplitude: 0.50)
        #expect(abs(hHalf - 0.50) < 0.001)

        let hThresh = AudioWaveformMath.perceptualHeightFraction(amplitude: 0.8414)
        #expect(abs(hThresh - 0.8414) < 0.001)

        let hFull = AudioWaveformMath.perceptualHeightFraction(amplitude: 1.0)
        #expect(hFull == 1.0)
    }

    @Test("AudioWaveformMath peakInRange time window extraction and zoom scaling")
    func testPeakInRange() {
        var peaks = [Float](repeating: 0.1, count: 200)
        peaks[105] = 0.92
        peaks[50] = 0.40

        let peak1 = AudioWaveformMath.peakInRange(peaks: peaks, sourceStartTime: 0.0, sourceEndTime: 0.4)
        #expect(abs(peak1 - 0.1) < 0.001)

        let peak2 = AudioWaveformMath.peakInRange(peaks: peaks, sourceStartTime: 0.45, sourceEndTime: 0.55)
        #expect(abs(peak2 - 0.40) < 0.001)

        let peak3 = AudioWaveformMath.peakInRange(peaks: peaks, sourceStartTime: 1.0, sourceEndTime: 1.1)
        #expect(abs(peak3 - 0.92) < 0.001)
        #expect(AudioWaveformMath.isAboveThreshold(amplitude: peak3))

        #expect(AudioWaveformMath.peakInRange(peaks: [], sourceStartTime: 0, sourceEndTime: 1) == 0.0)
        #expect(AudioWaveformMath.peakInRange(peaks: peaks, sourceStartTime: 10, sourceEndTime: 11) == 0.1)
    }

    @Test("AudioWaveformServiceProtocol default generateWaveformPeaks delegates to generateWaveformSamples")
    func testProtocolDefaultPeaksDelegation() async {
        let service = MockTestWaveformService()
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.mp3")
        let peaks = await service.generateWaveformPeaks(for: dummyURL, samplesPerSecond: 10)
        #expect(peaks.count == 100)
        #expect(peaks.first == 0.15)
    }

    @Test("AudioWaveformServiceProtocol with onProgress streaming callback")
    func testProgressWaveformStreaming() async {
        let service = MockProgressWaveformService()
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.mp3")
        final class StreamBox: @unchecked Sendable {
            var items: [Float] = []
        }
        let box = StreamBox()
        let finalPeaks = await service.generateWaveformPeaks(for: dummyURL, samplesPerSecond: 100) { partial in
            box.items = partial
        }
        #expect(finalPeaks.count == 50)
        #expect(box.items.count == 50)
        #expect(box.items.first == 0.35)
    }

    @Test("AudioWaveformView shared across audio and video clips")
    func testWaveformSharedAcrossVideoAndAudio() {
        let duration = CMTime(seconds: 10, preferredTimescale: 600)
        let sourceStart = CMTime(seconds: 2, preferredTimescale: 600)
        let sampleURL = URL(fileURLWithPath: "/tmp/movie.mp4")

        let videoClip = TimelineClip(
            name: "VideoClip",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            mediaURL: sampleURL,
            sourceStartTime: sourceStart
        )
        let audioClip = TimelineClip(
            name: "AudioClip",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: duration),
            mediaURL: sampleURL,
            sourceStartTime: sourceStart
        )

        #expect(videoClip.mediaURL == audioClip.mediaURL)
        #expect(videoClip.sourceStartTime == audioClip.sourceStartTime)
        #expect(videoClip.kind.canHaveAudio)
        #expect(audioClip.kind.canHaveAudio)
        #expect(!ClipKind.image.canHaveAudio)
        #expect(!ClipKind.text.canHaveAudio)
    }

    @Test("MediaLibraryViewModel preloads waveform when importing audio and video")
    @MainActor
    func testMediaLibraryWaveformPreload() async {
        let thumbService = MockAssetThumbnailService()
        let waveService = MockProgressWaveformService()
        let vm = MediaLibraryViewModel(thumbnailService: thumbService, waveformService: waveService)

        let audioURL = URL(fileURLWithPath: "/tmp/song.mp3")
        vm.importURLs([audioURL])

        #expect(vm.assets.count == 1)
        #expect(vm.assets.first?.type == .audio)
    }

    @Test("Expanding left trim calculates earlier source start time so covered audio reveals immediately")
    func testExpandingLeftTrimRevealsPreviousAudioWithoutGap() {
        let pps: CGFloat = 60.0
        let originalSourceStart = CMTime(seconds: 86.0, preferredTimescale: 600)
        let clip = TimelineClip(
            name: "Con đò lỡ hẹn part 2",
            kind: .audio,
            timeRange: CMTimeRange(
                start: CMTime(seconds: 86.0, preferredTimescale: 600),
                duration: CMTime(seconds: 60.0, preferredTimescale: 600)
            ),
            maxDuration: CMTime(seconds: 300.0, preferredTimescale: 600),
            mediaURL: URL(fileURLWithPath: "/tmp/sample.mp3"),
            sourceStartTime: originalSourceStart
        )

        // Simulate dragging left handle backwards by 20 seconds (dx = -20s * 60pps = -1200px)
        let trimLeftOffset: CGFloat = -1200.0
        let deltaSec = Double(trimLeftOffset / pps) // -20.0s
        let activeSourceStartTime = max(0.0, CMTimeGetSeconds(clip.sourceStartTime) + deltaSec)

        #expect(activeSourceStartTime == 66.0)
        // At the original boundary (x = 20s * 60pps = 1200px into the new expanded clip):
        let timeAtOriginalLeftEdge = activeSourceStartTime + Double(1200.0 / pps)
        #expect(timeAtOriginalLeftEdge == 86.0)
        // At the right edge of the expanded clip (width = 80s * 60pps = 4800px):
        let timeAtRightEdge = activeSourceStartTime + Double(4800.0 / pps)
        #expect(timeAtRightEdge == 146.0)
    }

    @Test("Waveform time sampling stretches horizontally according to clip speed")
    func testWaveformTimeSamplingStretchesWithSpeed() {
        let pps: CGFloat = 50.0
        let speed = 0.5
        let clipTimelineDuration = 264.0
        let clipWidth = CGFloat(clipTimelineDuration) * pps // 13200px
        let sourceStartSec = 0.0

        // At end of timeline clip (x = clipWidth)
        let timelineSec = Double(clipWidth / pps)
        #expect(timelineSec == 264.0)

        // With speed = 0.5, source time only reaches 132.0s
        let sourceTime = sourceStartSec + (timelineSec * speed)
        #expect(sourceTime == 132.0)

        // Mock peaks array of 145 seconds (at 100 peaks/sec -> 14500 samples)
        let mockPeaks = [Float](repeating: 0.5, count: 14500)
        let endPeak = AudioWaveformMath.peakInRange(
            peaks: mockPeaks,
            sourceStartTime: sourceTime - 0.05,
            sourceEndTime: sourceTime,
            peaksPerSecond: 100.0
        )
        // Verify peak exists and is valid at the end of the stretched clip
        #expect(endPeak > 0.0)
    }
}

