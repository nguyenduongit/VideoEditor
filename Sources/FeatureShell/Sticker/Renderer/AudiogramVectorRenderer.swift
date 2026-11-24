import Foundation
import CoreGraphics
import Domain
#if os(macOS)
import AppKit
#endif

/// Procedural 60fps CoreGraphics vector renderer for Audio-Reactive Audiogram Stickers.
public enum AudiogramVectorRenderer: Sendable {
    /// Ideal vector canvas proportions for each Audiogram visual style.
    public static func canvasDimensions(for style: StickerAudiogramStyle, targetSize: CGSize) -> CGSize {
        let maxSide = max(96.0, min(1024.0, max(targetSize.width, targetSize.height) * 2.0))
        switch style {
        case .spectrumBars, .mirrorWave, .flowingRibbon, .dotMatrix:
            return CGSize(width: maxSide, height: round(maxSide * 0.68))
        case .circularRing, .bassSpeaker, .musicNotePulse, .vinylEqualizer:
            return CGSize(width: maxSide, height: maxSide)
        }
    }

    /// Draws an anti-aliased RGBA `CGImage` driven by real-time `AudioReactiveFrame` and elapsed `time`.
    public static func render(
        config: StickerAudiogramConfiguration,
        frame: AudioReactiveFrame,
        targetSize: CGSize,
        time: Double
    ) -> CGImage? {
        let size = canvasDimensions(for: config.style, targetSize: targetSize)
        let w = max(32, Int(size.width))
        let h = max(32, Int(size.height))
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        let primary = rgbaComponents(from: config.primaryColorHex, fallback: (0.02, 0.71, 0.83, 1.0))
        let secondary = rgbaComponents(from: config.secondaryColorHex, fallback: (0.55, 0.36, 0.96, 1.0))

        switch config.style {
        case .spectrumBars:
            drawSpectrumBars(in: ctx, rect: rect, count: config.barCount, frame: frame, primary: primary, secondary: secondary)
        case .mirrorWave:
            drawMirrorWave(in: ctx, rect: rect, count: config.barCount, frame: frame, primary: primary, secondary: secondary)
        case .circularRing:
            drawCircularRing(in: ctx, rect: rect, count: config.barCount, frame: frame, primary: primary, secondary: secondary)
        case .flowingRibbon:
            drawFlowingRibbon(in: ctx, rect: rect, frame: frame, time: time, primary: primary, secondary: secondary)
        case .bassSpeaker:
            drawBassSpeaker(in: ctx, rect: rect, frame: frame, primary: primary, secondary: secondary)
        case .musicNotePulse:
            drawMusicNotePulse(in: ctx, rect: rect, frame: frame, primary: primary, secondary: secondary)
        case .vinylEqualizer:
            drawVinylEqualizer(in: ctx, rect: rect, count: config.barCount, frame: frame, time: time, primary: primary, secondary: secondary)
        case .dotMatrix:
            drawDotMatrix(in: ctx, rect: rect, count: min(16, max(8, config.barCount)), frame: frame, primary: primary, secondary: secondary)
        }

        return ctx.makeImage()
    }

    // MARK: - Core Waveform & Spectrum Styles

