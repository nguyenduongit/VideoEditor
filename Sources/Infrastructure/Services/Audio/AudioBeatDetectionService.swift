import Foundation
import Accelerate
import CoreMedia
import Domain

/// Dịch vụ phân tích nhịp âm thanh chuẩn nhạc lý (Tempo BPM & Isochronous Beat Grid Tracking)
/// sử dụng Apple Accelerate (`vDSP`).
///
/// Quy trình 3 bước chuẩn DSP âm nhạc:
/// 1. Tính đường bao khởi âm đa dải (Multi-band Onset Strength Envelope: Bass Kick + Percussive Transient).
/// 2. Ước lượng Chu kỳ nhịp chuẩn ($T_{\text{beat}} = 60 / \text{BPM}$) bằng Autocorrelation kết hợp bậc hài.
/// 3. Quét tinh Lọc lược (Fine Comb-Filter Sweep) độ phân giải 0.2ms để khóa chính xác cả Chu kỳ $T^*$
///    và Pha phách đầu $\phi^*$, tạo ra lưới nhịp đều đặn tuyệt đối theo nhạc lý.
public final class AudioBeatDetectionService: AudioBeatDetectionServiceProtocol, Sendable {
    private let decoder = AudioDecoderService()
    private let hopSize: Int = 256
    private let windowSize: Int = 512

    public init() {}

    public func detectBeats(
        url: URL,
        mode: AudioBeatDetectionMode
    ) async -> [AudioBeatMarker] {
        let sampleRate = AudioDecoderService.targetSampleRate
        guard let samples = await decoder.decodeToMonoFloat32(url: url, targetSampleRate: sampleRate),
              samples.count >= windowSize else {
            return []
        }
        return detectBeats(samples: samples, sampleRate: sampleRate, mode: mode)
    }

    public func detectBeats(
        samples: [Float],
        sampleRate: Double = 22050.0,
        mode: AudioBeatDetectionMode
    ) -> [AudioBeatMarker] {
        guard samples.count >= windowSize, sampleRate > 0 else { return [] }

        let onsetFlux = computeOnsetStrengthEnvelope(samples: samples, sampleRate: sampleRate)
        guard onsetFlux.count > 16 else { return [] }

        var maxFlux: Float = 0
        vDSP_maxv(onsetFlux, 1, &maxFlux, vDSP_Length(onsetFlux.count))
        guard maxFlux > 1e-5 else { return [] }

        let frameDuration = Double(hopSize) / sampleRate
        guard let activeBounds = findActiveTimeBounds(
            flux: onsetFlux,
            maxFlux: maxFlux,
            frameDuration: frameDuration
        ) else {
            return []
        }

        let coarsePeriod = estimateCoarseBeatPeriod(flux: onsetFlux, frameDuration: frameDuration)
        let (bestPeriod, bestPhase) = refinePeriodAndPhase(
            flux: onsetFlux,
            frameDuration: frameDuration,
            coarsePeriod: coarsePeriod
        )

        return buildIsochronousBeatGrid(
            period: bestPeriod,
            phase: bestPhase,
            activeStart: activeBounds.start,
            activeEnd: activeBounds.end,
            flux: onsetFlux,
            maxFlux: maxFlux,
            frameDuration: frameDuration,
            mode: mode
        )
    }

    // MARK: - Step 1: Multi-Band Onset Strength Envelope

