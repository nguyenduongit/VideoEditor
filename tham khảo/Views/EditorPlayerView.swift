import AppKit
import AVFoundation

final class EditorPlayerView: NSView {
    let playerLayer = AVPlayerLayer()
    var cropPanningEnabled = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    var onCropPanBegan: (() -> Void)?
    var onCropPanChanged: ((CGPoint) -> Void)?
    var onCropPanEnded: (() -> Void)?
    private let guideLayer = CALayer()
    private let topGuideLine = CAShapeLayer()
    private let bottomGuideLine = CAShapeLayer()
    private let zoneHighlight = CALayer()
    private let topBadge = CATextLayer()
    private let bottomBadge = CATextLayer()
    private var lastHipYNorm: Double = 0.55
    private var lastAnkleYNorm: Double = 0.25
    private var lastScaleFactor: Double = 1.0
    private var lastVisible: Bool = false
    private var cropPanStart: CGPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspect
        
        guideLayer.zPosition = 10
        layer?.addSublayer(guideLayer)
        
        zoneHighlight.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.12).cgColor
        guideLayer.addSublayer(zoneHighlight)
        
        topGuideLine.strokeColor = NSColor.systemTeal.cgColor
        guideLayer.addSublayer(topGuideLine)
        
        bottomGuideLine.strokeColor = NSColor.systemOrange.cgColor
        guideLayer.addSublayer(bottomGuideLine)
        
        func styleBadge(_ badge: CATextLayer, color: NSColor) {
            badge.fontSize = 11
            badge.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            badge.foregroundColor = NSColor.white.cgColor
            badge.backgroundColor = color.withAlphaComponent(0.85).cgColor
            badge.cornerRadius = 4
            badge.masksToBounds = true
            badge.alignmentMode = .center
            badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        }
        styleBadge(topBadge, color: .systemTeal)
        styleBadge(bottomBadge, color: .systemOrange)
        guideLayer.addSublayer(topBadge)
        guideLayer.addSublayer(bottomBadge)
        
        guideLayer.isHidden = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        super.resetCursorRects()
        if cropPanningEnabled { addCursorRect(playerLayer.videoRect, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard cropPanningEnabled, playerLayer.videoRect.contains(point) else {
            super.mouseDown(with: event)
            return
        }
        cropPanStart = point
        NSCursor.closedHand.set()
        onCropPanBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = cropPanStart else {
            super.mouseDragged(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        onCropPanChanged?(CGPoint(x: point.x - start.x, y: point.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard cropPanStart != nil else {
            super.mouseUp(with: event)
            return
        }
        cropPanStart = nil
        onCropPanEnded?()
        NSCursor.openHand.set()
    }

    var displayedVideoRect: CGRect { playerLayer.videoRect }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        guideLayer.frame = bounds
        CATransaction.commit()
        if lastVisible { updateLegGuides(hipYNorm: lastHipYNorm, ankleYNorm: lastAnkleYNorm, scaleFactor: lastScaleFactor, visible: true) }
    }
    
    func updateLegGuides(hipYNorm: Double, ankleYNorm: Double, scaleFactor: Double = 1.0, visible: Bool) {
        lastHipYNorm = hipYNorm; lastAnkleYNorm = ankleYNorm; lastScaleFactor = scaleFactor; lastVisible = visible
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guard visible else {
            guideLayer.isHidden = true
            CATransaction.commit()
            return
        }
        let vr = playerLayer.videoRect
        guard vr.width > 10 && vr.height > 10 else {
            guideLayer.isHidden = true
            CATransaction.commit()
            return
        }
        guideLayer.isHidden = false
        
        let presentedHeight = playerLayer.player?.currentItem?.presentationSize.height ?? 0.0
        let pixelHeight = max(3.0, round(presentedHeight > 0.0 ? presentedHeight : vr.height))
        guard let geometry = LegLengtheningService.shared.geometry(
            imageHeight: pixelHeight,
            hipYNorm: hipYNorm,
            ankleYNorm: ankleYNorm,
            scaleFactor: scaleFactor
        ) else {
            guideLayer.isHidden = true
            CATransaction.commit()
            return
        }

        // Một đường đúng một pixel màn hình và nằm giữa hàng pixel nguồn tương ứng.
        let displayScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        guideLayer.contentsScale = displayScale
        topGuideLine.contentsScale = displayScale
        bottomGuideLine.contentsScale = displayScale
        topGuideLine.lineWidth = 1.0 / displayScale
        bottomGuideLine.lineWidth = 1.0 / displayScale
        topGuideLine.lineDashPattern = nil
        bottomGuideLine.lineDashPattern = nil

        func rowCenterY(_ row: CGFloat) -> CGFloat {
            let rawY = vr.minY + ((row + 0.5) / pixelHeight) * vr.height
            return (floor(rawY * displayScale) + 0.5) / displayScale
        }
        let visibleTopRow = min(pixelHeight - 1.0, geometry.upperDestinationRow)
        let topY = rowCenterY(visibleTopRow)
        let botY = rowCenterY(geometry.lowerRow)
        let visibleTopNorm = min(1.0, max(0.0, (geometry.upperDestinationRow + 0.5) / pixelHeight))
        
        let zoneY = vr.minY + ((geometry.lowerRow + 1.0) / pixelHeight) * vr.height
        let zoneTopY = vr.minY + (min(pixelHeight, geometry.upperDestinationRow) / pixelHeight) * vr.height
        let zoneH = max(0.0, zoneTopY - zoneY)
        zoneHighlight.frame = CGRect(x: vr.minX, y: zoneY, width: vr.width, height: zoneH)
        
        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: vr.minX, y: topY))
        topPath.addLine(to: CGPoint(x: vr.maxX, y: topY))
        topGuideLine.path = topPath
        
        if scaleFactor > 1.005 {
            topBadge.string = String(format: " Đường ngang đùi (%.0f%% ➔ %.0f%%) ", hipYNorm * 100, visibleTopNorm * 100)
            topBadge.frame = CGRect(x: vr.minX + 8, y: min(bounds.height - 20, topY + 4), width: 225, height: 18)
        } else {
            topBadge.string = String(format: " Đường ngang đùi (%.0f%%) ", hipYNorm * 100)
            topBadge.frame = CGRect(x: vr.minX + 8, y: min(bounds.height - 20, topY + 4), width: 165, height: 18)
        }
        
        let botPath = CGMutablePath()
        botPath.move(to: CGPoint(x: vr.minX, y: botY))
        botPath.addLine(to: CGPoint(x: vr.maxX, y: botY))
        bottomGuideLine.path = botPath
        bottomBadge.string = String(format: " Đường ngang mắt cá (%.0f%%) ", ankleYNorm * 100)
        bottomBadge.frame = CGRect(x: vr.minX + 8, y: max(2, botY - 22), width: 180, height: 18)
        
        CATransaction.commit()
    }
}

final class CompareButton: ProToolButton {
    var onStateChanged: ((Bool) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onStateChanged?(true)
        super.mouseDown(with: event)
        onStateChanged?(false)
    }
}