    private static func drawSpectrumBars(
        in ctx: CGContext, rect: CGRect, count: Int,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let n = max(8, count)
        let padX = rect.width * 0.08
        let baselineY = rect.height * 0.16
        let usableW = rect.width - padX * 2.0
        let maxBarH = rect.height * 0.72
        let slotW = usableW / CGFloat(n)
        let barW = max(2.0, slotW * 0.62)

        ctx.setFillColor(cgColor(primary, alpha: 0.28))
        ctx.fill(CGRect(x: padX, y: baselineY - 1.5, width: usableW, height: 2.0))

        for i in 0..<n {
            let t = n > 1 ? Double(i) / Double(n - 1) : 0.0
            let amp = sampleBand(frame.bands, normalizedPosition: t)
            let barH = max(barW, maxBarH * CGFloat(amp))
            let x = padX + CGFloat(i) * slotW + (slotW - barW) * 0.5
            let barRect = CGRect(x: x, y: baselineY, width: barW, height: barH)
            let col = blendRGBA(primary, secondary, t: t, alpha: 0.94)
            fillRoundedRect(in: ctx, rect: barRect, radius: barW * 0.45, color: col)

            let capRect = CGRect(x: x, y: min(rect.height - barW, baselineY + barH + 3.0), width: barW, height: max(2.0, barW * 0.35))
            fillRoundedRect(in: ctx, rect: capRect, radius: barW * 0.2, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.88))
        }
    }

    private static func drawMirrorWave(
        in ctx: CGContext, rect: CGRect, count: Int,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let n = max(10, count)
        let padX = rect.width * 0.07
        let midY = rect.midY
        let usableW = rect.width - padX * 2.0
        let halfMax = rect.height * 0.42
        let slotW = usableW / CGFloat(n)
        let barW = max(2.0, slotW * 0.58)

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
        ctx.fill(CGRect(x: padX * 0.6, y: midY - 0.75, width: rect.width - padX * 1.2, height: 1.5))

        for i in 0..<n {
            let mirrorU = abs(Double(i) / Double(max(1, n - 1)) * 2.0 - 1.0)
            let amp = sampleBand(frame.bands, normalizedPosition: 1.0 - mirrorU) * (0.45 + 0.55 * (1.0 - mirrorU * 0.45))
            let halfH = max(barW * 0.6, halfMax * CGFloat(amp))
            let x = padX + CGFloat(i) * slotW + (slotW - barW) * 0.5
            let barRect = CGRect(x: x, y: midY - halfH, width: barW, height: halfH * 2.0)
            let col = blendRGBA(primary, secondary, t: Double(i) / Double(max(1, n - 1)), alpha: 0.95)
            fillRoundedRect(in: ctx, rect: barRect, radius: barW * 0.5, color: col)
        }
    }

    private static func drawCircularRing(
        in ctx: CGContext, rect: CGRect, count: Int,
        frame: AudioReactiveFrame, primary: RGBA, secondary: RGBA
    ) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let minDim = min(rect.width, rect.height)
        let bassBoost = CGFloat(frame.bassLevel * 0.16 + frame.beatImpulse * 0.14)
        let baseR = minDim * (0.24 + bassBoost * 0.25)
        let maxSpike = minDim * 0.21

        ctx.setStrokeColor(cgColor(primary, alpha: 0.92))
        ctx.setLineWidth(max(2.5, minDim * 0.018))
        ctx.addArc(center: center, radius: baseR, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.strokePath()

        ctx.setStrokeColor(cgColor(secondary, alpha: 0.25 + frame.beatImpulse * 0.35))
        ctx.setLineWidth(max(1.5, minDim * 0.01))
        ctx.addArc(center: center, radius: baseR * 0.80, startAngle: 0, endAngle: .pi * 2.0, clockwise: false)
        ctx.strokePath()

        let spikes = max(16, count)
        let strokeW = max(2.0, (2.0 * .pi * baseR) / CGFloat(spikes) * 0.48)
        ctx.setLineCap(.round)
        ctx.setLineWidth(strokeW)

        for i in 0..<spikes {
            let t = Double(i) / Double(spikes)
            let symmetricT = t <= 0.5 ? (t * 2.0) : ((1.0 - t) * 2.0)
            let amp = sampleBand(frame.bands, normalizedPosition: symmetricT)
            let len = max(strokeW, maxSpike * CGFloat(amp))
            let ang = CGFloat(t * 2.0 * .pi) - .pi * 0.5
            let p0 = CGPoint(x: center.x + cos(ang) * (baseR + strokeW * 0.8), y: center.y + sin(ang) * (baseR + strokeW * 0.8))
            let p1 = CGPoint(x: center.x + cos(ang) * (baseR + strokeW * 0.8 + len), y: center.y + sin(ang) * (baseR + strokeW * 0.8 + len))
            ctx.setStrokeColor(blendRGBA(primary, secondary, t: symmetricT, alpha: 0.96))
            ctx.move(to: p0)
            ctx.addLine(to: p1)
            ctx.strokePath()
        }
    }

    private static func drawFlowingRibbon(
        in ctx: CGContext, rect: CGRect,
        frame: AudioReactiveFrame, time: Double, primary: RGBA, secondary: RGBA
    ) {
        let steps = 48
        let padX = rect.width * 0.06
        let spanW = rect.width - padX * 2.0
        let midY = rect.midY
        let ampScale = rect.height * (0.14 + 0.30 * CGFloat(frame.overallLevel + frame.beatImpulse * 0.25))

        for layer in 0..<2 {
            let isFront = layer == 1
            let phase = time * (isFront ? 5.2 : 3.6) + (isFront ? 0.0 : 1.4)
            let path = CGMutablePath()
            let mirrorPath = CGMutablePath()

            for s in 0...steps {
                let u = Double(s) / Double(steps)
                let env = sin(u * .pi)
                let bandVal = sampleBand(frame.bands, normalizedPosition: u)
                let wave = sin(u * 10.0 * .pi + phase) * 0.55 + cos(u * 19.0 * .pi - phase * 1.3) * 0.45
                let dy = ampScale * CGFloat(env * (0.35 + 0.65 * bandVal) * wave) * (isFront ? 1.0 : 0.72)
                let pt = CGPoint(x: padX + spanW * CGFloat(u), y: midY + dy)
                let mPt = CGPoint(x: pt.x, y: midY - dy * 0.85)
                if s == 0 {
                    path.move(to: pt)
                    mirrorPath.move(to: mPt)
                } else {
                    path.addLine(to: pt)
                    mirrorPath.addLine(to: mPt)
                }
            }
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(isFront ? max(3.0, rect.height * 0.032) : max(2.0, rect.height * 0.02))
            ctx.setStrokeColor(cgColor(isFront ? primary : secondary, alpha: isFront ? 0.96 : 0.65))
            ctx.addPath(path)
            ctx.strokePath()
            ctx.setStrokeColor(cgColor(isFront ? secondary : primary, alpha: isFront ? 0.55 : 0.35))
            ctx.addPath(mirrorPath)
            ctx.strokePath()
        }
    }

    // MARK: - Shared Vector Helpers

    typealias RGBA = (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)

    static func sampleBand(_ bands: [Double], normalizedPosition u: Double) -> Double {
        guard !bands.isEmpty else { return 0.25 }
        let clamped = max(0.0, min(1.0, u))
        let pos = clamped * Double(bands.count - 1)
        let i0 = Int(floor(pos))
        let i1 = min(bands.count - 1, i0 + 1)
        let f = pos - Double(i0)
        return max(0.04, min(1.0, bands[i0] + (bands[i1] - bands[i0]) * f))
    }

    static func rgbaComponents(from hex: String, fallback: RGBA) -> RGBA {
        #if os(macOS)
        let ns = TextAdvancedStyleRenderer.parseHexColor(hex)
        if let srgb = ns.usingColorSpace(.sRGB) {
            return (srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent)
        }
        #endif
        return fallback
    }

    static func cgColor(_ c: RGBA, alpha: CGFloat? = nil) -> CGColor {
        CGColor(red: c.r, green: c.g, blue: c.b, alpha: alpha ?? c.a)
    }

    static func blendRGBA(_ a: RGBA, _ b: RGBA, t: Double, alpha: CGFloat = 1.0) -> CGColor {
        let k = CGFloat(max(0.0, min(1.0, t)))
        return CGColor(
            red: a.r + (b.r - a.r) * k,
            green: a.g + (b.g - a.g) * k,
            blue: a.b + (b.b - a.b) * k,
            alpha: alpha
        )
    }

    static func fillRoundedRect(in ctx: CGContext, rect: CGRect, radius: CGFloat, color: CGColor) {
        let r = min(radius, min(rect.width, rect.height) * 0.5)
        let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        ctx.setFillColor(color)
        ctx.addPath(path)
        ctx.fillPath()
    }
}