    private func computeOnsetStrengthEnvelope(samples: [Float], sampleRate: Double) -> [Float] {
        let numFrames = (samples.count - windowSize) / hopSize + 1
        guard numFrames > 4 else { return [] }

        // Tách dải Bass (< 170Hz cho Kick drum) và Mid-High (Snare/Clap)
        let cutoffHz = 170.0
        let rc = 1.0 / (2.0 * Double.pi * cutoffHz)
        let dt = 1.0 / sampleRate
        let alpha = Float(dt / (rc + dt))

        var lowSamples = [Float](repeating: 0, count: samples.count)
        var highSamples = [Float](repeating: 0, count: samples.count)
        var prevLow: Float = 0

        for i in 0..<samples.count {
            let s = samples[i]
            prevLow += alpha * (s - prevLow)
            lowSamples[i] = prevLow
            highSamples[i] = s - prevLow
        }

        let lowFlux = computeLogEnergyFlux(signal: lowSamples, numFrames: numFrames)
        let highFlux = computeLogEnergyFlux(signal: highSamples, numFrames: numFrames)

        var combined = [Float](repeating: 0, count: numFrames)
        for i in 0..<numFrames {
            combined[i] = 1.35 * lowFlux[i] + 0.65 * highFlux[i]
        }
        return smoothEnvelope(combined)
    }

    private func computeLogEnergyFlux(signal: [Float], numFrames: Int) -> [Float] {
        var logEnergies = [Float](repeating: 0, count: numFrames)
        let invWindow = 1.0 / Float(windowSize)

        signal.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for f in 0..<numFrames {
                var meanSq: Float = 0
                vDSP_svesq(base + (f * hopSize), 1, &meanSq, vDSP_Length(windowSize))
                logEnergies[f] = log1pf(1000.0 * meanSq * invWindow)
            }
        }

