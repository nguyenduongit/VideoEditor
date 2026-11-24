import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif
import Domain

/// Engine kết xuất Nhãn dán (Sticker `.svg`, `.png`, `.gif`, `.apng`) ở 60fps.
/// Hỗ trợ rasterize Vector SVG trực tiếp ở độ phân giải sau phóng đại (`baseSize * scale`),
/// lật ngang/dọc, đổ bóng, hòa trộn Blend Mode và đồng bộ trọn vẹn hệ thống hoạt ảnh Script-Driven (`Intro → Loop → Outro`).
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public final class StickerRendererEngine: Sendable {
    public init() {}

    /// Kích thước cơ sở (chưa nhân `scale`) của Sticker theo khung hình Canvas.
    public static func baseStickerSize(for canvasSize: CGSize) -> CGSize {
        let side = max(32.0, round(min(canvasSize.width, canvasSize.height) * 0.22))
        return CGSize(width: side, height: side)
    }

    /// Hòa trộn Sticker lên nền `background` theo `blendMode` của `StickerConfiguration`.
    public func composite(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        over background: CIImage,
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        compTime: Double? = nil,
        audioTracks: [AudioReactiveTrackSnapshot] = []
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        guard let fg = renderStickerImage(
            config: config,
            clipProperties: clipProperties,
            localTime: localTime,
            duration: duration,
            canvasSize: canvasSize,
            compTime: compTime,
            audioTracks: audioTracks
        ) else {
            return background
        }

        if config.blendMode == .normal {
            return fg.composited(over: background).cropped(to: canvasRect)
        }
        guard let filter = CIFilter(name: config.blendMode.ciFilterName, parameters: [
            kCIInputImageKey: fg,
            kCIInputBackgroundImageKey: background
        ]), let out = filter.outputImage else {
            return fg.composited(over: background).cropped(to: canvasRect)
        }
        return out.cropped(to: canvasRect)
    }

    /// Kết xuất Sticker thành `CIImage` kích thước `canvasSize` (đã áp dụng Transform, Shadow, Audiogram DSP & Animation).
    public func renderStickerImage(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        compTime: Double? = nil,
        audioTracks: [AudioReactiveTrackSnapshot] = []
    ) -> CIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let refSize = CanvasAspectRatio.closest(for: canvasSize).renderSize
        let coordScaleX = refSize.width > 0 ? Double(canvasSize.width / refSize.width) : 1.0
        let coordScaleY = refSize.height > 0 ? Double(canvasSize.height / refSize.height) : 1.0

        let rawPosX = (clipProperties["positionX"]?.asNumber ?? 0.0) * coordScaleX
        let rawPosY = (clipProperties["positionY"]?.asNumber ?? 0.0) * coordScaleY
        let rawScale = max(0.05, clipProperties["scale"]?.asNumber ?? 1.0)
        let rawRotation = clipProperties["rotation"]?.asNumber ?? 0.0
        let rawOpacity = max(0.0, min(1.0, clipProperties["opacity"]?.asNumber ?? 1.0))

        let baseSize = Self.baseStickerSize(for: canvasSize)
        var evaluated = StickerAnimationEvaluator.evaluate(
            animation: config.animation,
            localTime: localTime,
            clipDuration: duration,
            baseStickerSize: baseSize,
            positionX: rawPosX,
            positionY: rawPosY,
            scale: rawScale,
            rotation: rawRotation,
            opacity: rawOpacity
        )
        guard evaluated.opacity > 0.002 else { return nil }

        let effScaleX = max(0.02, evaluated.scaleX)
        let effScaleY = max(0.02, evaluated.scaleY)
        let rasterTarget = CGSize(
            width: max(32.0, min(4096.0, baseSize.width * CGFloat(effScaleX))),
            height: max(32.0, min(4096.0, baseSize.height * CGFloat(effScaleY)))
        )

        let audiogramFrame = resolveAudiogramFrameIfNeeded(
            config: config,
            compTime: compTime ?? localTime,
            audioTracks: audioTracks,
            evaluated: &evaluated
        )

        guard let sourceCG = resolveSourceCGImage(
            config: config,
            clipProperties: clipProperties,
            localTime: localTime,
            rasterTarget: rasterTarget,
            audiogramFrame: audiogramFrame
        ) else {
            return nil
        }

        return transformAndStyleSticker(
            sourceCG: sourceCG,
            config: config,
            evaluated: evaluated,
            baseSize: baseSize,
            rawScale: rawScale,
            effScaleX: effScaleX,
            effScaleY: effScaleY,
            canvasSize: canvasSize
        )
    }

    private func resolveAudiogramFrameIfNeeded(
        config: StickerConfiguration,
        compTime: Double,
        audioTracks: [AudioReactiveTrackSnapshot],
        evaluated: inout StickerAnimationEvaluator.EvaluationResult
    ) -> AudioReactiveFrame? {
        guard config.format == .audiogram else { return nil }
        let ag = config.audiogram ?? StickerAudiogramConfiguration()
        let sampled = AudioReactiveSampler.sample(
            atTimelineTime: compTime,
            tracks: audioTracks,
            bandCount: ag.barCount,
            sensitivity: ag.sensitivity,
            reactsToBeat: ag.reactsToBeat,
            fallbackBPM: config.animation.beatBPM
        )
        if ag.isGlowEnabled {
            evaluated.glowIntensity = max(evaluated.glowIntensity, 0.25 + sampled.overallLevel * 0.5 + sampled.beatImpulse * 0.4)
        }
        return sampled
    }

    private func resolveSourceCGImage(
        config: StickerConfiguration,
        clipProperties: [String: PropertyValue],
        localTime: Double,
        rasterTarget: CGSize,
        audiogramFrame: AudioReactiveFrame?
    ) -> CGImage? {
        if config.format == .audiogram {
            let ag = config.audiogram ?? StickerAudiogramConfiguration()
            let frame = audiogramFrame ?? AudioReactiveSampler.sample(atTimelineTime: localTime, tracks: [], bandCount: ag.barCount, sensitivity: ag.sensitivity, reactsToBeat: ag.reactsToBeat, fallbackBPM: config.animation.beatBPM)
            return AudiogramVectorRenderer.render(config: ag, frame: frame, targetSize: rasterTarget, time: localTime)
        }
        let speed = clipProperties["speed"]?.asNumber ?? config.playbackSpeed
        let loopRaw = clipProperties["loopMode"]?.asString ?? config.loopMode.rawValue
        let shouldLoop = (StickerLoopMode(rawValue: loopRaw) ?? config.loopMode) == .loop

        if let srcPath = config.sourceURLString, !srcPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let cg = TextSVGAndAssetCache.shared.frameForAsset(
                path: srcPath,
                localTime: localTime,
                loop: shouldLoop,
                speed: speed,
                targetSize: rasterTarget
            ) {
                return cg
            }
        }

        if let originID = clipProperties["originPresetId"]?.asString, !originID.isEmpty {
            if let cg = TextSVGAndAssetCache.shared.frameForAsset(
                path: "\(originID).apng",
                localTime: localTime,
                loop: shouldLoop,
                speed: speed,
                targetSize: rasterTarget
            ) {
                return cg
            }
        }

        if let svg = config.svgMarkup, !svg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let cg = TextSVGAndAssetCache.shared.rasterizeSVG(svg, targetSize: rasterTarget) {
                return cg
            }
        }

        let symbol = clipProperties["systemSymbolFallback"]?.asString
            ?? config.systemSymbolFallback
            ?? "face.smiling"
        return TextSVGAndAssetCache.shared.rasterizeSymbol(
            name: symbol,
            tintHex: "#06B6D4",
            targetSize: rasterTarget
        )
    }

    private func transformAndStyleSticker(
        sourceCG: CGImage,
        config: StickerConfiguration,
        evaluated: StickerAnimationEvaluator.EvaluationResult,
        baseSize: CGSize,
        rawScale: Double,
        effScaleX: Double,
        effScaleY: Double,
        canvasSize: CGSize
    ) -> CIImage {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var img = CIImage(cgImage: sourceCG)
        let srcW = max(1.0, CGFloat(sourceCG.width))
        let srcH = max(1.0, CGFloat(sourceCG.height))

        if evaluated.clipRevealX < 0.999 || evaluated.clipRevealY < 0.999 {
            let revW = max(1.0, srcW * CGFloat(evaluated.clipRevealX))
            let revH = max(1.0, srcH * CGFloat(evaluated.clipRevealY))
            img = img.cropped(to: CGRect(x: 0, y: srcH - revH, width: revW, height: revH))
        }

        let transform = buildStickerTransform(
            srcSize: CGSize(width: srcW, height: srcH),
            baseSize: baseSize,
            rawScale: rawScale,
            effScaleX: effScaleX,
            effScaleY: effScaleY,
            config: config,
            evaluated: evaluated,
            canvasSize: canvasSize
        )
        img = img.transformed(by: transform)
        img = applyAnimationEffects(to: img, evaluated: evaluated, canvasRect: canvasRect)

        if config.hasShadow {
            img = applyDropShadow(to: img, config: config, canvasRect: canvasRect)
        }

        img = TextSVGAndAssetCache.applyPremultipliedOpacity(evaluated.opacity, to: img)
        let clearCanvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: canvasRect)
        return img.cropped(to: canvasRect).composited(over: clearCanvas)
    }

    private func buildStickerTransform(
        srcSize: CGSize,
        baseSize: CGSize,
        rawScale: Double,
        effScaleX: Double,
        effScaleY: Double,
        config: StickerConfiguration,
        evaluated: StickerAnimationEvaluator.EvaluationResult,
        canvasSize: CGSize
    ) -> CGAffineTransform {
        let aspect = srcSize.width / srcSize.height
        let targetW: CGFloat = aspect >= 1.0 ? baseSize.width * CGFloat(effScaleX) : baseSize.height * CGFloat(effScaleX) * aspect
        let targetH: CGFloat = aspect >= 1.0 ? (baseSize.width * CGFloat(effScaleY)) / aspect : baseSize.height * CGFloat(effScaleY)
        let restH: CGFloat = aspect >= 1.0 ? (baseSize.width * CGFloat(rawScale)) / aspect : baseSize.height * CGFloat(rawScale)

        let flipX: CGFloat = config.flipHorizontal ? -1.0 : 1.0
        let flipY: CGFloat = config.flipVertical ? -1.0 : 1.0
        let (pivotY, anchorPinY) = anchorPivotOffsets(anchor: evaluated.anchorPoint, targetHeight: targetH, restingHeight: restH)

        var transform = CGAffineTransform(translationX: -srcSize.width / 2.0, y: -srcSize.height / 2.0)
        transform = transform.concatenating(CGAffineTransform(scaleX: (targetW / srcSize.width) * flipX, y: (targetH / srcSize.height) * flipY))
        if abs(pivotY) > 0.01 {
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: -pivotY))
        }
        if abs(evaluated.skewX) > 0.0005 || abs(evaluated.skewY) > 0.0005 {
            transform = transform.concatenating(CGAffineTransform(a: 1.0, b: CGFloat(evaluated.skewY), c: CGFloat(evaluated.skewX), d: 1.0, tx: 0, ty: 0))
        }
        if abs(evaluated.rotation) > 0.001 {
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(-evaluated.rotation * .pi / 180.0)))
        }
        if abs(pivotY) > 0.01 || abs(anchorPinY) > 0.01 {
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: pivotY + anchorPinY))
        }
        let cx = canvasSize.width / 2.0 + CGFloat(evaluated.positionX)
        let cy = canvasSize.height / 2.0 - CGFloat(evaluated.positionY)
        return transform.concatenating(CGAffineTransform(translationX: cx, y: cy))
    }

    private func anchorPivotOffsets(
        anchor: StickerAnchorPoint,
        targetHeight: CGFloat,
        restingHeight: CGFloat
    ) -> (pivotY: CGFloat, anchorPinY: CGFloat) {
        switch anchor {
        case .center:
            return (0.0, 0.0)
        case .bottom:
            return (-targetHeight * 0.5, (targetHeight - restingHeight) * 0.5)
        case .top:
            return (targetHeight * 0.5, -(targetHeight - restingHeight) * 0.5)
        }
    }

    private func applyAnimationEffects(
        to image: CIImage,
        evaluated: StickerAnimationEvaluator.EvaluationResult,
        canvasRect: CGRect
    ) -> CIImage {
        var result = image
        if evaluated.echoCount > 0 {
            result = compositeEchoTrails(primary: result, evaluated: evaluated)
        }
        if evaluated.glitchIntensity > 0.01 {
            let split = TextShaderFilterEngine.applyRGBSplit(to: result, offset: evaluated.glitchIntensity * 6.0)
            result = TextShaderFilterEngine.applyGlitchSlices(to: split, intensity: evaluated.glitchIntensity * 0.45)
        }
        if evaluated.blurRadius > 0.05 {
            let pad = CGFloat(min(40.0, evaluated.blurRadius * 2.0))
            let blurRect = result.extent.insetBy(dx: -pad, dy: -pad).intersection(canvasRect)
            if !blurRect.isEmpty {
                let clearPad = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: blurRect)
                let padded = result.composited(over: clearPad).cropped(to: blurRect)
                result = TextShaderFilterEngine.applyGaussianBlur(to: padded, radius: evaluated.blurRadius)
            }
        }
        if evaluated.glowIntensity > 0.01 {
            let glowStyle = TextGlowStyle(isEnabled: true, colorHex: "#FFFFFF", intensity: min(100.0, evaluated.glowIntensity * 85.0), range: 14.0)
            let glowExtent = result.extent.insetBy(dx: -28.0, dy: -28.0).intersection(canvasRect)
            if !glowExtent.isEmpty, let glowLayer = TextShaderFilterEngine.renderGlowLayer(from: result, glow: glowStyle, extent: glowExtent) {
                result = result.composited(over: glowLayer)
            }
        }
        return result
    }

    private func compositeEchoTrails(
        primary: CIImage,
        evaluated: StickerAnimationEvaluator.EvaluationResult
    ) -> CIImage {
        var accumulated = primary
        for idx in (1...evaluated.echoCount).reversed() {
            let stepX = CGFloat(-idx) * CGFloat(evaluated.echoOffsetX)
            let stepY = CGFloat(idx) * CGFloat(evaluated.echoOffsetY)
            let shifted = primary.transformed(by: CGAffineTransform(translationX: stepX, y: stepY))
            let ghost = TextSVGAndAssetCache.applyPremultipliedOpacity(0.32 / Double(idx), to: shifted)
            accumulated = accumulated.composited(over: ghost)
        }
        return accumulated
    }

    private func applyDropShadow(
        to image: CIImage,
        config: StickerConfiguration,
        canvasRect: CGRect
    ) -> CIImage {
        #if os(macOS)
        let nsColor = TextAdvancedStyleRenderer.parseHexColor(config.shadowColorHex)
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = srgb.redComponent
        let g = srgb.greenComponent
        let b = srgb.blueComponent
        let a = srgb.alphaComponent
        #else
        let (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0.6)
        #endif

        guard a > 0.01 else { return image }
        var shadow = image
        if let tint = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: shadow,
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: a),
            "inputBiasVector": CIVector(x: r * a, y: g * a, z: b * a, w: 0)
        ])?.outputImage {
            shadow = tint
        }
        if config.shadowBlur > 0.2,
           let blurred = CIFilter(name: "CIGaussianBlur", parameters: [
               kCIInputImageKey: shadow,
               kCIInputRadiusKey: config.shadowBlur
           ])?.outputImage {
            shadow = blurred
        }
        shadow = shadow.transformed(
            by: CGAffineTransform(translationX: CGFloat(config.shadowOffsetX), y: CGFloat(-config.shadowOffsetY))
        ).cropped(to: canvasRect)
        return image.composited(over: shadow)
    }
}
