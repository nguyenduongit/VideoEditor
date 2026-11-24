import Foundation

/// Compact 30Hz multi-band spectral intensity profile precomputed from an audio track via Accelerate vDSP.
/// Designed for lock-free O(1) synchronous bilinear sampling inside CoreGraphics / AVVideoComposition render callbacks.
public struct AudioReactiveProfile: Codable, Sendable, Equatable {
    public let sampleRateHz: Double
    public let bandCount: Int
    public let durationSeconds: Double
    public let bandLevels: [Float]
    public let rmsLevels: [Float]

    public var frameCount: Int { rmsLevels.count }

    public init(
        sampleRateHz: Double = 30.0,
        bandCount: Int = 16,
        durationSeconds: Double,
        bandLevels: [Float],
        rmsLevels: [Float]
    ) {
        self.sampleRateHz = max(10.0, sampleRateHz)
        self.bandCount = max(4, bandCount)
        self.durationSeconds = max(0.0, durationSeconds)
        self.bandLevels = bandLevels
        self.rmsLevels = rmsLevels
    }

    /// Samples linearly interpolated spectral bands `[0...1]` and RMS level at audio source time `sourceSeconds`.
    public func sample(atSourceSeconds sourceSeconds: Double, targetBands: Int = 16) -> (bands: [Double], overallLevel: Double) {
        let outCount = max(4, targetBands)
        guard frameCount > 0, durationSeconds > 0 else {
            return (Array(repeating: 0.0, count: outCount), 0.0)
        }
        let clamped = max(0.0, min(durationSeconds, sourceSeconds))
        let fIdx = min(Double(frameCount - 1), max(0.0, clamped * sampleRateHz))
        let i0 = Int(floor(fIdx))
        let i1 = min(frameCount - 1, i0 + 1)
        let frac = Double(fIdx - Double(i0))

        let r0 = Double(rmsLevels[i0])
        let r1 = Double(rmsLevels[i1])
        let rms = max(0.0, min(1.0, r0 + (r1 - r0) * frac))

        var out = [Double](repeating: 0.0, count: outCount)
        for b in 0..<outCount {
            let srcPos = outCount > 1 ? Double(b) / Double(outCount - 1) * Double(bandCount - 1) : 0.0
            let b0 = min(bandCount - 1, Int(floor(srcPos)))
            let b1 = min(bandCount - 1, b0 + 1)
            let bFrac = srcPos - Double(b0)

            let v0 = interpolatedBand(frame: i0, b0: b0, b1: b1, frac: bFrac)
            let v1 = interpolatedBand(frame: i1, b0: b0, b1: b1, frac: bFrac)
            out[b] = max(0.0, min(1.0, v0 + (v1 - v0) * frac))
        }
        return (out, rms)
    }

    private func interpolatedBand(frame: Int, b0: Int, b1: Int, frac: Double) -> Double {
        let base = frame * bandCount
        guard base + b1 < bandLevels.count else { return 0.0 }
        let v0 = Double(bandLevels[base + b0])
        let v1 = Double(bandLevels[base + b1])
        return v0 + (v1 - v0) * frac
    }
}
