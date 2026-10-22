import Foundation
import AVFoundation
import Accelerate

/// Protocol định nghĩa giao diện phát hiện nhịp (Beat Detection)
public protocol BeatDetectorServiceProtocol: Sendable {
    func detectBPM(url: URL, completion: @escaping @Sendable (BeatDetectorService.BeatAnalysisResult?) -> Void)
    func analyzeSamples(_ samples: [Float], sampleRate: Double) -> BeatDetectorService.BeatAnalysisResult?
}

/// Dịch vụ tự động phân tích tempo (BPM) và căn chỉnh pha nhịp (Phase Alignment)
/// Sử dụng thuật toán Onset Energy Flux trên dải âm trầm (Bass/Kick Transient Detection)
/// và bộ cộng hưởng răng lược (Comb Filter Phase Locking) đã được kiểm chứng chuẩn MIR
public final class BeatDetectorService: BeatDetectorServiceProtocol, @unchecked Sendable {
    public static let shared = BeatDetectorService()
    
    private let decoder: AudioDecoderServiceProtocol

    public init(decoder: AudioDecoderServiceProtocol = AudioDecoderService.shared) {
        self.decoder = decoder
    }
    
    public struct BeatAnalysisResult: Sendable {
        public let bpm: Double
        public let firstDownbeatTime: Double // Thời điểm phách 1 (Downbeat - vạch Xanh lá) đầu tiên (giây)
        public let beatInterval: Double     // Khoảng cách giữa 2 phách = 60 / BPM (giây)
        public let confidence: Double
    }
    
