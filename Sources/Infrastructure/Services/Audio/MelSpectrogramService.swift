import Foundation
import Accelerate

/// Computes Mel-Spectrogram and Normalized Spectral Flux from raw audio samples using Apple Accelerate.
/// Bọc FFTSetup (C-pointer của Apple Accelerate vDSP); toàn bộ bộ đệm tính toán đều bất biến sau khi khởi tạo (R8.3).
public final class MelSpectrogramService: @unchecked Sendable {
    public let sampleRate: Float = 22050.0
    public let nFFT: Int = 4096
    public let hopLength: Int = 512
    public let nMels: Int = 40
    public let fMin: Float = 50.0
    public let fMax: Float = 11025.0

    private let fftSetup: FFTSetup?
    private let log2n: vDSP_Length
    private var hannWindow: [Float]
    private var melFilterbank: [[Float]]

    public init() {
        self.log2n = vDSP_Length(log2(Double(nFFT)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        self.hannWindow = [Float](repeating: 0, count: nFFT)
        vDSP_hann_window(&hannWindow, vDSP_Length(nFFT), Int32(vDSP_HANN_NORM))

        self.melFilterbank = MelSpectrogramService.createMelFilterbank(
            nMels: nMels,
            nFFT: nFFT,
            sampleRate: sampleRate,
            fMin: fMin,
            fMax: fMax
        )
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    // MARK: - Mel Scale Conversion

    private static func hzToMel(_ hz: Float) -> Float {
        2595.0 * log10(1.0 + hz / 700.0)
    }

    private static func melToHz(_ mel: Float) -> Float {
        700.0 * (pow(10.0, mel / 2595.0) - 1.0)
    }

    private static func createMelFilterbank(
        nMels: Int,
        nFFT: Int,
        sampleRate: Float,
        fMin: Float,
        fMax: Float
    ) -> [[Float]] {
        let numBins = nFFT / 2 + 1
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: numBins), count: nMels)

        let melMin = hzToMel(fMin)
        let melMax = hzToMel(fMax)

        var melPoints = [Float](repeating: 0, count: nMels + 2)
        for i in 0..<(nMels + 2) {
            melPoints[i] = melMin + Float(i) * (melMax - melMin) / Float(nMels + 1)
        }

        var binIndices = [Float](repeating: 0, count: nMels + 2)
        for i in 0..<(nMels + 2) {
            let hz = melToHz(melPoints[i])
            binIndices[i] = floor((Float(nFFT) + 1.0) * hz / sampleRate)
        }

        for m in 1...nMels {
            let leftBin = Int(binIndices[m - 1])
            let centerBin = Int(binIndices[m])
            let rightBin = Int(binIndices[m + 1])

            for k in leftBin..<centerBin {
                if k >= 0 && k < numBins && centerBin > leftBin {
                    filterbank[m - 1][k] = Float(k - leftBin) / Float(centerBin - leftBin)
                }
            }
            for k in centerBin..<rightBin {
                if k >= 0 && k < numBins && rightBin > centerBin {
                    filterbank[m - 1][k] = Float(rightBin - k) / Float(rightBin - centerBin)
                }
            }
        }
        return filterbank
    }

    // MARK: - Spectral Flux (Onset Detection)

    /// Computes Normalized Spectral Flux matrix (40 Mel bands) to isolate rhythm onsets and suppress ambient noise.
    public func computeNormalizedSpectralFlux(samples: [Float]) -> [[Float]] {
        guard let fftSetup, samples.count >= nFFT else { return [] }

        let numFrames = (samples.count - nFFT) / hopLength + 1
        let numBins = nFFT / 2 + 1

        var melSpectrogram = [[Float]](repeating: [Float](repeating: 0, count: numFrames), count: nMels)
        var windowedFrame = [Float](repeating: 0, count: nFFT)
        var realParts = [Float](repeating: 0, count: nFFT / 2)
        var imagParts = [Float](repeating: 0, count: nFFT / 2)
        var powerSpectrum = [Float](repeating: 0, count: numBins)

        samples.withUnsafeBufferPointer { sPtr in
            guard let sBase = sPtr.baseAddress else { return }

            for frameIdx in 0..<numFrames {
                let startSample = frameIdx * hopLength
                vDSP_vmul(sBase + startSample, 1, hannWindow, 1, &windowedFrame, 1, vDSP_Length(nFFT))

                windowedFrame.withUnsafeBufferPointer { windowedPtr in
                    realParts.withUnsafeMutableBufferPointer { realPtr in
                        imagParts.withUnsafeMutableBufferPointer { imagPtr in
                            guard let rBase = realPtr.baseAddress, let iBase = imagPtr.baseAddress, let wBase = windowedPtr.baseAddress else { return }
                            var splitComplex = DSPSplitComplex(realp: rBase, imagp: iBase)

                            wBase.withMemoryRebound(to: DSPComplex.self, capacity: nFFT / 2) { complexPtr in
                                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(nFFT / 2))
                            }

                            vDSP_fft_zrip(fftSetup, &splitComplex, 1, self.log2n, FFTDirection(FFT_FORWARD))

                            var scale: Float = 0.5
                            vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(nFFT / 2))
                            vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(nFFT / 2))

                            powerSpectrum[0] = splitComplex.realp[0] * splitComplex.realp[0]
                            powerSpectrum[numBins - 1] = splitComplex.imagp[0] * splitComplex.imagp[0]

                            var subComplex = DSPSplitComplex(
                                realp: splitComplex.realp.advanced(by: 1),
                                imagp: splitComplex.imagp.advanced(by: 1)
                            )
                            vDSP_zvmags(&subComplex, 1, &powerSpectrum[1], 1, vDSP_Length(numBins - 2))
                        }
                    }
                }

                for m in 0..<nMels {
                    var melEnergy: Float = 0.0
                    let filter = melFilterbank[m]
                    vDSP_dotpr(powerSpectrum, 1, filter, 1, &melEnergy, vDSP_Length(numBins))
                    melSpectrogram[m][frameIdx] = log(1.0 + melEnergy)
                }
            }
        }

        guard numFrames > 1 else { return melSpectrogram }

        var spectralFlux = [[Float]](repeating: [Float](repeating: 0, count: numFrames - 1), count: nMels)
        var temp = [Float](repeating: 0, count: numFrames - 1)

        for m in 0..<nMels {
            for t in 1..<numFrames {
                let diff = melSpectrogram[m][t] - melSpectrogram[m][t - 1]
                spectralFlux[m][t - 1] = max(0.0, diff)
            }

            var mean: Float = 0.0
            vDSP_meanv(spectralFlux[m], 1, &mean, vDSP_Length(numFrames - 1))

            var negMean = -mean
            vDSP_vsadd(spectralFlux[m], 1, &negMean, &temp, 1, vDSP_Length(numFrames - 1))

            var variance: Float = 0.0
            vDSP_measqv(temp, 1, &variance, vDSP_Length(numFrames - 1))
            let std = sqrt(variance) + 1e-6

            var invStd = 1.0 / std
            vDSP_vsmul(temp, 1, &invStd, &spectralFlux[m], 1, vDSP_Length(numFrames - 1))
        }

        return spectralFlux
    }
}
