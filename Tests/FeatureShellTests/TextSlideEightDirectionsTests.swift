import Foundation
import CoreGraphics
import CoreImage
import AppKit
import SwiftUI
import Testing
@testable import Domain
@testable import FeatureShell

@Suite("Eight-Direction Slide Text Animations & Hover Preview")
@MainActor
struct TextSlideEightDirectionsTests {
    private let canvasSize = CGSize(width: 1280, height: 720)

    private static let expectedOrder: [String] = [
        "slide_up_up",
        "slide_down_down",
        "slide_up_down",
        "slide_down_up",
        "slide_left_left",
        "slide_left_right",
        "slide_right_left",
        "slide_right_right"
    ]

    @Test("Slide tab exposes exact 8 directional Whole-Block scripts in canonical order")
    func testSlideCategoryExposesExactEightScripts() {
        let slides = TextAnimationScriptRegistry.shared.scripts(in: .slide)
        #expect(slides.count == 8)
        #expect(slides.map(\.id) == Self.expectedOrder)

        for script in slides {
            #expect(script.category == .slide)
            #expect(script.scope == .wholeBlock)
            #expect(script.loopCycleDuration == 1.0)
            #expect(!script.displayName.isEmpty)
        }
    }

    @Test("All 8 Slide scripts obey movement-direction convention in Intro and Outro and stand completely still in Loop")
    func testEightSlideDirectionsAndStationaryLoop() {
        let cases: [(id: String, inSignX: Double, inSignY: Double, outSignX: Double, outSignY: Double)] = [
            ("slide_up_up", 0, +1, 0, -1),
            ("slide_down_down", 0, -1, 0, +1),
            ("slide_up_down", 0, +1, 0, +1),
            ("slide_down_up", 0, -1, 0, -1),
            ("slide_left_left", +1, 0, -1, 0),
            ("slide_left_right", +1, 0, +1, 0),
            ("slide_right_left", -1, 0, -1, 0),
            ("slide_right_right", -1, 0, +1, 0)
        ]

        for entry in cases {
            var cfg = TextConfiguration(content: "HEADLINE", fontSize: 64.0)
            cfg.animation.scriptId = entry.id

            let introStart = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.0, duration: 5.0, canvasSize: canvasSize)
            let introMid = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.35, duration: 5.0, canvasSize: canvasSize)
            let outroMid = TextAnimationEvaluator.evaluate(config: cfg, localTime: 4.65, duration: 5.0, canvasSize: canvasSize)
            let outroEnd = TextAnimationEvaluator.evaluate(config: cfg, localTime: 5.0, duration: 5.0, canvasSize: canvasSize)

            assertAxisDirection(eval: introStart, signX: entry.inSignX, signY: entry.inSignY, minTravel: 500.0, label: "\(entry.id) introStart")
            assertAxisDirection(eval: introMid, signX: entry.inSignX, signY: entry.inSignY, minTravel: 50.0, label: "\(entry.id) introMid")
            assertMonotonicApproach(start: introStart, mid: introMid, label: entry.id)

            for loopT in [1.0, 1.5, 2.5, 3.5, 4.0] {
                let loopEval = TextAnimationEvaluator.evaluate(config: cfg, localTime: loopT, duration: 5.0, canvasSize: canvasSize)
                assertStationaryCrispLoop(loopEval, label: "\(entry.id) loop@\(loopT)")
            }

