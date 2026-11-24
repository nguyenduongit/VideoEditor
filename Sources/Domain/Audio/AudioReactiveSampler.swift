import Foundation

/// Combines pre-decoded audio spectrum profiles & beat markers at composition time into an `AudioReactiveFrame`.
public enum AudioReactiveSampler: Sendable {
    /// Samples audio intensity, frequency bands, and beat impulse at timeline `compTime` (or generates ambient preview wave).
    public static func sample(
        atTimelineTime compTime: Double,
        tracks: [AudioReactiveTrackSnapshot],
        bandCount: Int = 16,
        sensitivity: Double = 1.15,
        reactsToBeat: Bool = true,
        fallbackBPM: Double = 120.0
    ) -> AudioReactiveFrame {
        let count = max(8, min(36, bandCount))
        let gain = max(0.3, min(2.5, sensitivity))
        let overlapping = tracks.filter {
            $0.volume > 0.001 && compTime >= $0.timelineStart && compTime <= $0.timelineEnd
        }

        if overlapping.isEmpty {
            return ambientPreviewFrame(time: compTime, bandCount: count, gain: gain, bpm: fallbackBPM, reactsToBeat: reactsToBeat)
        }

        var mergedBands = [Double](repeating: 0.0, count: count)
        var maxOverall = 0.0
        var maxImpulse = 0.0
        var hasSpectralData = false

        for track in overlapping {
            let volGain = min(1.4, track.volume)
            let beatPulse = reactsToBeat ? recentBeatImpulse(at: compTime, beatTimes: track.beatTimesSeconds) : 0.0
            maxImpulse = max(maxImpulse, beatPulse * volGain)

            if let profile = track.profile {
                hasSpectralData = true
                let srcTime = track.sourceStart + (compTime - track.timelineStart) * track.speed
                let sampled = profile.sample(atSourceSeconds: srcTime, targetBands: count)
                maxOverall = max(maxOverall, sampled.overallLevel * volGain)
                for idx in 0..<count {
                    mergedBands[idx] = max(mergedBands[idx], sampled.bands[idx] * volGain)
                }
            } else if !track.beatTimesSeconds.isEmpty || track.detectedBPM != nil {
                hasSpectralData = true
                let synth = beatDrivenSpectrum(
                    time: compTime,
                    bandCount: count,
                    impulse: beatPulse,
                    bpm: track.detectedBPM ?? fallbackBPM
                )
                maxOverall = max(maxOverall, synth.overall * volGain)
                for idx in 0..<count {
                    mergedBands[idx] = max(mergedBands[idx], synth.bands[idx] * volGain)
                }
            }
        }

        guard hasSpectralData else {
            return ambientPreviewFrame(time: compTime, bandCount: count, gain: gain, bpm: fallbackBPM, reactsToBeat: reactsToBeat)
        }

        return finalizeFrame(
            rawBands: mergedBands,
            rawOverall: maxOverall,
            beatImpulse: maxImpulse,
            gain: gain,
            reactsToBeat: reactsToBeat,
            isSynced: true
        )
    }

    private static func recentBeatImpulse(at time: Double, beatTimes: [Double]) -> Double {
        guard !beatTimes.isEmpty else { return 0.0 }
        var best = 0.0
        for beat in beatTimes where beat <= time && (time - beat) <= 0.28 {
            let dt = time - beat
            let impulse = exp(-dt * 11.5)
            if impulse > best { best = impulse }
        }
        return best
    }

    private static func beatDrivenSpectrum(
        time: Double,
        bandCount: Int,
        impulse: Double,
        bpm: Double
    ) -> (bands: [Double], overall: Double) {
        let freq = max(40.0, min(220.0, bpm)) / 60.0
        let phase = time * freq * 2.0 * .pi
        var bands = [Double](repeating: 0.0, count: bandCount)
        for i in 0..<bandCount {
            let norm = Double(i) / Double(max(1, bandCount - 1))
            let wave = 0.25 + 0.30 * abs(sin(phase * 0.5 + norm * 3.1))
            let kickBoost = impulse * (1.0 - 0.45 * norm)
            bands[i] = min(1.0, wave + 0.65 * kickBoost)
        }
        let overall = min(1.0, 0.30 + 0.55 * impulse + 0.15 * abs(sin(phase)))
        return (bands, overall)
    }

    private static func ambientPreviewFrame(
        time: Double,
        bandCount: Int,
        gain: Double,
        bpm: Double,
        reactsToBeat: Bool
    ) -> AudioReactiveFrame {
        let freq = max(40.0, min(200.0, bpm)) / 60.0
        let angle = max(0.0, time) * freq * 2.0 * .pi
        let beat = reactsToBeat ? pow(max(0.0, sin(angle * 0.5)), 4.0) * 0.65 : 0.25
        var bands = [Double](repeating: 0.0, count: bandCount)
        for i in 0..<bandCount {
            let u = Double(i) / Double(max(1, bandCount - 1))
            let shape = 0.20 + 0.36 * (0.5 + 0.5 * sin(angle * 0.8 + u * 5.2)) * (1.0 - 0.32 * u)
            bands[i] = min(1.0, shape + 0.28 * beat * (1.0 - 0.4 * u))
        }
        return finalizeFrame(
            rawBands: bands,
            rawOverall: 0.32 + 0.35 * beat,
            beatImpulse: beat,
            gain: gain,
            reactsToBeat: reactsToBeat,
            isSynced: false
        )
    }

    private static func finalizeFrame(
        rawBands: [Double],
        rawOverall: Double,
        beatImpulse: Double,
        gain: Double,
        reactsToBeat: Bool,
        isSynced: Bool
    ) -> AudioReactiveFrame {
        let scaled = rawBands.map { value in
            let boosted = value * gain + (reactsToBeat ? beatImpulse * 0.18 : 0.0)
            return max(0.04, min(1.0, boosted))
        }
        let count = scaled.count
        let bassEnd = max(1, count / 4)
        let midEnd = max(bassEnd + 1, (count * 5) / 8)

        let bass = scaled[0..<bassEnd].reduce(0.0, +) / Double(bassEnd)
        let mid = scaled[bassEnd..<midEnd].reduce(0.0, +) / Double(max(1, midEnd - bassEnd))
        let treble = scaled[midEnd..<count].reduce(0.0, +) / Double(max(1, count - midEnd))
        let overall = max(0.05, min(1.0, rawOverall * gain))

        return AudioReactiveFrame(
            bands: scaled,
            overallLevel: overall,
            bassLevel: bass,
            midLevel: mid,
            trebleLevel: treble,
            beatImpulse: reactsToBeat ? max(0.0, min(1.0, beatImpulse)) : 0.0,
            isSyncedToAudio: isSynced
        )
    }
}
