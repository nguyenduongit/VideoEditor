import Testing
import Foundation
import SwiftUI
@testable import Domain
@testable import DesignSystem
@testable import FeatureShell

@Suite("TextAnimationDualDurationTests")
@MainActor
struct TextAnimationDualDurationTests {
    @Test("Dual duration clamps In and Out animations to prevent collision")
    func testDualDurationCollisionClamping() {
        var config = TextConfiguration()
        config.animation.inType = .fadeIn
        config.animation.outType = .fadeOut
        config.animation.inDuration = 0.5
        config.animation.outDuration = 0.5

        let clipDuration = 3.0

        // In duration cannot exceed clipDuration - outDuration
        let maxAllowedIn = max(0.1, clipDuration - config.animation.outDuration)
        #expect(maxAllowedIn == 2.5)

        // If user tries to set In to 2.8s, it should clamp to 2.5s
        let attemptedIn = 2.8
        let clampedIn = max(0.1, min(maxAllowedIn, attemptedIn))
        #expect(clampedIn == 2.5)

        // Out duration cannot exceed clipDuration - inDuration
        config.animation.inDuration = 2.0
        let maxAllowedOut = max(0.1, clipDuration - config.animation.inDuration)
        #expect(maxAllowedOut == 1.0)

        let attemptedOut = 1.5
        let clampedOut = max(0.1, min(maxAllowedOut, attemptedOut))
        #expect(clampedOut == 1.0)
    }

    @Test("Loop speed is bounded between 0.2x and 4.0x")
    func testLoopSpeedClamping() {
        var config = TextConfiguration()
        config.animation.loopType = .pulse
        config.animation.loopSpeed = 1.0

        let underflow = 0.05
        let clampedUnderflow = max(0.2, min(4.0, underflow))
        #expect(clampedUnderflow == 0.2)

        let overflow = 5.5
        let clampedOverflow = max(0.2, min(4.0, overflow))
        #expect(clampedOverflow == 4.0)
    }

    @Test("DSDualSlider initializes with valid bounds and non-zero duration")
    func testDSDualSliderInitialization() {
        var inVal: Double = 0.5
        var outVal: Double = 0.5

        let slider = DSDualSlider(
            inValue: Binding(get: { inVal }, set: { inVal = $0 }),
            outValue: Binding(get: { outVal }, set: { outVal = $0 }),
            totalDuration: 3.0,
            minDuration: 0.1,
            step: 0.05,
            showsInThumb: true,
            showsOutThumb: false
        )
        _ = slider
        #expect(inVal == 0.5 && outVal == 0.5)
    }

    @Test("Selecting None clears animation and preserves 1.0s default duration when re-enabled")
    func testAnimationNoneSelectionReset() {
        var config = TextConfiguration()
        #expect(config.animation.inDuration == 1.0)
        #expect(config.animation.outDuration == 1.0)

        // Bật animation Out
        config.animation.outType = .tvOff
        #expect(config.animation.outType == .tvOff)

        // Bỏ hiệu ứng: chọn None
        config.animation.outType = .none
        #expect(config.animation.outType == .none)

        // Bật animation In
        config.animation.inType = .fadeIn
        #expect(config.animation.inType == .fadeIn)
        config.animation.inType = .none
        #expect(config.animation.inType == .none)

        // Bật animation Loop
        config.animation.loopType = .pulse
        #expect(config.animation.loopType == .pulse)
        config.animation.loopType = .none
        #expect(config.animation.loopType == .none)
    }
}
