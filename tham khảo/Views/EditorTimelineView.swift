import AppKit

private final class TimelineAccessibilityElement: NSAccessibilityElement {
    var onPress: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        guard let onPress else { return false }
        onPress()
        return true
    }
}
final class EditorTimelineView: NSView {
    var session = EditorSession() { didSet { if session != oldValue { cachedMap = EditorTimeMap(session); waveformDirty = true; needsDisplay = true } } }
    private var cachedMap = EditorTimeMap(EditorSession())
    var editing = false { didSet { needsDisplay = true } }
    var enabled = true
    var peaks: [Float] = [] { didSet { waveformDirty = true; needsDisplay = true } }
    var peakStep = 0.01 { didSet { waveformDirty = true; needsDisplay = true } }
    var playhead = 0.0 { didSet { needsDisplay = true } }
    var selectedBlock: UUID? { didSet { needsDisplay = true } }
    var selectedFade: UUID? { didSet { needsDisplay = true } }
    var selectedVideoEffect: UUID? { didSet { needsDisplay = true } }
    var onSeek: ((Double) -> Void)?
    var onSelection: ((UUID?, UUID?) -> Void)?
    var onBlockChange: ((EditorBlock) -> Void)?
    var onBlockDrop: ((Int) -> Void)?
    var onFadeChange: ((EditorFade) -> Void)?
    var onFadeDrop: ((Int, EditorFadeKind, Int) -> Void)?
    var onVideoEffectSelection: ((UUID?) -> Void)?
    var onVideoEffectChange: ((VideoEffect) -> Void)?
    var onVideoEffectDrop: ((Double, VideoEffectKind, Double) -> Void)?
    var onDelete: (() -> Void)?
    var onZoomWheel: ((CGFloat, NSPoint, Bool) -> Void)?
    var onResetZoom: (() -> Void)?
    private struct Gesture {
        let originalBlock: EditorBlock?
        let originalFade: EditorFade?
        let originalVideoEffect: VideoEffect?
        var block: EditorBlock?
        var fade: EditorFade?
        var videoEffect: VideoEffect?
        let mode: Int // 0: move, 1: left edge, 2: right edge
        let initialPoint: NSPoint
        let initialRect: NSRect
        let grip: NSPoint
        let grid: TimelineSnapGrid
        let timeMap: EditorTimeMap
        let pixelsPerSecond: Double
        var active: Bool
        var valid = false
        /// Rect that tracks the cursor exactly — used as overlay position during drag.
        var liveRect: NSRect
        /// Rect snapped to the nearest beat + lane Y — committed on mouse-up.
        var finalRect: NSRect
    }
    private var gesture: Gesture?
    private var overlay: TimelineDragOverlay?
    private var dragMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var scrollTimer: Timer?
    private var pointerInWindow = NSPoint.zero
    private var settling = false
    private var waveformDirty = true
    private var waveformPath = NSBezierPath()
    private var dimmedWaveformPath = NSBezierPath()
    private var waveformRect = NSRect.zero
    private var waveformSize = NSSize.zero
    var isDraggingBlock: Bool { gesture != nil || settling }
    var activeDragFrame: NSRect? {
        guard let overlay = overlay else { return nil }
        return convert(overlay.bounds, from: overlay)
    }
    var dragPreviewIsValid: Bool { gesture?.valid ?? false }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    deinit {
        if let monitor = dragMonitor { NSEvent.removeMonitor(monitor) }
        if let observer = resignObserver { NotificationCenter.default.removeObserver(observer) }
        scrollTimer?.invalidate()
    }
    var map: EditorTimeMap { cachedMap }
    var scale: Double { max(1, Double(bounds.width - 24)) / max(1, map.duration) }
    private var videoEffectLaneY: CGFloat { 28 }
    private var voiceCountLaneY: CGFloat { max(92, bounds.height - 38) }
    func x(_ output: Double) -> CGFloat { 12 + CGFloat(output * scale) }
    func output(_ x: CGFloat) -> Double { min(map.duration, max(0, Double(x - 12) / scale)) }
    func displayedPeak(_ rawPeak: Float) -> Float {
        min(1.0, max(0.0, rawPeak * Float(session.musicVolume)))
    }
    private func label(_ value: String, _ point: NSPoint, _ color: NSColor = .secondaryLabelColor, size: CGFloat = 10) {
        (value as NSString).draw(at: point, withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular), .foregroundColor: color])
    }
    private func line(_ a: NSPoint, _ b: NSPoint, _ color: NSColor, width: CGFloat = 1) {
        color.setStroke(); let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.lineWidth = width; p.stroke()
    }
    private func blockRect(_ block: EditorBlock) -> NSRect {
        let a = map.outputTime(for: session.beatTime(block.startBeat))
        let b = map.outputTime(for: session.beatTime(block.endBeat), afterHold: false)
        return NSRect(x: x(a), y: voiceCountLaneY, width: max(2, x(b) - x(a)), height: 25)
    }
    private func fadeRect(_ fade: EditorFade) -> NSRect? {
        let spans = map.spans.filter { $0.fadeID == fade.id }
        if let original = session.fades.first(where: { $0.id == fade.id }),
           session.fadeBeat(original) == session.fadeBeat(fade), let first = spans.first {
            let duration = Double(fade.resolvedBeatCount) * 60 / max(1, session.targetBPM)
            return NSRect(x: x(first.start), y: voiceCountLaneY, width: max(2, CGFloat(duration * scale)), height: 25)
        }
        guard let beat = session.fadeBeat(fade) else { return nil }
        return templateFadeRect(beat: beat, beatCount: fade.resolvedBeatCount, kind: fade.resolvedKind)
    }
    private func templateFadeRect(beat: Int, beatCount: Int, kind: EditorFadeKind = .fadeOutIn) -> NSRect {
        let source = min(session.duration, max(0, session.beatTime(beat)))
        let start = map.outputTime(for: source)
        let duration = Double(beatCount) * 60 / max(1, session.targetBPM)
        let w = max(2, CGFloat(duration * scale))
        let originX = kind == .fadeIn ? max(12, x(start) - w) : x(start)
        return NSRect(x: originX, y: voiceCountLaneY, width: w, height: 25)
    }
    private func videoEffectRect(_ effect: VideoEffect) -> NSRect {
        NSRect(x: x(effect.startTime), y: videoEffectLaneY, width: max(2, CGFloat(effect.duration * scale)), height: 25)
    }
    private func drawVideoEffect(_ effect: VideoEffect, rect: NSRect, alpha: CGFloat = 0.68) {
        NSColor.systemOrange.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        let from = effect.kind == .fadeIn ? rect.maxY - 3 : rect.minY + 3
        let to = effect.kind == .fadeIn ? rect.minY + 3 : rect.maxY - 3
        line(NSPoint(x: rect.minX + 3, y: from), NSPoint(x: rect.maxX - 3, y: to), .white, width: 1.5)
        if rect.width >= 62 { label(effect.kind.title, NSPoint(x: rect.minX + 7, y: rect.minY + 5), .white) }
    }
    private func countBlockLabel(_ beatCount: Int, width: CGFloat) -> String {
        if beatCount % 4 == 0 && width >= 105 { return "\(beatCount / 4) nhịp • \(beatCount) phách" }
        return "\(beatCount) phách"
    }
    private func drawFadeBlock(_ rect: NSRect, kind: EditorFadeKind, alpha: CGFloat) {
        NSColor.systemPurple.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        let left = rect.minX + 3, right = rect.maxX - 3
        switch kind {
        case .fadeIn:
            line(NSPoint(x: left, y: rect.maxY - 3), NSPoint(x: right, y: rect.minY + 3), .white, width: 1.5)
        case .fadeOut:
            line(NSPoint(x: left, y: rect.minY + 3), NSPoint(x: right, y: rect.maxY - 3), .white, width: 1.5)
        case .fadeOutIn:
            line(NSPoint(x: left, y: rect.minY + 3), NSPoint(x: rect.midX, y: rect.maxY - 3), .white, width: 1.5)
            line(NSPoint(x: rect.midX, y: rect.maxY - 3), NSPoint(x: right, y: rect.minY + 3), .white, width: 1.5)
        }
    }
    private func formatRulerTime(_ seconds: Double, step: Double) -> String {
        let totalSec = max(0, seconds)
        if step < 0.1 {
            let m = Int(totalSec) / 60
            let s = totalSec.truncatingRemainder(dividingBy: 60)
            return String(format: "%02d:%05.2f", m, s)
        } else if step < 1.0 {
            let m = Int(totalSec) / 60
            let s = totalSec.truncatingRemainder(dividingBy: 60)
            return String(format: "%02d:%04.1f", m, s)
        } else {
            let rounded = Int(round(totalSec))
            let m = rounded / 60
            let s = rounded % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.075, alpha: 1).setFill(); bounds.fill()
        guard session.video != nil else { label("Thêm video và audio để bắt đầu", NSPoint(x: 20, y: 30)); return }
        let visible = visibleRect
        let rulerHeight: CGFloat = 22.0
        let gridBottom = max(rulerHeight, bounds.height - 8)

        let voiceLane = NSRect(x: visible.minX, y: voiceCountLaneY - 3, width: visible.width, height: 31)
        let effectLane = NSRect(x: visible.minX, y: videoEffectLaneY - 3, width: visible.width, height: 31)
        NSColor.systemOrange.withAlphaComponent(0.07).setFill(); effectLane.fill()
        NSColor.systemBlue.withAlphaComponent(0.07).setFill(); voiceLane.fill()
        line(NSPoint(x: visible.minX, y: effectLane.maxY), NSPoint(x: visible.maxX, y: effectLane.maxY), DS.Color.borderSubtle)
        line(NSPoint(x: visible.minX, y: voiceLane.minY), NSPoint(x: visible.maxX, y: voiceLane.minY), DS.Color.borderSubtle)
        label("VOICE COUNT", NSPoint(x: visible.minX + 16, y: voiceCountLaneY + 7), NSColor.systemBlue.withAlphaComponent(0.72), size: 9)
        label("VIDEO EFFECT", NSPoint(x: visible.minX + 16, y: videoEffectLaneY + 7), NSColor.systemOrange.withAlphaComponent(0.78), size: 9)
        
        // ── 1. Beat & Bar Grid on Waveform Lane (Chỉ kẻ nhịp và phách trên waveform) ──
        let sourceA = map.sourceTime(at: output(visible.minX))
        let sourceB = map.sourceTime(at: output(visible.maxX))
        let startBeat = max(session.beat(at: 0), session.beat(at: sourceA) - 2)
        let endBeat = min(session.beat(at: session.duration), session.beat(at: sourceB) + 2)
        let pixelsPerBeat = scale * 60 / session.baseBPM / session.speed
        let pixelsPerBar = pixelsPerBeat * 4
        
        // Tự động điều chỉnh mật độ bước chia nhịp/phách khi zoom
        let beatStep: Int
        if pixelsPerBeat >= 7.0 {
            beatStep = 1 // Hiển thị đầy đủ từng phách
        } else if pixelsPerBar >= 16.0 {
            beatStep = 4 // Chỉ hiển thị vạch nhịp (mỗi 4 phách)
        } else if pixelsPerBar * 4 >= 20.0 {
            beatStep = 16 // Hiển thị mỗi 4 nhịp (16 phách)
        } else {
            beatStep = 32 // Hiển thị mỗi 8 nhịp (32 phách)
        }
        
        if endBeat >= startBeat {
            for beat in stride(from: startBeat, through: endBeat, by: beatStep) {
                let source = session.beatTime(beat)
                guard source >= 0 && source <= session.duration else { continue }
                let px = x(map.outputTime(for: source))
                guard px >= visible.minX - 20 && px <= visible.maxX + 20 else { continue }
                
                let isBar = (beat % 4 == 0)
                let barNumber = beat / 4 + 1
                
                if isBar {
                    // VẠCH NHỊP ĐẬM HƠN (width 1.5, alpha 0.55)
                    line(NSPoint(x: px, y: rulerHeight), NSPoint(x: px, y: gridBottom), NSColor.white.withAlphaComponent(0.55), width: 1.5)
                    
                    // Số nhịp ở đầu vạch nhịp ngay dưới thước thời gian
                    if pixelsPerBar >= 22 {
                        let barAttr: [NSAttributedString.Key: Any] = [
                            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
                            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
                        ]
                        ("\(barNumber)" as NSString).draw(at: NSPoint(x: px + 3, y: rulerHeight + 2), withAttributes: barAttr)
                    }
                } else {
                    // VẠCH PHÁCH MẢNH VÀ MỜ HƠN (width 1.0, alpha 0.15)
                    line(NSPoint(x: px, y: rulerHeight), NSPoint(x: px, y: gridBottom), NSColor.white.withAlphaComponent(0.15), width: 1.0)
                }
            }
        }
        
        // ── 2. Dạng sóng Audio (Waveform) ──────────────────────────────────────
        let audioTop = effectLane.maxY + 5
        let audioBottom = voiceLane.minY - 5
        let center = (audioTop + audioBottom) / 2
        let amplitude = max(8, (audioBottom - audioTop) / 2 - 5)
        let audioLimit = session.effectiveAudioDuration
        let fadeDuration = max(0, session.audioFadeOutDuration)
        let fadeStart = max(0, audioLimit - fadeDuration)
        if !peaks.isEmpty {
            if waveformDirty || waveformRect != visible || waveformSize != bounds.size {
                let path = NSBezierPath()
                let dimmed = NSBezierPath()
                for px in stride(from: max(12, visible.minX), to: min(bounds.width - 12, visible.maxX), by: 2) {
                    let t = output(px)
                    guard let span = map.span(at: t), span.kind == .content else { continue }
                    let source = map.sourceTime(at: t)
                    let index = Int(source / peakStep)
                    let endIndex = min(peaks.count - 1, Int((source + 2 / scale * session.speed) / peakStep))
                    guard index >= 0 && index < peaks.count else { continue }
                    let rawPeak = endIndex >= index ? peaks[index...endIndex].max() ?? 0 : peaks[index]
                    var peak = displayedPeak(rawPeak)
                    
                    if source > audioLimit {
                        // Sau điểm cắt audio: sóng âm bị mờ/tối đi
                        let height = CGFloat(peak * 0.18) * amplitude
                        dimmed.move(to: NSPoint(x: px, y: center - max(0.5, height)))
                        dimmed.line(to: NSPoint(x: px, y: center + max(0.5, height)))
                    } else {
                        // Trước điểm cắt audio: áp dụng dốc âm lượng nếu nằm trong vùng fade out
                        if fadeDuration > 0 && source >= fadeStart {
                            let factor = Float(max(0.0, min(1.0, (audioLimit - source) / fadeDuration)))
                            peak *= factor
                        }
                        let height = CGFloat(peak) * amplitude
                        path.move(to: NSPoint(x: px, y: center - height)); path.line(to: NSPoint(x: px, y: center + height))
                    }
                }
                waveformPath = path; dimmedWaveformPath = dimmed; waveformRect = visible; waveformSize = bounds.size; waveformDirty = false
            }
            NSColor.systemTeal.setStroke(); waveformPath.lineWidth = 1; waveformPath.stroke()
            if !dimmedWaveformPath.isEmpty {
                NSColor.systemGray.withAlphaComponent(0.32).setStroke()
                dimmedWaveformPath.lineWidth = 1
                dimmedWaveformPath.stroke()
            }
            
            // Vẽ đường bao trực quan của hiệu ứng Fade Out
            if fadeDuration > 0 && audioLimit > 0 {
                let xFadeStart = x(map.outputTime(for: fadeStart, afterHold: false))
                let xAudioEnd = x(map.outputTime(for: audioLimit, afterHold: false))
                if xAudioEnd > xFadeStart + 4 && xAudioEnd >= visible.minX && xFadeStart <= visible.maxX {
                    let fadeGuide = NSBezierPath()
                    fadeGuide.move(to: NSPoint(x: xFadeStart, y: center - amplitude * 0.85))
                    fadeGuide.curve(to: NSPoint(x: xAudioEnd, y: center),
                                    controlPoint1: NSPoint(x: xFadeStart + (xAudioEnd - xFadeStart) * 0.5, y: center - amplitude * 0.6),
                                    controlPoint2: NSPoint(x: xAudioEnd - (xAudioEnd - xFadeStart) * 0.2, y: center - amplitude * 0.1))
                    fadeGuide.curve(to: NSPoint(x: xFadeStart, y: center + amplitude * 0.85),
                                    controlPoint1: NSPoint(x: xAudioEnd - (xAudioEnd - xFadeStart) * 0.2, y: center + amplitude * 0.1),
                                    controlPoint2: NSPoint(x: xFadeStart + (xAudioEnd - xFadeStart) * 0.5, y: center + amplitude * 0.6))
                    NSColor.systemOrange.withAlphaComponent(0.35).setStroke()
                    fadeGuide.lineWidth = 1.2
                    let pattern: [CGFloat] = [3, 2]
                    fadeGuide.setLineDash(pattern, count: 2, phase: 0)
                    fadeGuide.stroke()
                }
            }
        } else {
            label(session.match == nil ? "AUDIO · Chưa đồng bộ audio ngoài" : "AUDIO · Đang chuẩn bị dạng sóng…", NSPoint(x: visible.minX + 20, y: center - 6))
        }
        for span in map.spans where span.kind != .content {
            line(NSPoint(x: x(span.start), y: center), NSPoint(x: x(span.end), y: center), NSColor.systemPurple.withAlphaComponent(0.75))
        }
        
        // ── 3. Track Voice Count ────────────────────────────────────────────────
        for block in session.blocks {
            if gesture?.active == true && gesture?.originalBlock?.id == block.id { continue }
            let b = block
            let rect = blockRect(b)
            NSColor.systemBlue.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            label(countBlockLabel(b.beatCount, width: rect.width), NSPoint(x: rect.minX + 8, y: rect.minY + 5), .white)
            if selectedBlock == b.id { NSColor.systemBlue.setStroke(); NSBezierPath(rect: rect).stroke() }
        }
        // Fade của Voice Count nằm cùng track với các count block.
        for fade in session.fades {
            if gesture?.active == true && gesture?.originalFade?.id == fade.id { continue }
            let f = fade
            guard let rect = fadeRect(f) else { continue }
            drawFadeBlock(rect, kind: f.resolvedKind, alpha: 0.62)
            if selectedFade == f.id { NSColor.white.setStroke(); NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).stroke() }
        }
        for effect in session.videoEffects {
            if gesture?.active == true && gesture?.originalVideoEffect?.id == effect.id { continue }
            let rect = videoEffectRect(effect)
            drawVideoEffect(effect, rect: rect)
            if selectedVideoEffect == effect.id { NSColor.white.setStroke(); NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).stroke() }
        }
        
        // ── 5. Thước thời gian (Time Ruler - Chỉ hiển thị gọn phía trên thước) ──
        let rulerRect = NSRect(x: visible.minX, y: 0, width: visible.width, height: rulerHeight)
        DS.Color.panelBg.setFill()
        rulerRect.fill()
        line(NSPoint(x: visible.minX, y: rulerHeight), NSPoint(x: visible.maxX, y: rulerHeight), DS.Color.borderSubtle, width: 1)
        
        let standardSteps: [Double] = [
            0.01, 0.02, 0.05,
            0.1, 0.2, 0.25, 0.5,
            1.0, 2.0, 5.0, 10.0, 15.0, 30.0,
            60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0
        ]
        let majorStep: Double = standardSteps.first(where: { $0 * scale >= 65.0 }) ?? standardSteps.last!
        let minorSubdivisions: Int
        if majorStep == 60 || majorStep == 300 || majorStep == 600 || majorStep == 1800 || majorStep == 3600 {
            minorSubdivisions = 6
        } else if majorStep == 0.2 || majorStep == 2.0 || majorStep == 20.0 || majorStep == 120.0 {
            minorSubdivisions = 4
        } else if majorStep == 0.25 {
            minorSubdivisions = 5
        } else {
            minorSubdivisions = 5
        }
        let minorStep = majorStep / Double(minorSubdivisions)
        let drawMinor = (minorStep * scale >= 7.0)
        
        let tStart = max(0, floor(output(visible.minX) / majorStep) * majorStep)
        let tEnd = min(map.duration, ceil(output(visible.maxX) / majorStep) * majorStep)
        
        for majorTime in stride(from: tStart, through: tEnd, by: majorStep) {
            let px = x(majorTime)
            if px >= visible.minX - 30 && px <= visible.maxX + 30 {
                // Vạch chia chính: Chỉ nằm trong thước (y: 12 đến 22)
                line(NSPoint(x: px, y: 12), NSPoint(x: px, y: rulerHeight), NSColor.white.withAlphaComponent(0.40), width: 1)
                // Nhãn thời gian
                let timeStr = formatRulerTime(majorTime, step: majorStep)
                label(timeStr, NSPoint(x: px + 3, y: 2), DS.Color.textSecondary, size: 9.5)
            }
            if drawMinor {
                for sub in 1..<minorSubdivisions {
                    let minorTime = majorTime + Double(sub) * minorStep
                    guard minorTime <= map.duration else { break }
                    let mpx = x(minorTime)
                    if mpx >= visible.minX && mpx <= visible.maxX {
                        // Vạch chia phụ: Chỉ nằm trong thước (y: 16 đến 22)
                        line(NSPoint(x: mpx, y: 16), NSPoint(x: mpx, y: rulerHeight), NSColor.white.withAlphaComponent(0.18), width: 1)
                    }
                }
            }
        }
        
        // ── 5. Trim Markers (Vạch cắt Audio & Video) ───────────────────────────
        if session.audioTrimEnd != nil || audioLimit < session.duration - 0.05 {
            let audioEndX = x(map.outputTime(for: audioLimit, afterHold: false))
            if audioEndX >= visible.minX - 35 && audioEndX <= visible.maxX + 35 {
                line(NSPoint(x: audioEndX, y: rulerHeight), NSPoint(x: audioEndX, y: bounds.height), NSColor.systemOrange.withAlphaComponent(0.9), width: 1.5)
                let tagW: CGFloat = 62, tagH: CGFloat = 15
                let tagRect = NSRect(x: audioEndX - tagW / 2, y: rulerHeight + 2, width: tagW, height: tagH)
                NSColor.systemOrange.withAlphaComponent(0.92).setFill()
                NSBezierPath(roundedRect: tagRect, xRadius: 3, yRadius: 3).fill()
                let pStyle = NSMutableParagraphStyle()
                pStyle.alignment = .center
                ("Audio End" as NSString).draw(in: NSRect(x: tagRect.minX, y: tagRect.minY + 1.5, width: tagRect.width, height: tagRect.height - 1), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                    .foregroundColor: NSColor.white,
                    .paragraphStyle: pStyle
                ])
            }
        }
        
        if session.videoTrimEnd != nil {
            let videoEndX = x(map.duration)
            if videoEndX >= visible.minX - 35 && videoEndX <= visible.maxX + 35 {
                line(NSPoint(x: videoEndX, y: 0), NSPoint(x: videoEndX, y: bounds.height), NSColor.systemPurple.withAlphaComponent(0.9), width: 1.5)
                let tagW: CGFloat = 62, tagH: CGFloat = 15
                let tagRect = NSRect(x: videoEndX - tagW / 2, y: 3, width: tagW, height: tagH)
                NSColor.systemPurple.withAlphaComponent(0.92).setFill()
                NSBezierPath(roundedRect: tagRect, xRadius: 3, yRadius: 3).fill()
                let pStyle = NSMutableParagraphStyle()
                pStyle.alignment = .center
                ("Video End" as NSString).draw(in: NSRect(x: tagRect.minX, y: tagRect.minY + 1.5, width: tagRect.width, height: tagRect.height - 1), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                    .foregroundColor: NSColor.white,
                    .paragraphStyle: pStyle
                ])
            }
        }
        
        // ── 6. Playhead ────────────────────────────────────────────────────────
        let playheadX = x(playhead)
        line(NSPoint(x: playheadX, y: 0), NSPoint(x: playheadX, y: bounds.height), .systemRed, width: 2)
        let indicator = NSBezierPath()
        indicator.move(to: NSPoint(x: playheadX - 5, y: 0))
        indicator.line(to: NSPoint(x: playheadX + 5, y: 0))
        indicator.line(to: NSPoint(x: playheadX + 5, y: 9))
        indicator.line(to: NSPoint(x: playheadX, y: 15))
        indicator.line(to: NSPoint(x: playheadX - 5, y: 9))
        indicator.close()
        NSColor.systemRed.setFill()
        indicator.fill()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let delta = event.scrollingDeltaY
            if abs(delta) > 0.001 {
                let point = convert(event.locationInWindow, from: nil)
                onZoomWheel?(delta, point, event.hasPreciseScrollingDeltas)
            }
            return
        }
        super.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        if abs(event.magnification) > 0.001 {
            let point = convert(event.locationInWindow, from: nil)
            onZoomWheel?(event.magnification * 80.0, point, true)
        }
    }
    func beginTemplateDrag(kind: EditorFadeKind?, beatCount: Int, event: NSEvent) {
        guard enabled && editing && !isDraggingBlock else { return }
        let point = convert(event.locationInWindow, from: nil)
        let rect = NSRect(x: point.x - 12, y: point.y - 12.5,
                          width: CGFloat(Double(beatCount) * 60 / session.targetBPM * scale), height: 25)
        let block = kind == nil ? EditorBlock(startBeat: 0, beatCount: beatCount) : nil
        let fade = kind.map { EditorFade(startBeat: 0, beatCount: beatCount, kind: $0) }
        startGesture(block: block, fade: fade, videoEffect: nil, original: false, rect: rect, mode: 0, point: point)
        updateGesture(at: event.locationInWindow)
    }
    func beginVideoEffectTemplateDrag(kind: VideoEffectKind, duration: Double = 1.0, event: NSEvent) {
        guard enabled && editing && !isDraggingBlock else { return }
        let point = convert(event.locationInWindow, from: nil)
        let effect = VideoEffect(startTime: 0, duration: duration, kind: kind)
        let rect = NSRect(x: point.x - 12, y: point.y - 12.5, width: max(10, CGFloat(duration * scale)), height: 25)
        startGesture(block: nil, fade: nil, videoEffect: effect, original: false, rect: rect, mode: 0, point: point)
        updateGesture(at: event.locationInWindow)
    }

    private func startGesture(block: EditorBlock?, fade: EditorFade?, videoEffect: VideoEffect?, original: Bool, rect: NSRect, mode: Int, point: NSPoint) {
        // Build a session without the dragged fade so the snap grid never has a point
        // at the fade's current beat (which would create a "sticky" snap there).
        var snapSession = session
        if original, let fade = fade { snapSession.fades.removeAll { $0.id == fade.id } }
        let snapMap = EditorTimeMap(snapSession)
        // ⚠️ Snap grid MUST use cachedMap (original map) for X positions, not snapMap.
        //    rawLeft is a pixel position in the original-map's coordinate space (the same
        //    space the view draws beat lines in). snapMap omits the fade's hold span, so
        //    beats after the fade's original position are shifted left by fadeDuration*pps
        //    in snap-map space — causing nearest() to return the wrong beat and the block
        //    to jump by exactly beatCount beats on release.
        //    state.timeMap = snapMap is kept for finalRect.x, which correctly represents
        //    the committed output position (snap map ≈ new map after fade is moved).
        gesture = Gesture(originalBlock: original ? block : nil, originalFade: original ? fade : nil, originalVideoEffect: original ? videoEffect : nil,
                          block: block, fade: fade, videoEffect: videoEffect, mode: mode, initialPoint: point, initialRect: rect,
                          grip: NSPoint(x: point.x - rect.minX, y: point.y - rect.minY),
                          grid: TimelineSnapGrid(session: snapSession, map: snapMap, pixelsPerSecond: scale),
                          timeMap: snapMap, pixelsPerSecond: scale, active: !original,
                          liveRect: rect, finalRect: rect)
        pointerInWindow = convert(point, to: nil)
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp, .keyDown]) { [weak self] event in
            guard let self = self, self.gesture != nil else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.cancelGesture() }
                return nil
            }
            if event.type == .leftMouseUp { self.finishGesture(at: event.locationInWindow) }
            else { self.updateGesture(at: event.locationInWindow) }
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.cancelGesture() }
        // 1/120 s gives smoother auto-scroll on ProMotion displays while costing nothing
        // extra on 60 Hz panels (the body executes the same number of effective scroll steps).
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.scrollDuringDrag() }
        RunLoop.main.add(timer, forMode: .common); scrollTimer = timer
    }

    override func mouseDown(with event: NSEvent) {
        guard enabled && !isDraggingBlock else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if editing {
            if let effect = session.videoEffects.first(where: { videoEffectRect($0).insetBy(dx: -3, dy: -3).contains(point) }) {
                selectedVideoEffect = effect.id; selectedBlock = nil; selectedFade = nil; onVideoEffectSelection?(effect.id)
                let rect = videoEffectRect(effect)
                let mode = point.x - rect.minX < min(7, rect.width / 4) ? 1 : (rect.maxX - point.x < min(7, rect.width / 4) ? 2 : 0)
                startGesture(block: nil, fade: nil, videoEffect: effect, original: true, rect: rect, mode: mode, point: point)
                return
            }
            if let fade = session.fades.first(where: { fadeRect($0)?.insetBy(dx: -3, dy: -3).contains(point) == true }), let rect = fadeRect(fade) {
                selectedFade = fade.id; selectedBlock = nil; selectedVideoEffect = nil; onSelection?(nil, fade.id)
                if event.clickCount == 2 {
                    var reset = fade; reset.beatCount = fade.resolvedKind.defaultBeatCount
                    if session.accepts(reset) { onFadeChange?(reset) }; return
                }
                let mode = point.x - rect.minX < min(7, rect.width / 4) ? 1 : (rect.maxX - point.x < min(7, rect.width / 4) ? 2 : 0)
                startGesture(block: nil, fade: fade, videoEffect: nil, original: true, rect: rect, mode: mode, point: point)
                return
            }
            if let block = session.blocks.first(where: { blockRect($0).insetBy(dx: -3, dy: -3).contains(point) }) {
                selectedBlock = block.id; selectedFade = nil; selectedVideoEffect = nil; onSelection?(block.id, nil)
                if event.clickCount == 2 {
                    var reset = block; reset.beatCount = 32
                    if session.accepts(reset) { onBlockChange?(reset) }; return
                }
                let rect = blockRect(block)
                let mode = point.x - rect.minX < min(7, rect.width / 4) ? 1 : (rect.maxX - point.x < min(7, rect.width / 4) ? 2 : 0)
                startGesture(block: block, fade: nil, videoEffect: nil, original: true, rect: rect, mode: mode, point: point)
                return
            }
        }
        selectedBlock = nil; selectedFade = nil; selectedVideoEffect = nil; onSelection?(nil, nil); onVideoEffectSelection?(nil); onSeek?(output(point.x))
    }

    override func mouseDragged(with event: NSEvent) {
        if gesture != nil { updateGesture(at: event.locationInWindow) }
        else if enabled { onSeek?(output(convert(event.locationInWindow, from: nil).x)) }
    }
    override func mouseUp(with event: NSEvent) { finishGesture(at: event.locationInWindow) }

    private func updateGesture(at windowPoint: NSPoint) {
        guard var state = gesture else { return }
        pointerInWindow = windowPoint
        let point = convert(windowPoint, from: nil)
        if !state.active {
            // 4 px dead-zone prevents accidental micro-drags on a click.
            guard hypot(point.x - state.initialPoint.x, point.y - state.initialPoint.y) >= 4 else { return }
            state.active = true; needsDisplay = true
        }
        let withinTimeline = visibleRect.contains(point)
        let withinVideoEffectLaneY = point.y >= videoEffectLaneY - 8 && point.y <= videoEffectLaneY + 33
        let originalEffectPinnedToEnd = state.originalVideoEffect.map { abs($0.endTime - map.duration) < 0.051 } ?? false
        let extendingPinnedEffectPastView = originalEffectPinnedToEnd && state.mode == 2 && point.x >= state.initialPoint.x
        let withinVideoEffectLane = withinVideoEffectLaneY && (withinTimeline || extendingPinnedEffectPastView)
        let laneY = state.videoEffect == nil ? voiceCountLaneY : videoEffectLaneY
        let rawLeft = point.x - state.grip.x

        if state.mode == 0 {
            // ── Move ──────────────────────────────────────────────────────────────
            // liveRect bám sát con trỏ pixel-perfect.
            // finalRect snap vào beat gần nhất — chỉ được commit khi thả chuột.
            if var effect = state.originalVideoEffect ?? state.videoEffect {
                effect.startTime = session.snappedVideoEffectStart(output(rawLeft), duration: effect.duration)
                state.videoEffect = effect
                state.valid = withinVideoEffectLane && session.accepts(effect)
                let w = max(2, CGFloat(effect.duration * state.pixelsPerSecond))
                state.finalRect = NSRect(x: 12 + CGFloat(effect.startTime * state.pixelsPerSecond), y: laneY, width: w, height: 25)
                state.liveRect = NSRect(x: rawLeft, y: point.y - state.grip.y, width: w, height: 25)
            } else if var block = state.originalBlock ?? state.block {
                // Blocks: rawLeft is already in the correct coordinate space
                // (blocks create no hold spans, so snapMap ≈ cachedMap for block drags).
                guard let snapped = state.grid.nearest(to: rawLeft) else { return }
                block.startBeat = snapped.beat
                state.block = block
                state.valid = withinTimeline && session.accepts(block)
                let start = state.timeMap.outputTime(for: session.beatTime(block.startBeat))
                let end   = state.timeMap.outputTime(for: session.beatTime(block.endBeat), afterHold: false)
                let w = max(2, CGFloat((end - start) * state.pixelsPerSecond))
                state.finalRect = NSRect(x: 12 + CGFloat(start * state.pixelsPerSecond), y: laneY, width: w, height: 25)
                state.liveRect  = NSRect(x: rawLeft, y: point.y - state.grip.y, width: w, height: 25)
            } else if var fade = state.originalFade ?? state.fade {
                let isFadeIn = fade.resolvedKind == .fadeIn
                let w = max(2, CGFloat(Double(max(1, fade.beatCount ?? 1)) * 60 / session.targetBPM * state.pixelsPerSecond))
                // Fades: convert snapping edge from original-map pixel space to snap-map space.
                // For fadeIn, the primary anchor is its RIGHT edge (leads into the beat / count block).
                // For fadeOut and fadeOutIn, the primary anchor is its LEFT edge.
                let rawSnapEdge = isFadeIn ? rawLeft + w : rawLeft
                let rawOutput = Double(rawSnapEdge - 12) / state.pixelsPerSecond
                let sourceAtRaw = map.sourceTime(at: rawOutput)
                let snapOutput = state.timeMap.outputTime(for: sourceAtRaw)
                let snappableEdge = 12 + CGFloat(snapOutput * state.pixelsPerSecond)
                guard let snapped = state.grid.nearest(to: snappableEdge) else { return }
                fade.startBeat = snapped.beat
                state.fade = fade
                state.valid = withinTimeline && (fade.beatCount ?? 0) >= 1 && session.accepts(fade)
                let beat = session.fadeBeat(fade) ?? 0
                let source = min(session.duration, max(0, session.beatTime(beat)))
                let snapX = 12 + CGFloat(state.timeMap.outputTime(for: source) * state.pixelsPerSecond)
                let finalX = isFadeIn ? max(12, snapX - w) : snapX
                state.finalRect = NSRect(x: finalX, y: laneY, width: w, height: 25)
                state.liveRect  = NSRect(x: rawLeft, y: point.y - state.grip.y, width: w, height: 25)
            }
        } else {
            // ── Resize edge ───────────────────────────────────────────────────────
            // Snap xảy ra ngay lập tức để phản hồi tức thì; liveRect == finalRect.
            let edge = (state.mode == 1 ? state.initialRect.minX : state.initialRect.maxX)
                     + point.x - state.initialPoint.x
            guard let snapped = state.grid.nearest(to: edge) else { return }
            var resizedRect = state.initialRect
            if let originalEffect = state.originalVideoEffect ?? state.videoEffect {
                var effect = originalEffect
                let delta = Double(point.x - state.initialPoint.x) / state.pixelsPerSecond
                if state.mode == 1 {
                    let end = originalEffect.endTime
                    effect.startTime = ((originalEffect.startTime + delta) * 10).rounded() / 10
                    effect.startTime = max(0, min(end - 0.1, effect.startTime))
                    // Giữ cạnh phải chính xác, kể cả khi cuối timeline có phần lẻ < 0,1s.
                    effect.duration = end - effect.startTime
                } else {
                    if originalEffectPinnedToEnd && delta > 0 {
                        // Cạnh phải không còn chỗ để đi tiếp: tăng duration về bên trái
                        // và giữ điểm kết thúc khóa ở cuối timeline.
                        effect.duration = min(map.duration, max(0.1, (originalEffect.duration + delta) * 10).rounded() / 10)
                        effect.startTime = map.duration - effect.duration
                    } else {
                        let available = map.duration - effect.startTime
                        let proposed = originalEffect.duration + delta
                        effect.duration = proposed >= available - 0.05
                            ? available
                            : (proposed * 10).rounded() / 10
                        effect.duration = max(0.1, min(available, effect.duration))
                    }
                }
                state.videoEffect = effect
                state.valid = withinVideoEffectLane && session.accepts(effect)
                resizedRect.origin.x = 12 + CGFloat(effect.startTime * state.pixelsPerSecond)
                resizedRect.size.width = max(2, CGFloat(effect.duration * state.pixelsPerSecond))
            } else if let originalBlock = state.originalBlock ?? state.block {
                var block = originalBlock
                if state.mode == 1 {
                    block.startBeat = snapped.beat
                    block.beatCount = originalBlock.endBeat - snapped.beat
                } else {
                    block.beatCount = snapped.beat - block.startBeat
                }
                state.block = block
                state.valid = withinTimeline && session.accepts(block)
                let start = state.timeMap.outputTime(for: session.beatTime(block.startBeat))
                let end   = state.timeMap.outputTime(for: session.beatTime(block.endBeat), afterHold: false)
                resizedRect.origin.x   = 12 + CGFloat(start * state.pixelsPerSecond)
                resizedRect.size.width = max(2, CGFloat((end - start) * state.pixelsPerSecond))
            } else if var fade = state.originalFade ?? state.fade {
                let isFadeIn = fade.resolvedKind == .fadeIn
                let originalBeat = session.fadeBeat(fade) ?? 0
                if state.mode == 1 {
                    if isFadeIn {
                        fade.beatCount = max(1, originalBeat - snapped.beat)
                    } else {
                        fade.startBeat = snapped.beat
                        fade.beatCount = fade.resolvedBeatCount + originalBeat - snapped.beat
                    }
                } else {
                    if isFadeIn {
                        fade.startBeat = snapped.beat
                    } else {
                        // Do not clamp to the old timeline end when extending the last fade.
                        let delta = Int(((point.x - state.initialPoint.x)
                            / CGFloat(state.pixelsPerSecond) * session.targetBPM / 60).rounded())
                        fade.beatCount = fade.resolvedBeatCount + delta
                    }
                }
                state.fade = fade
                state.valid = withinTimeline && (fade.beatCount ?? 0) >= 1 && session.accepts(fade)
                // Same source-time clamping as templateFadeRect.
                let fadeBeatVal = session.fadeBeat(fade) ?? 0
                let fadeSource = min(session.duration, max(0, session.beatTime(fadeBeatVal)))
                let snapX = 12 + CGFloat(state.timeMap.outputTime(for: fadeSource) * state.pixelsPerSecond)
                let w = max(2, CGFloat(Double(max(1, fade.beatCount ?? 1)) * 60 / session.targetBPM * state.pixelsPerSecond))
                let finalX = isFadeIn ? max(12, snapX - w) : snapX
                resizedRect.origin.x   = finalX
                resizedRect.size.width = w
            }
            let snappedRect = NSRect(x: resizedRect.origin.x, y: laneY, width: resizedRect.width, height: 25)
            state.finalRect = snappedRect
            state.liveRect  = snappedRect
        }

        gesture = state
        showOverlay(state: state)
    }

    private func showOverlay(state: Gesture) {
        guard let root = window?.contentView else { return }
        if overlay == nil {
            let visual = TimelineDragOverlay(frame: .zero)
            visual.wantsLayer = true
            root.addSubview(visual, positioned: .above, relativeTo: nil)
            overlay = visual
        }
        guard let visual = overlay else { return }
        // Disable implicit Core Animation transitions so the overlay tracks the pointer
        // at exactly the display refresh rate with zero artificial lag.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visual.frame = convert(state.liveRect, to: root)
        CATransaction.commit()
        let count = state.block?.beatCount ?? state.fade?.resolvedBeatCount ?? 1
        let snapOffsetX = state.finalRect.minX - state.liveRect.minX
        if visual.kind != state.fade?.resolvedKind || visual.videoEffectKind != state.videoEffect?.kind || visual.beatCount != count
            || visual.valid != state.valid || abs(visual.snapOffsetX - snapOffsetX) > 0.5 {
            visual.kind = state.fade?.resolvedKind
            visual.videoEffectKind = state.videoEffect?.kind
            visual.beatCount = count
            visual.valid = state.valid
            visual.snapOffsetX = snapOffsetX
            visual.needsDisplay = true
        }
    }

    private func scrollDuringDrag() {
        guard let state = gesture, state.active, let scroll = enclosingScrollView else { return }
        let point = convert(pointerInWindow, from: nil)
        let visible = visibleRect
        guard point.y >= visible.minY - 24 && point.y <= visible.maxY + 24 else { return }
        let zone: CGFloat = 44
        let left = max(0, min(1, (visible.minX + zone - point.x) / zone))
        let right = max(0, min(1, (point.x - visible.maxX + zone) / zone))
        let delta = (right * right - left * left) * 14
        let target = max(0, min(bounds.width - visible.width, visible.minX + delta))
        guard abs(target - visible.minX) > 0.01 else { return }
        scroll.contentView.scroll(to: NSPoint(x: target, y: visible.minY))
        scroll.reflectScrolledClipView(scroll.contentView)
        updateGesture(at: pointerInWindow)
    }

    private func stopTracking() {
        if let monitor = dragMonitor { NSEvent.removeMonitor(monitor); dragMonitor = nil }
        if let observer = resignObserver { NotificationCenter.default.removeObserver(observer); resignObserver = nil }
        scrollTimer?.invalidate(); scrollTimer = nil
    }
    func cancelGesture() {
        guard !settling else { return }
        stopTracking(); overlay?.removeFromSuperview(); overlay = nil; gesture = nil; needsDisplay = true
    }
    private func finishGesture(at point: NSPoint) {
        guard gesture != nil, !settling else { return }
        updateGesture(at: point)
        guard let state = gesture, state.active && state.valid else { cancelGesture(); return }
        stopTracking(); settling = true
        let commit: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.overlay?.removeFromSuperview(); self.overlay = nil
            self.gesture = nil; self.settling = false
            if let effect = state.videoEffect {
                if state.originalVideoEffect == nil { self.onVideoEffectDrop?(effect.startTime, effect.kind, effect.duration) }
                else if effect != state.originalVideoEffect { self.onVideoEffectChange?(effect) }
            } else if let block = state.block {
                if state.originalBlock == nil { self.onBlockDrop?(block.startBeat) }
                else if block != state.originalBlock { self.onBlockChange?(block) }
            } else if let fade = state.fade, let beat = self.session.fadeBeat(fade) {
                if state.originalFade == nil { self.onFadeDrop?(beat, fade.resolvedKind, fade.resolvedBeatCount) }
                else if fade != state.originalFade { self.onFadeChange?(fade) }
            }
            self.needsDisplay = true
        }
        if let visual = overlay, let root = visual.superview {
            // Clear snap indicator before the settling animation so the overlay
            // looks clean while flying into the lane.
            visual.snapOffsetX = 0; visual.needsDisplay = true
            let targetFrame  = convert(state.finalRect, to: root)
            let currentFrame = visual.frame
            // Travel distance in points — used to scale animation duration so a
            // tiny 2 px nudge feels snappy while a cross-lane drop still reads as motion.
            let dist = hypot(targetFrame.midX - currentFrame.midX,
                             targetFrame.midY - currentFrame.midY)
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && dist > 0.5 else {
                CATransaction.begin(); CATransaction.setDisableActions(true)
                visual.frame = targetFrame; CATransaction.commit()
                commit(); return
            }
            NSAnimationContext.runAnimationGroup({ ctx in
                // Duration: 80 ms base, +1 ms per 10 pts of travel, capped at 180 ms.
                ctx.duration = min(0.18, max(0.08, dist / 1000))
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = false
                visual.animator().frame = targetFrame
            }, completionHandler: commit)
        } else { commit() }
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && gesture != nil { cancelGesture() }
        else if enabled && editing && (event.keyCode == 51 || event.keyCode == 117) { onDelete?() }
        else if (event.keyCode == 6 || event.charactersIgnoringModifiers?.lowercased() == "z") &&
                event.modifierFlags.intersection([.command, .option, .control, .shift]) == .shift {
            onResetZoom?()
        }
        else if enabled && event.keyCode == 123 { // Left arrow: seek backward
            let step = event.modifierFlags.contains(.option) ? 1.0 : 0.25
            onSeek?(max(0, playhead - step))
        }
        else if enabled && event.keyCode == 124 { // Right arrow: seek forward
            let step = event.modifierFlags.contains(.option) ? 1.0 : 0.25
            onSeek?(min(session.duration, playhead + step))
        }
        else if enabled && event.keyCode == 115 { // Home: seek to start
            onSeek?(0)
        }
        else if enabled && event.keyCode == 119 { // End: seek to end
            onSeek?(session.duration)
        }
        else if enabled && editing && event.keyCode == 48 { // Tab: cycle block/fade selection
            let allItems: [(blockId: UUID?, fadeId: UUID?)] = session.blocks.map { ($0.id, nil) } + session.fades.map { (nil, $0.id) }
            if !allItems.isEmpty {
                let currentIdx = allItems.firstIndex { $0.blockId == selectedBlock && $0.fadeId == selectedFade } ?? -1
                let nextIdx: Int
                if event.modifierFlags.contains(.shift) {
                    nextIdx = currentIdx <= 0 ? allItems.count - 1 : currentIdx - 1
                } else {
                    nextIdx = (currentIdx + 1) % allItems.count
                }
                onSelection?(allItems[nextIdx].blockId, allItems[nextIdx].fadeId)
            }
        }
        else { super.keyDown(with: event) }
    }
    override func resetCursorRects() {
        guard enabled && editing else { return }
        let rects = session.blocks.map(blockRect) + session.fades.compactMap(fadeRect) + session.videoEffects.map(videoEffectRect)
        for rect in rects {
            addCursorRect(rect, cursor: .openHand)
            let width = min(7, rect.width / 4)
            addCursorRect(NSRect(x: rect.minX, y: rect.minY, width: width, height: rect.height), cursor: .resizeLeftRight)
            addCursorRect(NSRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height), cursor: .resizeLeftRight)
        }
    }

    // MARK: - Accessibility
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .layoutArea }
    override func accessibilityLabel() -> String? { "Dòng thời gian chỉnh sửa video" }
    override func accessibilityChildren() -> [Any]? {
        guard enabled && editing else { return [] }
        var elements: [NSAccessibilityElement] = []
        for block in session.blocks {
            let el = TimelineAccessibilityElement()
            el.setAccessibilityParent(self)
            el.setAccessibilityRole(.button)
            el.setAccessibilityLabel("Đoạn giữ nhịp \(block.startBeat), độ dài \(block.beatCount) nhịp")
            el.setAccessibilityValue("\(block.beatCount) nhịp")
            let rect = blockRect(block)
            if let win = window {
                el.setAccessibilityFrame(win.convertToScreen(convert(rect, to: nil)))
            }
            el.onPress = { [weak self] in self?.onSelection?(block.id, nil) }
            elements.append(el)
        }
        for fade in session.fades {
            let el = TimelineAccessibilityElement()
            el.setAccessibilityParent(self)
            el.setAccessibilityRole(.button)
            let beatStr = session.fadeBeat(fade).map { "\($0)" } ?? "?"
            let kindStr = fade.resolvedKind.title
            el.setAccessibilityLabel("Hiệu ứng \(kindStr) tại nhịp \(beatStr), độ dài \(fade.resolvedBeatCount) nhịp")
            el.setAccessibilityValue("\(fade.resolvedBeatCount) nhịp")
            if let rect = fadeRect(fade), let win = window {
                el.setAccessibilityFrame(win.convertToScreen(convert(rect, to: nil)))
            }
            el.onPress = { [weak self] in self?.onSelection?(nil, fade.id) }
            elements.append(el)
        }
        for effect in session.videoEffects {
            let el = TimelineAccessibilityElement()
            el.setAccessibilityParent(self); el.setAccessibilityRole(.button)
            el.setAccessibilityLabel("Hiệu ứng video \(effect.kind.title) tại \(String(format: "%.1f", effect.startTime)) giây")
            el.setAccessibilityValue("\(String(format: "%.1f", effect.duration)) giây")
            if let win = window { el.setAccessibilityFrame(win.convertToScreen(convert(videoEffectRect(effect), to: nil))) }
            el.onPress = { [weak self] in self?.onVideoEffectSelection?(effect.id) }
            elements.append(el)
        }
        return elements
    }
}
