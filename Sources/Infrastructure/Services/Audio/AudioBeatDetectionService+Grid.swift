import Foundation
import CoreMedia
import Domain

extension AudioBeatDetectionService {
    // MARK: - Step 3: Fine Comb-Filter Sweep

    func refinePeriodAndPhase(
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

    func buildIsochronousBeatGrid(
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

    func sampleNormalizedStrength(
        at time: Double,
        flux: [Float],
        maxFlux: Float,
        frameDuration: Double
    ) -> Double {
        let idx = max(0, min(flux.count - 1, Int(round((time / frameDuration) - 1.0))))
        return min(1.0, max(0.2, Double(flux[idx] / maxFlux)))
    }
}
