import Foundation
import Accelerate
import AVFoundation
import Domain

/// Extracts and caches 30Hz 16-band logarithmic spectral intensity profiles via Apple Accelerate `vDSP` FFT.
public final class AudioReactiveAnalysisService: AudioReactiveAnalysisServiceProtocol, @unchecked Sendable {
    private let decoder = AudioDecoderService()
    private let cache = LRUCache<String, AudioReactiveProfile>(capacity: 64)
    private let lock = NSLock()

    private let nFFT: Int = 1024
    private let log2n: vDSP_Length = 10
    private let bandCount: Int = 16
    private let targetSampleRateHz: Double = 30.0
    private let fftSetup: FFTSetup?
    private let hannWindow: [Float]
    private let bandBinRanges: [(low: Int, high: Int)]

    public init() {
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        var window = [Float](repeating: 0, count: nFFT)
        vDSP_hann_window(&window, vDSP_Length(nFFT), Int32(vDSP_HANN_NORM))
        self.hannWindow = window
        self.bandBinRanges = Self.buildLogBandRanges(bandCount: bandCount, nFFT: nFFT, audioRate: Float(AudioDecoderService.targetSampleRate))
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    public func cachedProfile(for url: URL) -> AudioReactiveProfile? {
        lock.withLock {
            cache[url.absoluteString]
        }
    }

    private func storeCachedProfile(_ profile: AudioReactiveProfile, for url: URL) {
        lock.withLock {
            cache[url.absoluteString] = profile
        }
    }

    public func extractReactiveProfile(from url: URL) async -> AudioReactiveProfile? {
        if let existing = cachedProfile(for: url) {
            return existing
        }
        let rate = AudioDecoderService.targetSampleRate
        guard let samples = await decoder.decodeToMonoFloat32(url: url, targetSampleRate: rate),
              samples.count >= nFFT else {
            return nil
        }
        let profile = computeProfile(samples: samples, sampleRate: rate)
        if let profile {
            storeCachedProfile(profile, for: url)
        }
        return profile
    }

    public func computeProfile(samples: [Float], sampleRate: Double) -> AudioReactiveProfile? {
        guard let fftSetup, samples.count >= nFFT, sampleRate > 0 else { return nil }
        let hop = max(128, Int((sampleRate / targetSampleRateHz).rounded()))
        let frameCount = max(1, (samples.count - nFFT) / hop + 1)
        let numBins = nFFT / 2 + 1

        var rawBands = [Float](repeating: 0, count: frameCount * bandCount)
        var rawRMS = [Float](repeating: 0, count: frameCount)
        var buffers = FFTScratchBuffers(nFFT: nFFT, numBins: numBins)

        for frameIdx in 0..<frameCount {
            let start = frameIdx * hop
            analyzeFrame(
                samples: samples,
                start: start,
                fftSetup: fftSetup,
                buffers: &buffers,
                outBands: &rawBands,
                bandOffset: frameIdx * bandCount,
                outRMS: &rawRMS[frameIdx]
            )
        }

        normalizeAndSmooth(bands: &rawBands, rms: &rawRMS, frameCount: frameCount)
        let duration = Double(samples.count) / sampleRate
        return AudioReactiveProfile(
            sampleRateHz: Double(sampleRate) / Double(hop),
            bandCount: bandCount,
            durationSeconds: duration,
            bandLevels: rawBands,
            rmsLevels: rawRMS
        )
    }

    private func analyzeFrame(
        samples: [Float],
        start: Int,
        fftSetup: FFTSetup,
        buffers: inout FFTScratchBuffers,
        outBands: inout [Float],
        bandOffset: Int,
        outRMS: inout Float
    ) {
        samples.withUnsafeBufferPointer { sPtr in
            guard let sBase = sPtr.baseAddress else { return }
            let framePtr = sBase.advanced(by: start)
            vDSP_rmsqv(framePtr, 1, &outRMS, vDSP_Length(nFFT))
            vDSP_vmul(framePtr, 1, hannWindow, 1, &buffers.windowed, 1, vDSP_Length(nFFT))
            computePowerSpectrum(fftSetup: fftSetup, buffers: &buffers)
        }

        for b in 0..<bandCount {
            let range = bandBinRanges[b]
            var sum: Float = 0.0
            for k in range.low...range.high {
                sum += buffers.power[k]
            }
            let avg = sum / Float(max(1, range.high - range.low + 1))
            outBands[bandOffset + b] = log1pf(sqrtf(max(0.0, avg)) * 0.85)
        }
    }

    private func computePowerSpectrum(fftSetup: FFTSetup, buffers: inout FFTScratchBuffers) {
        let half = nFFT / 2
        let numBins = half + 1
        buffers.windowed.withUnsafeBufferPointer { wPtr in
            buffers.real.withUnsafeMutableBufferPointer { rPtr in
                buffers.imag.withUnsafeMutableBufferPointer { iPtr in
                    guard let wBase = wPtr.baseAddress, let rBase = rPtr.baseAddress, let iBase = iPtr.baseAddress else { return }
                    var split = DSPSplitComplex(realp: rBase, imagp: iBase)
                    wBase.withMemoryRebound(to: DSPComplex.self, capacity: half) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(half))
                    }
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    buffers.power[0] = split.realp[0] * split.realp[0]
                    buffers.power[numBins - 1] = split.imagp[0] * split.imagp[0]
                    var sub = DSPSplitComplex(realp: split.realp.advanced(by: 1), imagp: split.imagp.advanced(by: 1))
                    vDSP_zvmags(&sub, 1, &buffers.power[1], 1, vDSP_Length(numBins - 2))
                }
            }
        }
    }

    private func normalizeAndSmooth(bands: inout [Float], rms: inout [Float], frameCount: Int) {
        let rmsPeak = max(1e-4, percentile98(rms))
        for i in rms.indices {
            rms[i] = min(1.0, max(0.0, powf(rms[i] / rmsPeak, 0.72)))
        }
        let bandPeak = max(1e-4, percentile98(bands))
        for i in bands.indices {
            bands[i] = min(1.0, max(0.0, powf(bands[i] / bandPeak, 0.82)))
        }
        guard frameCount > 1 else { return }
        for f in 1..<frameCount {
            rms[f] = rms[f] >= rms[f - 1] ? (0.72 * rms[f] + 0.28 * rms[f - 1]) : (0.38 * rms[f] + 0.62 * rms[f - 1])
            let cur = f * bandCount
            let prev = (f - 1) * bandCount
            for b in 0..<bandCount {
                let c = bands[cur + b]
                let p = bands[prev + b]
                bands[cur + b] = c >= p ? (0.75 * c + 0.25 * p) : (0.40 * c + 0.60 * p)
            }
        }
    }

    private func percentile98(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 1.0 }
        let sorted = values.sorted()
        let idx = min(sorted.count - 1, Int(Double(sorted.count) * 0.98))
        return max(1e-4, sorted[idx])
    }

    private static func buildLogBandRanges(bandCount: Int, nFFT: Int, audioRate: Float) -> [(low: Int, high: Int)] {
        let numBins = nFFT / 2 + 1
        let binHz = audioRate / Float(nFFT)
        let fMin: Float = 45.0
        let fMax: Float = min(audioRate * 0.48, 10500.0)
        return (0..<bandCount).map { b in
            let loHz = fMin * powf(fMax / fMin, Float(b) / Float(bandCount))
            let hiHz = fMin * powf(fMax / fMin, Float(b + 1) / Float(bandCount))
            let lo = max(1, min(numBins - 1, Int(floorf(loHz / binHz))))
            let hi = max(lo, min(numBins - 1, Int(ceilf(hiHz / binHz))))
            return (lo, hi)
        }
    }
}

private struct FFTScratchBuffers {
    var windowed: [Float]
    var real: [Float]
    var imag: [Float]
    var power: [Float]

    init(nFFT: Int, numBins: Int) {
        self.windowed = [Float](repeating: 0, count: nFFT)
        self.real = [Float](repeating: 0, count: nFFT / 2)
        self.imag = [Float](repeating: 0, count: nFFT / 2)
        self.power = [Float](repeating: 0, count: numBins)
    }
}
