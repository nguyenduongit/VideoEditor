import Testing
import Foundation
import CoreMedia
@testable import Domain
@testable import Infrastructure

@Suite("AudioBeatDetectionServiceTests")
struct AudioBeatDetectionServiceTests {

    @Test("Detects periodic 120 BPM kick drum beats with strictly uniform spacing in majorOnly mode")
    func testDetectPeriodicKickBeatsUniformGrid() {
        let service = AudioBeatDetectionService()
        let sampleRate = 22050.0
        let durationSec = 5.0
        let totalSamples = Int(durationSec * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)

        // Generate 120 BPM low-frequency kick hits at 0.5s, 1.0s, 1.5s, 2.0s, 2.5s, 3.0s, 3.5s, 4.0s, 4.5s
        // Even if we add a random syncopated transient at 1.82s, the beat grid must remain strictly uniform!
        let expectedBeats: [Double] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5]
        for beatTime in expectedBeats {
            let startIdx = Int(beatTime * sampleRate)
            let hitLength = Int(0.06 * sampleRate)
            for i in 0..<hitLength where (startIdx + i) < totalSamples {
                let t = Double(i) / sampleRate
                let env = Float(exp(-t * 35.0))
                samples[startIdx + i] += env * Float(sin(2.0 * .pi * 95.0 * t))
            }
        }

        // Add an off-beat vocal/synth note at 1.82s
        let offBeatStart = Int(1.82 * sampleRate)
        for i in 0..<Int(0.05 * sampleRate) {
            let t = Double(i) / sampleRate
            samples[offBeatStart + i] += 0.5 * Float(exp(-t * 25.0) * sin(2.0 * .pi * 440.0 * t))
        }

        let detected = service.detectBeats(samples: samples, sampleRate: sampleRate, mode: .majorOnly)
        #expect(detected.count == expectedBeats.count)
        #expect(detected.allSatisfy { $0.kind == .major })

        // Verify that every beat is aligned to the video frame grid and matches the expected 0.5s grid
        for (marker, expected) in zip(detected, expectedBeats) {
            let snapped = TimeRational.snapToFrame(time: marker.sourceTime.cmTime)
            #expect(marker.sourceTime.cmTime == snapped)
            #expect(abs(marker.sourceSeconds - expected) <= (1.0 / Double(TimeRational.defaultFPS)) + 0.005)
        }

        // Verify that the spacing between consecutive beats is uniform within 1 frame quantization (1/30s)
        let firstInterval = detected[1].sourceSeconds - detected[0].sourceSeconds
        let oneFrameSec = 1.0 / Double(TimeRational.defaultFPS) + 0.002
        for i in 1..<(detected.count - 1) {
            let interval = detected[i + 1].sourceSeconds - detected[i].sourceSeconds
            #expect(abs(interval - firstInterval) <= oneFrameSec)
        }
    }

    @Test("Detects uniform major beats and half-period minor sub-beats in allBeats mode")
    func testDetectAllBeatsModeSubdividesGridUniformly() {
        let service = AudioBeatDetectionService()
        let sampleRate = 22050.0
        let durationSec = 4.0
        let totalSamples = Int(durationSec * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)

        // Major low-freq kick every 0.6s (100 BPM): 0.6, 1.2, 1.8, 2.4, 3.0
        let majorTimes: [Double] = [0.6, 1.2, 1.8, 2.4, 3.0]
        for t0 in majorTimes {
            let startIdx = Int(t0 * sampleRate)
            let len = Int(0.06 * sampleRate)
            for i in 0..<len where (startIdx + i) < totalSamples {
                let t = Double(i) / sampleRate
                samples[startIdx + i] += Float(exp(-t * 30.0) * sin(2.0 * .pi * 90.0 * t))
            }
        }

        let majorOnly = service.detectBeats(samples: samples, sampleRate: sampleRate, mode: .majorOnly)
        let allBeats = service.detectBeats(samples: samples, sampleRate: sampleRate, mode: .allBeats)

        #expect(allBeats.count > majorOnly.count)
        #expect(allBeats.contains { $0.kind == .major })
        #expect(allBeats.contains { $0.kind == .minor })

        // Verify that consecutive markers in allBeats are frame-aligned and evenly spaced within 1 frame quantization
        let halfPeriod = allBeats[1].sourceSeconds - allBeats[0].sourceSeconds
        let oneFrameSec = 1.0 / Double(TimeRational.defaultFPS) + 0.002
        for i in 1..<(allBeats.count - 1) {
            let step = allBeats[i + 1].sourceSeconds - allBeats[i].sourceSeconds
            #expect(abs(step - halfPeriod) <= oneFrameSec)
        }
    }

    @Test("Returns empty array for silent signal")
    func testSilenceReturnsNoBeats() {
        let service = AudioBeatDetectionService()
        let silent = [Float](repeating: 0, count: 44100)
        let markers = service.detectBeats(samples: silent, sampleRate: 22050.0, mode: .allBeats)
        #expect(markers.isEmpty)
    }
}