        var flux = [Float](repeating: 0, count: numFrames)
        for f in 1..<numFrames {
            let diff = logEnergies[f] - logEnergies[f - 1]
            if diff > 0 { flux[f] = diff }
        }
        return flux
    }

    private func smoothEnvelope(_ env: [Float]) -> [Float] {
        guard env.count >= 5 else { return env }
        var out = env
        for i in 2..<(env.count - 2) {
            out[i] = 0.15 * env[i - 2] + 0.25 * env[i - 1] + 0.20 * env[i] + 0.25 * env[i + 1] + 0.15 * env[i + 2]
        }
        return out
    }

    private func findActiveTimeBounds(
        flux: [Float],
        maxFlux: Float,
        frameDuration: Double
    ) -> (start: Double, end: Double)? {
        let threshold = maxFlux * 0.04
        guard let firstIdx = flux.firstIndex(where: { $0 >= threshold }),
              let lastIdx = flux.lastIndex(where: { $0 >= threshold }),
              lastIdx >= firstIdx else {
            return nil
        }
        let startSec = max(0.0, Double(firstIdx) * frameDuration - 0.02)
        let endSec = Double(lastIdx + 2) * frameDuration
        return (startSec, endSec)
    }

    // MARK: - Step 2: Coarse Tempo Period Estimation (Autocorrelation + Harmonics)

    private func estimateCoarseBeatPeriod(flux: [Float], frameDuration: Double) -> Double {
        // Dải Tempo chuẩn: 72 BPM (0.833s) đến 160 BPM (0.375s)
        let minLag = max(4, Int(floor(0.375 / frameDuration)))
        let maxLag = min(flux.count / 2, Int(ceil(0.833 / frameDuration)))
        guard maxLag > minLag else { return 0.5 }

        var ac = [Float](repeating: 0, count: maxLag * 2 + 2)
        let n = flux.count
        flux.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for lag in minLag..<min(n, ac.count) {
                var dot: Float = 0
                let count = n - lag
                vDSP_dotpr(base, 1, base + lag, 1, &dot, vDSP_Length(count))
                ac[lag] = dot / Float(count)
            }
        }

        var bestLag = minLag
        var bestScore: Float = -1.0

        for lag in minLag...maxLag {
            let periodSec = Double(lag) * frameDuration
            // Trọng số ưu tiên vùng nhịp tự nhiên quanh 115 BPM để tránh nhân đôi/chia đôi nhịp
            let logDiff = log2(periodSec / 0.52)
            let tempoPrior = Float(exp(-0.5 * (logDiff / 0.55) * (logDiff / 0.55)))

            var harmonicSum = ac[lag]
            if lag * 2 < ac.count { harmonicSum += 0.50 * ac[lag * 2] }
            let score = harmonicSum * tempoPrior

            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }

        return Double(bestLag) * frameDuration
    }

    // MARK: - Step 3: Fine Comb-Filter Sweep for Exact Period & Phase

    private func refinePeriodAndPhase(
        flux: [Float],
        frameDuration: Double,
        coarsePeriod: Double
    ) -> (period: Double, phase: Double) {
        let minPeriod = max(0.36, coarsePeriod - 1.5 * frameDuration)
        let maxPeriod = min(0.85, coarsePeriod + 1.5 * frameDuration)
        let periodStep = 0.00025 // Độ chính xác 0.25ms tránh trôi nhịp trên bài nhạc dài
        let totalDuration = Double(flux.count - 1) * frameDuration

        var bestPeriod = coarsePeriod
        var bestPhase = 0.0
        var bestEnergy: Double = -1.0

        var candidatePeriod = minPeriod
        while candidatePeriod <= maxPeriod {
            let phaseSteps = 48
            let phaseDelta = candidatePeriod / Double(phaseSteps)

            for pIdx in 0..<phaseSteps {
                let candidatePhase = Double(pIdx) * phaseDelta
                var energySum = 0.0
                var beatCount = 0
                var t = candidatePhase

                while t < totalDuration {
                    // Bù 1 frame cho độ trễ trung tâm cửa sổ (windowSize = 2 * hopSize)
                    let fPos = (t / frameDuration) - 1.0
                    if fPos >= 0 {
                        let idx = Int(fPos)
                        if idx + 1 < flux.count {
                            let frac = Float(fPos - Double(idx))
                            let interp = flux[idx] * (1.0 - frac) + flux[idx + 1] * frac
                            energySum += Double(interp)
                            beatCount += 1
                        }
                    }
                    t += candidatePeriod
                }

                if beatCount > 0 {
                    let avgEnergy = energySum / pow(Double(beatCount), 0.85)
                    if avgEnergy > bestEnergy {
                        bestEnergy = avgEnergy
                        bestPeriod = candidatePeriod
                        bestPhase = candidatePhase
                    }
                }
            }
            candidatePeriod += periodStep
        }

        return (bestPeriod, bestPhase)
    }

    // MARK: - Step 4: Construct Isochronous Beat Grid

    private func buildIsochronousBeatGrid(
        period: Double,
        phase: Double,
        activeStart: Double,
        activeEnd: Double,
        flux: [Float],
        maxFlux: Float,
        frameDuration: Double,
        mode: AudioBeatDetectionMode
    ) -> [AudioBeatMarker] {
        guard period > 0.1 else { return [] }
        var markers: [AudioBeatMarker] = []

        var k = 0
        while true {
            let majorTime = phase + Double(k) * period
            if majorTime > activeEnd { break }

            if majorTime >= activeStart {
                let strength = sampleNormalizedStrength(
                    at: majorTime,
                    flux: flux,
                    maxFlux: maxFlux,
                    frameDuration: frameDuration
                )
                markers.append(
                    AudioBeatMarker(
                        sourceTime: CMTime(seconds: majorTime, preferredTimescale: 600),
                        kind: .major,
                        strength: strength
                    )
                )
            }

            if mode == .allBeats {
                let minorTime = majorTime + 0.5 * period
                if minorTime >= activeStart && minorTime <= activeEnd {
                    let subStrength = sampleNormalizedStrength(
                        at: minorTime,
                        flux: flux,
                        maxFlux: maxFlux,
                        frameDuration: frameDuration
                    )
                    markers.append(
                        AudioBeatMarker(
                            sourceTime: CMTime(seconds: minorTime, preferredTimescale: 600),
                            kind: .minor,
                            strength: subStrength
                        )
                    )
                }
            }
            k += 1
        }

        return markers
    }

    private func sampleNormalizedStrength(
        at time: Double,
        flux: [Float],
        maxFlux: Float,
        frameDuration: Double
    ) -> Double {
        let idx = max(0, min(flux.count - 1, Int(round((time / frameDuration) - 1.0))))
        return min(1.0, max(0.2, Double(flux[idx] / maxFlux)))
    }
}
