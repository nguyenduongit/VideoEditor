import Testing
import Foundation
import AVFoundation
import CoreMedia
@testable import Domain
@testable import Infrastructure

@Suite("AudioAlignmentServiceTests")
struct AudioAlignmentServiceTests {

    @Test("Spectral flux cross-correlation detects synthetic lag accurately")
    func testSpectralFluxCrossCorrelationWithSyntheticLag() {
        let melService = MelSpectrogramService.shared
        let alignmentService = AudioAlignmentService.shared
        let sampleRate: Float = 22050.0

        // Generate distinct musical onsets with varying frequencies (0.5s, 1.3s, 2.2s, 3.5s)
        let durationSec = 7.0
        let totalSamples = Int(Float(durationSec) * sampleRate)
        var originalAudio = [Float](repeating: 0, count: totalSamples)

        let onsets: [(time: Float, freq: Float)] = [
            (0.5, 440.0), (1.3, 554.0), (2.2, 659.0), (3.5, 880.0), (4.8, 330.0)
        ]
        for onset in onsets {
            let start = Int(onset.time * sampleRate)
            let len = Int(0.12 * sampleRate)
            for i in start..<min(totalSamples, start + len) {
                let t = Float(i - start) / sampleRate
                originalAudio[i] = sin(2.0 * .pi * onset.freq * t)
            }
        }

        // Shift by 0.9 second (delayed audio)
        let lagSec = 0.9
        let lagSamples = Int(Float(lagSec) * sampleRate)
        var delayedAudio = [Float](repeating: 0, count: totalSamples)
        for i in lagSamples..<totalSamples {
            delayedAudio[i] = originalAudio[i - lagSamples]
        }

        let fluxDelayed = melService.computeNormalizedSpectralFlux(samples: delayedAudio)
        let fluxOriginal = melService.computeNormalizedSpectralFlux(samples: originalAudio)

        #expect(!fluxDelayed.isEmpty)
        #expect(!fluxOriginal.isEmpty)

        let result = alignmentService.matchSpectralFlux(flux1: fluxDelayed, flux2: fluxOriginal)
        #expect(result.isMatch == true)
        #expect(abs(result.offsetSeconds - lagSec) < 0.05)
    }

    @Test("Spectral flux handles silence and identical signals properly")
    func testIdenticalSignalsHaveZeroOffset() {
        let melService = MelSpectrogramService.shared
        let alignmentService = AudioAlignmentService.shared
        let sampleRate: Float = 22050.0

        let durationSec = 4.0
        let totalSamples = Int(Float(durationSec) * sampleRate)
        var audio = [Float](repeating: 0, count: totalSamples)

        for i in 0..<totalSamples {
            let t = Float(i) / sampleRate
            if fmod(t, 0.4) < 0.05 {
                audio[i] = sin(2.0 * .pi * 880.0 * t)
            }
        }

        let flux1 = melService.computeNormalizedSpectralFlux(samples: audio)
        let flux2 = melService.computeNormalizedSpectralFlux(samples: audio)

        let result = alignmentService.matchSpectralFlux(flux1: flux1, flux2: flux2)
        #expect(result.isMatch == true)
        #expect(abs(result.offsetSeconds) < 0.05)
    }

    @Test("Onset envelope refinement accurately refines sub-second lag")
    func testOnsetEnvelopeRefinement() {
        let alignmentService = AudioAlignmentService.shared
        let sampleRate: Float = 22050.0

        let durationSec = 15.0
        let totalSamples = Int(Float(durationSec) * sampleRate)
        var s1 = [Float](repeating: 0, count: totalSamples)

        for i in 0..<totalSamples {
            let t = Float(i) / sampleRate
            if fmod(t, 0.5) < 0.04 {
                s1[i] = sin(2.0 * .pi * 1000.0 * t)
            }
        }

        let actualLag = 1.234
        let lagSamples = Int(Float(actualLag) * sampleRate)
        var s2 = [Float](repeating: 0, count: totalSamples)
        for i in lagSamples..<totalSamples {
            s2[i] = s1[i - lagSamples]
        }

        let coarseLagEstimate = 1.25
        let refined = alignmentService.refineOnsetEnvelope(samples1: s2, samples2: s1, coarseOffset: coarseLagEstimate)

        #expect(abs(refined - actualLag) < 0.02)
    }
}