            assertAxisDirection(eval: outroMid, signX: entry.outSignX, signY: entry.outSignY, minTravel: 50.0, label: "\(entry.id) outroMid")
            assertAxisDirection(eval: outroEnd, signX: entry.outSignX, signY: entry.outSignY, minTravel: 500.0, label: "\(entry.id) outroEnd")
            #expect(introStart.config.opacity == 0.0)
            #expect(outroEnd.config.opacity == 0.0)
        }
    }

    @Test("Motion blur aligns with slide travel axis, obeys toggle/intensity, and turns off cleanly in Loop")
    func testDirectionalMotionBlurBehavior() {
        var verticalCfg = TextConfiguration(content: "VERTICAL", fontSize: 60.0)
        verticalCfg.animation.scriptId = "slide_up_down"

        let vIntro = TextAnimationEvaluator.evaluate(config: verticalCfg, localTime: 0.20, duration: 5.0, canvasSize: canvasSize)
        let vLoop = TextAnimationEvaluator.evaluate(config: verticalCfg, localTime: 2.50, duration: 5.0, canvasSize: canvasSize)
        let vOutro = TextAnimationEvaluator.evaluate(config: verticalCfg, localTime: 4.80, duration: 5.0, canvasSize: canvasSize)
        #expect(vIntro.overlay.motionBlurRadius > 0.5)
        #expect(abs(vIntro.overlay.motionBlurAngle - .pi * 0.5) < 0.01)
        #expect(vLoop.overlay.motionBlurRadius == 0.0)
        #expect(vOutro.overlay.motionBlurRadius > 0.5)
        #expect(abs(vOutro.overlay.motionBlurAngle - .pi * 0.5) < 0.01)

        var horizontalCfg = TextConfiguration(content: "HORIZONTAL", fontSize: 60.0)
        horizontalCfg.animation.scriptId = "slide_left_right"
        let hIntro = TextAnimationEvaluator.evaluate(config: horizontalCfg, localTime: 0.20, duration: 5.0, canvasSize: canvasSize)
        #expect(hIntro.overlay.motionBlurRadius > 0.5)
        #expect(abs(hIntro.overlay.motionBlurAngle) < 0.01)

        horizontalCfg.animation.isMotionBlurEnabled = false
        let hNoBlur = TextAnimationEvaluator.evaluate(config: horizontalCfg, localTime: 0.20, duration: 5.0, canvasSize: canvasSize)
        #expect(hNoBlur.overlay.motionBlurRadius == 0.0)
    }

    @Test("All 8 Slide scripts render crisp pixels, stay byte-identical to static text in Loop, and preserve Appearance colors")
    func testSlidePixelRenderingAndSegmentedOverride() throws {
        let engine = TextRendererEngine()
        let smallCanvas = CGSize(width: 640, height: 360)

        for scriptID in Self.expectedOrder {
            var staticCfg = TextConfiguration(content: "SLIDE\nTEST", fontSize: 52.0, textColorHex: "#FF5500", isBold: true)
            let staticImg = try #require(engine.renderAnimatedImage(for: staticCfg, localTime: 2.0, duration: 5.0, canvasSize: smallCanvas))
            let staticBytes = renderRGBABytes(staticImg, size: smallCanvas)

            var cfg = staticCfg
            cfg.animation.scriptId = scriptID

            let introImg = try #require(engine.renderAnimatedImage(for: cfg, localTime: 0.35, duration: 5.0, canvasSize: smallCanvas))
            let loopImgA = try #require(engine.renderAnimatedImage(for: cfg, localTime: 1.5, duration: 5.0, canvasSize: smallCanvas))
            let loopImgB = try #require(engine.renderAnimatedImage(for: cfg, localTime: 3.2, duration: 5.0, canvasSize: smallCanvas))
            let outroImg = try #require(engine.renderAnimatedImage(for: cfg, localTime: 4.65, duration: 5.0, canvasSize: smallCanvas))
            #expect(introImg.extent.size == smallCanvas)
            #expect(outroImg.extent.size == smallCanvas)

            let introBytes = renderRGBABytes(introImg, size: smallCanvas)
            let loopBytesA = renderRGBABytes(loopImgA, size: smallCanvas)
            let loopBytesB = renderRGBABytes(loopImgB, size: smallCanvas)
            let outroBytes = renderRGBABytes(outroImg, size: smallCanvas)

            #expect(loopBytesA == staticBytes, "\(scriptID) Loop must render identically to sharp static text")
            #expect(loopBytesB == staticBytes, "\(scriptID) Loop must remain completely stationary")
            #expect(introBytes != staticBytes, "\(scriptID) Intro must displace pixels")
            #expect(outroBytes != staticBytes, "\(scriptID) Outro must displace pixels")
            #expect(hasVisibleOpaquePixels(introBytes), "\(scriptID) Intro must contain visible pixels")
            #expect(hasVisibleOpaquePixels(outroBytes), "\(scriptID) Outro must contain visible pixels")

            cfg.animation.scopeOverride = .perWord
            cfg.animation.staggerDirection = .centerOut
            let segImg = try #require(engine.renderAnimatedImage(for: cfg, localTime: 0.35, duration: 5.0, canvasSize: smallCanvas))
            #expect(segImg.extent.size == smallCanvas)

            staticCfg.background = TextBackgroundStyle(isEnabled: true, sourceKind: .solid, solidColorHex: "#1E293B", animateWithText: true)
            staticCfg.animation.scriptId = scriptID
            let bgSlideImg = try #require(engine.renderAnimatedImage(for: staticCfg, localTime: 0.35, duration: 5.0, canvasSize: smallCanvas))
            #expect(bgSlideImg.extent.size == smallCanvas)
        }
    }

    @Test("Legacy Slide IDs and old In-type JSON decode safely to new 8-direction Slide scripts")
    func testLegacySlideAliasesAndJSONMigration() throws {
        let legacySlideIDs = [
            "smooth_word_glide", "line_cascade_rise", "trailer_tracking_expand",
            "whip_echo_slam", "anamorphic_split_reveal",
            "slide_directional_whip", "slide_zipper_cross", "vhs_tracking_drift"
        ]
        for legacyID in legacySlideIDs {
            let resolved = TextAnimationScriptRegistry.shared.script(for: legacyID)
            #expect(resolved != nil, "Missing alias for \(legacyID)")
            #expect(resolved?.category == .slide, "Legacy \(legacyID) must resolve into .slide")
        }

        let oldProjectJSON = """
        {
            "content": "Old Slide",
            "animation": { "inType": "SlideUp" }
        }
        """
        let decoded = try #require(TextConfiguration.decode(from: oldProjectJSON))
        #expect(decoded.animation.scriptId == "slide_up_up")
    }

    @Test("Hover preview starts immediately at Intro t=0 and renders distinct frames for all 8 Slide scripts")
    func testHoverPreviewStartsFromIntroZeroAndRendersThumbnails() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000.0)
        #expect(TextThumbnailRenderer.scriptPreviewLocalTime(startDate: start, currentDate: start, duration: 2.8) == 0.0)
        #expect(TextThumbnailRenderer.scriptPreviewLocalTime(startDate: start, currentDate: start.addingTimeInterval(-0.05), duration: 2.8) == 0.0)
        let midIntro = TextThumbnailRenderer.scriptPreviewLocalTime(startDate: start, currentDate: start.addingTimeInterval(0.35), duration: 2.8)
        #expect(abs(midIntro - 0.35) < 0.0001)
        let wrapped = TextThumbnailRenderer.scriptPreviewLocalTime(startDate: start, currentDate: start.addingTimeInterval(3.15), duration: 2.8)
        #expect(abs(wrapped - 0.35) < 0.0001)

        for scriptID in Self.expectedOrder {
            let heroT = TextThumbnailRenderer.heroPreviewTime(for: scriptID)
            #expect(heroT > 0.1 && heroT < 0.8)
            let frame = TextThumbnailRenderer.renderScriptPreviewFrame(scriptId: scriptID, localTime: heroT, duration: 2.8)
            #expect(frame != nil, "Expected thumbnail frame for \(scriptID)")
        }

        let grid = TextScriptAnimationCardsGrid(
            selectedScriptId: "slide_up_up",
            showBottomPanel: true,
            onSelectScript: { _ in },
            onClearScript: {}
        ) {
            EmptyView()
        }
        _ = grid.body
    }

    @Test("MCP resolver routes all 8 directional Slide queries cleanly without hijacking non-Slide scripts")
    func testMCPDirectionalSlideResolver() {
        #expect(MCPTextPropertyResolver.resolveScriptId("slide up") == "slide_up_up")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide down") == "slide_down_down")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide up down") == "slide_up_down")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide down up") == "slide_down_up")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide left") == "slide_left_left")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide left right") == "slide_left_right")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide right left") == "slide_right_left")
        #expect(MCPTextPropertyResolver.resolveScriptId("slide right") == "slide_right_right")
        #expect(MCPTextPropertyResolver.resolveScriptId("vào up ra down") == "slide_up_down")
        #expect(MCPTextPropertyResolver.resolveScriptId("vào left ra right") == "slide_left_right")
        #expect(MCPTextPropertyResolver.resolveScriptId("trượt trái sang phải") == "slide_left_right")
        #expect(MCPTextPropertyResolver.resolveScriptId("pop up") == "pop_elastic_bounce")
        #expect(MCPTextPropertyResolver.resolveScriptId("hinge 3d pop") == "pop_up_hinge_3d")
    }

    @Test("Rendered RGBA8 pixel centroids confirm exact visual travel direction for all 8 Slide variants")
    func testRenderedPixelCentroidsFollowEightDirections() throws {
        let engine = TextRendererEngine()
        let probeCanvas = CGSize(width: 640, height: 360)
        // Expected screen-space pixel centroid deltas (top-down buffer: +x is right, +y is down):
        // Intro moves from inStartDir -> center (0,0); Outro moves from center -> outEndDir
        let expectations: [(id: String, inDx: Double, inDy: Double, outDx: Double, outDy: Double)] = [
            ("slide_up_up", 0, -1, 0, -1),
            ("slide_down_down", 0, +1, 0, +1),
            ("slide_up_down", 0, -1, 0, +1),
            ("slide_down_up", 0, +1, 0, -1),
            ("slide_left_left", -1, 0, -1, 0),
            ("slide_left_right", -1, 0, +1, 0),
            ("slide_right_left", +1, 0, -1, 0),
            ("slide_right_right", +1, 0, +1, 0)
        ]

        for entry in expectations {
            var cfg = TextConfiguration(content: "BLOCK", fontSize: 56.0, textColorHex: "#FFFFFF", isBold: true)
            cfg.animation.scriptId = entry.id
            let inA = pixelCentroid(try #require(engine.renderAnimatedImage(for: cfg, localTime: 0.25, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
            let inB = pixelCentroid(try #require(engine.renderAnimatedImage(for: cfg, localTime: 0.50, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
            let loopC = pixelCentroid(try #require(engine.renderAnimatedImage(for: cfg, localTime: 2.00, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
            let outA = pixelCentroid(try #require(engine.renderAnimatedImage(for: cfg, localTime: 4.45, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
            let outB = pixelCentroid(try #require(engine.renderAnimatedImage(for: cfg, localTime: 4.72, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)

            assertTravelDirection(from: inA, to: inB, expectedSignX: entry.inDx, expectedSignY: entry.inDy, label: "\(entry.id) Intro")
            assertTravelDirection(from: inB, to: loopC, expectedSignX: entry.inDx, expectedSignY: entry.inDy, label: "\(entry.id) Settle")
            assertTravelDirection(from: loopC, to: outA, expectedSignX: entry.outDx, expectedSignY: entry.outDy, label: "\(entry.id) OutroStart")
            assertTravelDirection(from: outA, to: outB, expectedSignX: entry.outDx, expectedSignY: entry.outDy, label: "\(entry.id) OutroExit")
        }
    }

    @Test("Rendered pixels verify axis-aligned Motion Blur spread and extreme edge clearance + segmented independence")
    func testMotionBlurPixelSpreadEdgeClearanceAndLegacyMigration() throws {
        let engine = TextRendererEngine()
        let probeCanvas = CGSize(width: 640, height: 360)

        var vOn = TextConfiguration(content: "I", fontSize: 72.0, textColorHex: "#FFFFFF", isBold: true)
        vOn.animation.scriptId = "slide_up_up"
        var vOff = vOn
        vOff.animation.isMotionBlurEnabled = false
        let vOnBBox = pixelAlphaBounds(try #require(engine.renderAnimatedImage(for: vOn, localTime: 0.25, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
        let vOffBBox = pixelAlphaBounds(try #require(engine.renderAnimatedImage(for: vOff, localTime: 0.25, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
        #expect(vOnBBox.height > vOffBBox.height + 4.0, "Vertical slide must smear along Y axis")
        #expect(abs(vOnBBox.width - vOffBBox.width) <= 2.0, "Vertical slide must not smear horizontally")

        var hOn = TextConfiguration(content: "H", fontSize: 72.0, textColorHex: "#FFFFFF", isBold: true)
        hOn.animation.scriptId = "slide_left_left"
        var hOff = hOn
        hOff.animation.isMotionBlurEnabled = false
        let hOnBBox = pixelAlphaBounds(try #require(engine.renderAnimatedImage(for: hOn, localTime: 0.25, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
        let hOffBBox = pixelAlphaBounds(try #require(engine.renderAnimatedImage(for: hOff, localTime: 0.25, duration: 5.0, canvasSize: probeCanvas)), size: probeCanvas)
        #expect(hOnBBox.width > hOffBBox.width + 4.0, "Horizontal slide must smear along X axis")
        #expect(abs(hOnBBox.height - hOffBBox.height) <= 2.0, "Horizontal slide must not smear vertically")

        // Edge clearance for bottom subtitle, top header, and wide shifted text
        let hdCanvas = CGSize(width: 1920, height: 1080)
        var subCfg = TextConfiguration(content: "SUBTITLE\nLINE TWO", fontSize: 72.0, textColorHex: "#FFFFFF", isBold: true, positionY: 430.0)
        subCfg.animation.scriptId = "slide_up_up"
        let subEvalEnd = TextAnimationEvaluator.evaluate(config: subCfg, localTime: 5.0, duration: 5.0, canvasSize: hdCanvas)
        var subPosOnly = subCfg
        subPosOnly.animation = TextAnimationConfiguration()
        subPosOnly.positionY = subEvalEnd.config.positionY
        subPosOnly.opacity = 1.0
        #expect(!hasVisibleOpaquePixels(renderRGBABytes(try #require(engine.renderImage(for: subPosOnly, canvasSize: hdCanvas)), size: hdCanvas)))

        var hdrCfg = TextConfiguration(content: "HEADER\nLINE TWO", fontSize: 72.0, textColorHex: "#FFFFFF", isBold: true, positionY: -430.0)
        hdrCfg.animation.scriptId = "slide_down_down"
        let hdrEvalEnd = TextAnimationEvaluator.evaluate(config: hdrCfg, localTime: 5.0, duration: 5.0, canvasSize: hdCanvas)
        var hdrPosOnly = hdrCfg
        hdrPosOnly.animation = TextAnimationConfiguration()
        hdrPosOnly.positionY = hdrEvalEnd.config.positionY
        hdrPosOnly.opacity = 1.0
        #expect(!hasVisibleOpaquePixels(renderRGBABytes(try #require(engine.renderImage(for: hdrPosOnly, canvasSize: hdCanvas)), size: hdCanvas)))

        let wideCanvas = CGSize(width: 1280, height: 720)
        var wideCfg = TextConfiguration(content: "WIDE HEADLINE TEXT", fontSize: 80.0, textColorHex: "#FFFFFF", isBold: true, positionX: -320.0)
        wideCfg.animation.scriptId = "slide_right_right"
        let wideEvalEnd = TextAnimationEvaluator.evaluate(config: wideCfg, localTime: 5.0, duration: 5.0, canvasSize: wideCanvas)
        var widePosOnly = wideCfg
        widePosOnly.animation = TextAnimationConfiguration()
        widePosOnly.positionX = wideEvalEnd.config.positionX
        widePosOnly.opacity = 1.0
        #expect(!hasVisibleOpaquePixels(renderRGBABytes(try #require(engine.renderImage(for: widePosOnly, canvasSize: wideCanvas)), size: wideCanvas)))

        // Segmented per-word independence: center word stays sharp while staggered outer word blurs
        var segBlurCfg = TextConfiguration(content: "LEFT MID RIGHT", fontSize: 56.0, textColorHex: "#FFFFFF", isBold: true)
        segBlurCfg.animation.scriptId = "slide_up_up"
        segBlurCfg.animation.scopeOverride = .perWord
        segBlurCfg.animation.staggerDirection = .centerOut
        var segNoBlurCfg = segBlurCfg
        segNoBlurCfg.animation.isMotionBlurEnabled = false
        let segBlurImg = try #require(engine.renderAnimatedImage(for: segBlurCfg, localTime: 4.30, duration: 5.0, canvasSize: probeCanvas))
        let segNoBlurImg = try #require(engine.renderAnimatedImage(for: segNoBlurCfg, localTime: 4.30, duration: 5.0, canvasSize: probeCanvas))
        let rightSlice = CGRect(x: 380, y: 0, width: 260, height: 360)
        let blurRightBytes = renderRGBABytes(segBlurImg.cropped(to: rightSlice), size: probeCanvas)
        let noBlurRightBytes = renderRGBABytes(segNoBlurImg.cropped(to: rightSlice), size: probeCanvas)
        #expect(blurRightBytes == noBlurRightBytes, "Unmoved outer word must remain crisp while center word blurs")

        // Mixed legacy In/Out JSON migration
        let mixedJSON = #"{"content":"Legacy","animation":{"inType":"SlideUp","outType":"SlideDown"}}"#
        let outOnlyJSON = #"{"content":"Legacy","animation":{"inType":"None","outType":"SlideLeft"}}"#
        #expect(TextConfiguration.decode(from: mixedJSON)?.animation.scriptId == "slide_up_down")
        #expect(TextConfiguration.decode(from: outOnlyJSON)?.animation.scriptId == "slide_left_left")
    }

    private func assertTravelDirection(
        from a: (x: Double, y: Double),
        to b: (x: Double, y: Double),
        expectedSignX: Double,
        expectedSignY: Double,
        label: String
    ) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        if expectedSignX == 0 {
            #expect(abs(dx) < 3.0, "\(label) expected zero X drift, got \(dx)")
        } else {
            #expect(dx * expectedSignX > 10.0, "\(label) expected X movement \(expectedSignX), got \(dx)")
        }
        if expectedSignY == 0 {
            #expect(abs(dy) < 3.0, "\(label) expected zero Y drift, got \(dy)")
        } else {
            #expect(dy * expectedSignY > 10.0, "\(label) expected Y movement \(expectedSignY), got \(dy)")
        }
    }

    private func pixelCentroid(_ image: CIImage, size: CGSize) -> (x: Double, y: Double) {
        let bytes = renderRGBABytes(image, size: size)
        let w = Int(size.width), h = Int(size.height)
        var sumA = 0.0, sumX = 0.0, sumY = 0.0
        for y in 0..<h {
            for x in 0..<w {
                let a = Double(bytes[(y * w + x) * 4 + 3])
                if a > 0 {
                    sumA += a
                    sumX += Double(x) * a
                    sumY += Double(y) * a
                }
            }
        }
        guard sumA > 0 else { return (-1, -1) }
        return ((sumX / sumA * 10).rounded() / 10, (sumY / sumA * 10).rounded() / 10)
    }

    private func pixelAlphaBounds(_ image: CIImage, size: CGSize) -> CGRect {
        let bytes = renderRGBABytes(image, size: size)
        let w = Int(size.width), h = Int(size.height)
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                if bytes[(y * w + x) * 4 + 3] > 2 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func renderRGBABytes(_ image: CIImage, size: CGSize) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        ctx.render(
            image, toBitmap: &bytes, rowBytes: w * 4,
            bounds: CGRect(origin: .zero, size: size),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return bytes
    }

    private func hasVisibleOpaquePixels(_ bytes: [UInt8]) -> Bool {
        for idx in stride(from: 3, to: bytes.count, by: 4) where bytes[idx] > 40 {
            return true
        }
        return false
    }

    private func assertAxisDirection(
        eval: TextAnimationEvaluator.EvaluationResult,
        signX: Double,
        signY: Double,
        minTravel: Double,
        label: String
    ) {
        if signX == 0 {
            #expect(abs(eval.config.positionX) < 0.001, "\(label) expected zero X")
        } else {
            #expect(eval.config.positionX * signX >= minTravel, "\(label) expected X sign \(signX), got \(eval.config.positionX)")
        }
        if signY == 0 {
            #expect(abs(eval.config.positionY) < 0.001, "\(label) expected zero Y")
        } else {
            #expect(eval.config.positionY * signY >= minTravel, "\(label) expected Y sign \(signY), got \(eval.config.positionY)")
        }
    }

    private func assertMonotonicApproach(
        start: TextAnimationEvaluator.EvaluationResult,
        mid: TextAnimationEvaluator.EvaluationResult,
        label: String
    ) {
        let startDist = hypot(start.config.positionX, start.config.positionY)
        let midDist = hypot(mid.config.positionX, mid.config.positionY)
        #expect(midDist < startDist, "\(label) must decelerate inward from start")
    }

    private func assertStationaryCrispLoop(_ eval: TextAnimationEvaluator.EvaluationResult, label: String) {
        #expect(abs(eval.config.positionX) < 0.0001, "\(label) positionX")
        #expect(abs(eval.config.positionY) < 0.0001, "\(label) positionY")
        #expect(abs(eval.overlay.scaleX - 1.0) < 0.0001, "\(label) scaleX")
        #expect(abs(eval.overlay.scaleY - 1.0) < 0.0001, "\(label) scaleY")
        #expect(abs(eval.config.rotation) < 0.0001, "\(label) rotation")
        #expect(abs(eval.config.skewX) < 0.0001, "\(label) skewX")
        #expect(abs(eval.config.opacity - 1.0) < 0.0001, "\(label) opacity")
        #expect(eval.blurRadius == 0.0, "\(label) blurRadius")
        #expect(eval.overlay.motionBlurRadius == 0.0, "\(label) motionBlurRadius")
    }
}