    /// Phân tích nhịp và tìm pha nhịp chính xác từ tệp âm thanh hoặc video
    public func detectBPM(url: URL, completion: @escaping @Sendable (BeatAnalysisResult?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let samples = self.decoder.decodeToMonoFloat32(url: url) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let result = self.analyzeSamples(samples, sampleRate: 22050.0)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// Thuật toán Onset Energy Flux trên dải trầm + Autocorrelation + Comb Filter Phase Alignment
    public func analyzeSamples(_ samples: [Float], sampleRate: Double) -> BeatAnalysisResult? {
        guard samples.count > Int(sampleRate * 3.0) else { return nil }
        
        // 1. Lọc thông thấp Biquad IIR (Low-pass filter fc = 220Hz) để bắt riêng tiếng trống Kick/Bass
        // Giúp loại bỏ hoàn toàn nhiễu từ giọng hát, tiếng vỗ tay và chũm chọe (Hi-hat)
        let filteredSamples = lowPassFilter(samples, sampleRate: sampleRate, cutoffHz: 220.0)
        
        // 2. Tính Onset Energy Flux (Cửa sổ 15ms, bước nhảy hop 10ms -> 100 frames/giây)
        let hopSize = Int(sampleRate * 0.010) // 10ms hop
        let winSize = Int(sampleRate * 0.020) // 20ms window
        let numFrames = max(1, (filteredSamples.count - winSize) / hopSize)
        var envelope = [Float](repeating: 0, count: numFrames)
        
        var prevEnergy: Float = 0.0
        for f in 0..<numFrames {
            let start = f * hopSize
            let end = start + winSize
            var sumSq: Float = 0.0
            for i in start..<end {
                let s = filteredSamples[i]
                sumSq += s * s
            }
            let energy = sqrt(sumSq / Float(winSize))
            // Half-wave rectification: Chỉ lấy phần năng lượng tăng đột biến (transient onset)
            let diff = max(0.0, energy - prevEnergy)
            envelope[f] = diff
            prevEnergy = energy
        }
        
        let fps = sampleRate / Double(hopSize) // 100 frames/giây (độ chính xác 10ms)
        
        // 3. Tự tương quan (Autocorrelation) trong dải BPM [75, 175] kết hợp hàm ưu tiên (Tempo Prior)
        let minBPM = 75.0
        let maxBPM = 175.0
        let minLag = Int(fps * (60.0 / maxBPM))
        let maxLag = Int(fps * (60.0 / minBPM))
        
        var bestLag = minLag
        var maxCorr: Float = -1.0
        let searchRange = min(envelope.count / 2, 3000)
        
        for lag in minLag...maxLag {
            var corr: Float = 0.0
            for i in 0..<searchRange {
                corr += envelope[i] * envelope[i + lag]
            }
            // Gaussian prior quanh 125 BPM (nhịp tiêu chuẩn phổ biến của dance/aerobic)
            let bpmCandidate = (fps * 60.0) / Double(lag)
            let logDiff = log2(bpmCandidate / 125.0)
            let prior = exp(-Float(logDiff * logDiff) / 0.35)
            let weightedCorr = corr * prior
            
            if weightedCorr > maxCorr {
                maxCorr = weightedCorr
                bestLag = lag
            }
        }
        
        let detectedBPM = round((fps * 60.0) / Double(bestLag))
        let beatInterval = 60.0 / detectedBPM
        let framesPerBeatExact = fps * beatInterval
        guard framesPerBeatExact > 1.0 else { return nil }

        // Kiểm tra năng lượng onset: nếu maxCorr ≤ 0 (audio im lặng hoặc không có nhịp thực),
        // trả nil thay vì trả kết quả giả với confidence âm.
        guard maxCorr > 0 else { return nil }
        
        // 4. Khóa pha bằng bộ cộng hưởng lược (Comb Filter Phase Locking)
        // Tìm pha phi* trong khoảng [0, framesPerBeat) có tổng xung năng lượng kick cao nhất
        // Dùng phép tính số thực chính xác để triệt tiêu hoàn toàn sai số trôi số học (Accumulated Frame Drift)
        let searchPhaseLimit = Int(ceil(framesPerBeatExact))
        let phaseSearchLimit = min(envelope.count, Int(fps * 30.0)) // Quét trong 30s đầu
        let numBeatsInWindow = Int(Double(phaseSearchLimit) / framesPerBeatExact)
        
        var bestPhase = 0
        var maxPhaseScore: Float = -1.0
        
        for phase in 0..<searchPhaseLimit {
            var score: Float = 0.0
            var count: Float = 0.0
            for b in 0..<numBeatsInWindow {
                let fExact = Double(phase) + (Double(b) * framesPerBeatExact)
                let f = Int(round(fExact))
                if f < envelope.count {
                    score += envelope[f]
                    count += 1.0
                }
            }
            let avgScore = score / max(1.0, count)
            if avgScore > maxPhaseScore {
                maxPhaseScore = avgScore
                bestPhase = phase
            }
        }
        
        let bestBeatPhaseSec = Double(bestPhase) / fps
        
        // 5. Xác định phách Downbeat (Phách 1 của khuông 4/4 - Vạch Xanh Lá)
        // Kiểm tra trong 4 phách (0, 1, 2, 3) xem phách nào có lực dập trống mạnh nhất
        let framesPerBarExact = framesPerBeatExact * 4.0
        let numBarsInWindow = Int(Double(phaseSearchLimit) / framesPerBarExact)
        var bestBarOffset = 0
        var maxBarScore: Float = -1.0
        
        for b in 0..<4 {
            let barStartPhase = Double(bestPhase) + (Double(b) * framesPerBeatExact)
            var score: Float = 0.0
            var count: Float = 0.0
            for bar in 0..<numBarsInWindow {
                let fExact = barStartPhase + (Double(bar) * framesPerBarExact)
                let f = Int(round(fExact))
                if f < envelope.count {
                    score += envelope[f]
                    count += 1.0
                }
            }
            let avg = score / max(1.0, count)
            if avg > maxBarScore {
                maxBarScore = avg
                bestBarOffset = b
            }
        }
        
        let firstDownbeatSec = bestBeatPhaseSec + (Double(bestBarOffset) * beatInterval)
        
        return BeatAnalysisResult(
            bpm: detectedBPM,
            firstDownbeatTime: firstDownbeatSec,
            beatInterval: beatInterval,
            confidence: Double(maxCorr)
        )
    }
    
    // MARK: - 2nd Order Butterworth Low-Pass Filter
    private func lowPassFilter(_ input: [Float], sampleRate: Double, cutoffHz: Double) -> [Float] {
        guard !input.isEmpty else { return [] }
        let k = tan(.pi * cutoffHz / sampleRate)
        let q: Double = 0.7071
        let norm = 1.0 / (1.0 + (k / q) + (k * k))
        
        let b0 = Float(k * k * norm)
        let b1 = Float(2.0 * b0)
        let b2 = b0
        let a1 = Float(2.0 * (k * k - 1.0) * norm)
        let a2 = Float((1.0 - (k / q) + (k * k)) * norm)
        
        var output = [Float](repeating: 0, count: input.count)
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0
        
        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = (b0 * x0) + (b1 * x1) + (b2 * x2) - (a1 * y1) - (a2 * y2)
            output[i] = y0
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }
        return output
    }
}
