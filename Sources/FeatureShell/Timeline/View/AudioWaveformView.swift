import SwiftUI
import CoreMedia
@preconcurrency import AVFoundation
import Domain
import DesignSystem

@MainActor
enum AudioWaveformMemoryCache {
    static let cache = LRUCache<URL, [Float]>(capacity: 64)
}

public struct AudioWaveformView: View {
    private let url: URL?
    private let service: (any AudioWaveformServiceProtocol)?
    private let sourceStartTime: CMTime
    private let sourceDuration: CMTime?
    private let pixelsPerSecond: CGFloat
    private let thresholdDB: Float
    private let fadeIn: Double
    private let fadeOut: Double
    private let clipDuration: CMTime?
    private let speed: Double

    @State private var peaks: [Float]
    @State private var totalDurationSeconds: Double = 0

    public init(
        url: URL?,
        service: (any AudioWaveformServiceProtocol)?,
        sourceStartTime: CMTime = .zero,
        sourceDuration: CMTime? = nil,
        pixelsPerSecond: CGFloat = 60.0,
        thresholdDB: Float = AudioWaveformMath.defaultThresholdDB,
        fadeIn: Double = 0.0,
        fadeOut: Double = 0.0,
        clipDuration: CMTime? = nil,
        speed: Double = 1.0
    ) {
        self.url = url
        self.service = service
        self.sourceStartTime = sourceStartTime
        self.sourceDuration = sourceDuration
        self.pixelsPerSecond = pixelsPerSecond
        self.thresholdDB = thresholdDB
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.clipDuration = clipDuration
        self.speed = max(0.01, speed)
        if let url, let cached = AudioWaveformMemoryCache.cache[url] {
            self._peaks = State(initialValue: cached)
        } else {
            self._peaks = State(initialValue: [])
        }
        if let sourceDuration {
            let sec = CMTimeGetSeconds(sourceDuration)
            if sec > 0 && sec.isFinite {
                self._totalDurationSeconds = State(initialValue: sec)
            }
        }
    }

    public var body: some View {
        Canvas { context, size in
            let barWidth: CGFloat = 1.3
            let spacing: CGFloat = 0.7
            let pitch = barWidth + spacing
            let barCount = max(1, Int(size.width / pitch))
            let availHeight = max(4.0, size.height - 4.0)
            let yBottom = size.height - 2.0
            let threshLinear = pow(10.0, thresholdDB / 20.0)
            let threshFraction = CGFloat(AudioWaveformMath.perceptualHeightFraction(amplitude: threshLinear))
            let yThreshold = yBottom - (threshFraction * availHeight)
            let pps = max(1.0, pixelsPerSecond)
            let sourceStartSec = max(0, CMTimeGetSeconds(sourceStartTime))
            let clipDurSec = clipDuration.map { CMTimeGetSeconds($0) } ?? (Double(size.width) / Double(pps))

            drawThresholdGuide(context: context, width: size.width, y: yThreshold)

            let effSpeed = max(0.01, speed)
            for i in 0..<barCount {
                let x = CGFloat(i) * pitch
                let timelineSec = Double(x) / Double(pps)
                let tStart = sourceStartSec + (timelineSec * effSpeed)
                let tEnd = tStart + ((Double(pitch) / Double(pps)) * effSpeed)
                let relTime = timelineSec

                let amp = AudioWaveformMath.peakInRange(
                    peaks: peaks,
                    sourceStartTime: tStart,
                    sourceEndTime: tEnd,
                    peaksPerSecond: 100.0
                )
                let gain = AudioWaveformMath.envelopeGain(at: relTime, duration: clipDurSec, fadeIn: fadeIn, fadeOut: fadeOut)

                drawBar(
                    context: context,
                    x: x,
                    barWidth: barWidth,
                    amp: amp * gain,
                    availHeight: availHeight,
                    yBottom: yBottom,
                    yThreshold: yThreshold,
                    threshLinear: threshLinear
                )
            }

            if fadeIn > 0.001 || fadeOut > 0.001 {
                drawEnvelopeLine(
                    context: context,
                    width: size.width,
                    yBottom: yBottom,
                    yTop: yBottom - availHeight,
                    fadeIn: fadeIn,
                    fadeOut: fadeOut,
                    pps: pps
                )
            }
        }
        .task(id: url) {
            await loadWaveform()
        }
    }

    private func drawEnvelopeLine(
        context: GraphicsContext,
        width: CGFloat,
        yBottom: CGFloat,
        yTop: CGFloat,
        fadeIn: Double,
        fadeOut: Double,
        pps: CGFloat
    ) {
        var path = Path()
        let inW = min(width, CGFloat(fadeIn) * pps)
        let outW = min(width - inW, CGFloat(fadeOut) * pps)

        path.move(to: CGPoint(x: 0, y: yBottom))
        path.addLine(to: CGPoint(x: inW, y: yTop))
        path.addLine(to: CGPoint(x: max(inW, width - outW), y: yTop))
        path.addLine(to: CGPoint(x: width, y: yBottom))

        context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1.0)
    }

    private func drawThresholdGuide(context: GraphicsContext, width: CGFloat, y: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: width, y: y))
        context.stroke(path, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)
    }

    private func drawBar(
        context: GraphicsContext,
        x: CGFloat,
        barWidth: CGFloat,
        amp: Float,
        availHeight: CGFloat,
        yBottom: CGFloat,
        yThreshold: CGFloat,
        threshLinear: Float
    ) {
        let normH = CGFloat(AudioWaveformMath.perceptualHeightFraction(amplitude: amp))
        let barHeight = max(1.5, normH * availHeight)
        let yTop = yBottom - barHeight

        if amp <= threshLinear {
            let rect = CGRect(x: x, y: yTop, width: barWidth, height: barHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 0.4), with: .color(DSColors.waveformBar))
        } else {
            let safeHeight = max(0, yBottom - yThreshold)
            let safeRect = CGRect(x: x, y: yThreshold, width: barWidth, height: safeHeight)
            context.fill(Path(roundedRect: safeRect, cornerRadius: 0.4), with: .color(DSColors.waveformBar))

            let peakHeight = max(1.0, yThreshold - yTop)
            let peakRect = CGRect(x: x, y: yTop, width: barWidth, height: peakHeight)
            context.fill(Path(roundedRect: peakRect, cornerRadius: 0.4), with: .color(DSColors.waveformPeak))
        }
    }

    private func loadWaveform() async {
        guard let url, let service else { return }
        if let cached = AudioWaveformMemoryCache.cache[url] {
            if peaks.isEmpty {
                peaks = cached
            }
            return
        }
        if totalDurationSeconds <= 0 {
            if let resolved = TimelineMediaDurationResolver.resolveDuration(for: url, type: .audio) {
                totalDurationSeconds = CMTimeGetSeconds(resolved)
            } else {
                let asset = AVURLAsset(url: url)
                if let dur = try? await asset.load(.duration) {
                    let sec = CMTimeGetSeconds(dur)
                    if sec.isFinite && !sec.isNaN && sec > 0 {
                        totalDurationSeconds = sec
                    }
                }
            }
        }
        let loaded = await service.generateWaveformPeaks(for: url, samplesPerSecond: 100)
        if !loaded.isEmpty && !Task.isCancelled {
            peaks = loaded
            AudioWaveformMemoryCache.cache[url] = loaded
        }
    }
}
