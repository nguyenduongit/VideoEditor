import Testing
import Foundation
import CoreGraphics
@testable import FeatureShell

@Suite("TimelineRulerConfigTests")
struct TimelineRulerConfigTests {
    @Test("TimelineRulerConfig selects intervals ensuring at least minPixelDistance")
    func testBestIntervalAdaptsToPPS() {
        let testPPSList: [CGFloat] = [100.0, 40.0, 20.0, 8.0, 5.0, 2.5, 1.2, 0.5, 0.1]

        for pps in testPPSList {
            let config = TimelineRulerConfig.bestInterval(for: pps)
            let pixelDist = CGFloat(config.majorSeconds) * pps
            // If not at the maximum interval (7200s), pixel distance should be at least minPixelDistance (70px)
            if config.majorSeconds < 7200.0 {
                #expect(pixelDist >= TimelineRulerConfig.minPixelDistance)
            }
            #expect(config.subTicks >= 2)
        }
    }

    @Test("TimelineRulerConfig specific zoom levels match expectations")
    func testSpecificZoomLevels() {
        // At 100 pps, 1s interval is 100px >= 70px
        let c100 = TimelineRulerConfig.bestInterval(for: 100.0)
        #expect(c100.majorSeconds == 1.0)
        #expect(c100.subTicks == 4)

        // At 40 pps: 1s is 40px (< 70px), 2s is 80px (>= 70px)
        let c40 = TimelineRulerConfig.bestInterval(for: 40.0)
        #expect(c40.majorSeconds == 2.0)
        #expect(c40.subTicks == 4)

        // At 15 pps: 1s=15, 2s=30, 5s=75 (>= 70px)
        let c15 = TimelineRulerConfig.bestInterval(for: 15.0)
        #expect(c15.majorSeconds == 5.0)
        #expect(c15.subTicks == 5)

        // At 2.5 pps (e.g. 6-7 min video fit to 1000px):
        // 1s=2.5, 2s=5, 5s=12.5, 10s=25, 15s=37.5, 30s=75 (>= 70px)
        let c2_5 = TimelineRulerConfig.bestInterval(for: 2.5)
        #expect(c2_5.majorSeconds == 30.0)
        #expect(c2_5.subTicks == 6)

        // At 1.0 pps: 60s is 60px (< 70px), 120s is 120px (>= 70px)
        let c1_0 = TimelineRulerConfig.bestInterval(for: 1.0)
        #expect(c1_0.majorSeconds == 120.0)
        #expect(c1_0.subTicks == 4)
    }

    @Test("TimelineRulerConfig edge case pps zero or negative")
    func testEdgeCasePPS() {
        let zeroConfig = TimelineRulerConfig.bestInterval(for: 0.0)
        #expect(zeroConfig.majorSeconds > 0)

        let negConfig = TimelineRulerConfig.bestInterval(for: -5.0)
        #expect(negConfig.majorSeconds > 0)
    }

    @Test("TimelineRulerConfig formatRulerTime outputs correct strings")
    func testFormatRulerTime() {
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 0) == "00:00")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 5) == "00:05")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 65) == "01:05")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 599) == "09:59")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 3599) == "59:59")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 3600) == "01:00:00")
        #expect(TimelineRulerConfig.formatRulerTime(seconds: 3665) == "01:01:05")
    }
}
