import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineWaveformFadeTests")
struct TimelineWaveformFadeTests {
    @Test("AudioWaveformMath envelopeGain with zero fades returns full gain")
    func testEnvelopeGainZeroFades() {
        let gainStart = AudioWaveformMath.envelopeGain(at: 0.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0)
        let gainMid = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0)
        let gainEnd = AudioWaveformMath.envelopeGain(at: 10.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0)

        #expect(gainStart == 1.0)
        #expect(gainMid == 1.0)
        #expect(gainEnd == 1.0)
    }

    @Test("AudioWaveformMath envelopeGain S-curve calculation during fade-in")
    func testEnvelopeGainFadeIn() {
        let gain0 = AudioWaveformMath.envelopeGain(at: 0.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainQuarter = AudioWaveformMath.envelopeGain(at: 0.5, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainHalf = AudioWaveformMath.envelopeGain(at: 1.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainThreeQuarter = AudioWaveformMath.envelopeGain(at: 1.5, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainFull = AudioWaveformMath.envelopeGain(at: 2.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainAfter = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)

        #expect(abs(gain0 - 0.0) < 0.001)
        // At u=0.25, Hermite smoothstep 3u^2 - 2u^3 = 0.15625 (< linear 0.25)
        #expect(abs(gainQuarter - 0.15625) < 0.001)
        #expect(abs(gainHalf - 0.5) < 0.001)
        // At u=0.75, Hermite smoothstep 3u^2 - 2u^3 = 0.84375 (> linear 0.75)
        #expect(abs(gainThreeQuarter - 0.84375) < 0.001)
        #expect(abs(gainFull - 1.0) < 0.001)
        #expect(abs(gainAfter - 1.0) < 0.001)
    }

    @Test("AudioWaveformMath envelopeGain S-curve calculation during fade-out")
    func testEnvelopeGainFadeOut() {
        let gainBefore = AudioWaveformMath.envelopeGain(at: 7.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainStartOut = AudioWaveformMath.envelopeGain(at: 8.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainQuarterOut = AudioWaveformMath.envelopeGain(at: 8.5, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainHalfOut = AudioWaveformMath.envelopeGain(at: 9.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainThreeQuarterOut = AudioWaveformMath.envelopeGain(at: 9.5, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainEndOut = AudioWaveformMath.envelopeGain(at: 10.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)

        #expect(abs(gainBefore - 1.0) < 0.001)
        #expect(abs(gainStartOut - 1.0) < 0.001)
        #expect(abs(gainQuarterOut - 0.84375) < 0.001)
        #expect(abs(gainHalfOut - 0.5) < 0.001)
        #expect(abs(gainThreeQuarterOut - 0.15625) < 0.001)
        #expect(abs(gainEndOut - 0.0) < 0.001)
    }

    @Test("AudioWaveformMath envelopeGain handles boundary clamping and zero duration safely")
    func testEnvelopeGainClamping() {
        let zeroDurGain = AudioWaveformMath.envelopeGain(at: 1.0, duration: 0.0, fadeIn: 1.0, fadeOut: 1.0)
        #expect(zeroDurGain == 1.0)

        let negativeTimeGain = AudioWaveformMath.envelopeGain(at: -2.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        #expect(abs(negativeTimeGain - 0.0) < 0.001)

        let beyondDurGain = AudioWaveformMath.envelopeGain(at: 12.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        #expect(abs(beyondDurGain - 0.0) < 0.001)
    }

    @Test("TimelineViewModel updateClipLiveProperties mutates clip live without undo step")
    @MainActor
    func testLivePropertiesUpdate() {
        let vm = TimelineViewModel()
        let layerID = UUID()
        let clipID = UUID()
        let clip = TimelineClip(
            id: clipID,
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
            sourceStartTime: .zero,
            properties: ["fadeIn": .number(0.0), "fadeOut": .number(0.0)]
        )
        let layer = TimelineLayer(id: layerID, name: "Track 1", kind: .audio, clips: [clip])
        vm.layers = [layer]

        let initialCanUndo = vm.canUndo
        vm.updateClipLiveProperties(clipID: clipID, properties: ["fadeIn": .number(1.5), "fadeOut": .number(0.5)])

        let updated = vm.clip(by: clipID)
        #expect(updated?.properties["fadeIn"]?.asNumber == 1.5)
        #expect(updated?.properties["fadeOut"]?.asNumber == 0.5)
        #expect(vm.canUndo == initialCanUndo)
    }

    @Test("TimelineViewModel commitClipProperties creates undoable and redoable command")
    @MainActor
    func testCommitClipPropertiesUndoRedo() {
        let vm = TimelineViewModel()
        let layerID = UUID()
        let clipID = UUID()
        let clip = TimelineClip(
            id: clipID,
            name: "Audio 1",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
            sourceStartTime: .zero,
            properties: ["fadeIn": .number(0.0), "fadeOut": .number(0.0)]
        )
        let layer = TimelineLayer(id: layerID, name: "Track 1", kind: .audio, clips: [clip])
        vm.layers = [layer]

        vm.commitClipProperties(clipID: clipID, properties: ["fadeIn": .number(2.0), "fadeOut": .number(1.0)])

        let committed = vm.clip(by: clipID)
        #expect(committed?.properties["fadeIn"]?.asNumber == 2.0)
        #expect(committed?.properties["fadeOut"]?.asNumber == 1.0)
        #expect(vm.canUndo == true)

        let undoSuccess = vm.undo()
        #expect(undoSuccess == true)
        let undone = vm.clip(by: clipID)
        #expect(undone?.properties["fadeIn"]?.asNumber == 0.0)
        #expect(undone?.properties["fadeOut"]?.asNumber == 0.0)
        #expect(vm.canRedo == true)

        let redoSuccess = vm.redo()
        #expect(redoSuccess == true)
        let redone = vm.clip(by: clipID)
        #expect(redone?.properties["fadeIn"]?.asNumber == 2.0)
        #expect(redone?.properties["fadeOut"]?.asNumber == 1.0)
    }

    @Test("AudioWaveformMath envelopeGain scales waveform amplitude proportionally with volume up to 400%")
    func testEnvelopeGainScalesWithVolume() {
        let gainHalf = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0, volume: 0.5)
        let gainNormal = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0, volume: 1.0)
        let gainDouble = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0, volume: 2.0)
        let gainQuad = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 0.0, fadeOut: 0.0, volume: 4.0)
        let gainFadeMid = AudioWaveformMath.envelopeGain(at: 1.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0, volume: 2.0)

        #expect(abs(gainHalf - 0.5) < 0.001)
        #expect(abs(gainNormal - 1.0) < 0.001)
        #expect(abs(gainDouble - 2.0) < 0.001)
        #expect(abs(gainQuad - 4.0) < 0.001)
        #expect(abs(gainFadeMid - 1.0) < 0.001)

        #expect(AudioWaveformMath.volumeLineHeightFraction(volume: 0.0) == 0.0)
        #expect(AudioWaveformMath.volumeLineHeightFraction(volume: 1.0) == 0.5)
        #expect(AudioWaveformMath.volumeLineHeightFraction(volume: 4.0) == 1.0)
    }

    @Test("TimelineCompositionBuilder attaches live TimelineAudioGainTap controller for glitch-free Volume, FadeIn, FadeOut, and Balance updates")
    func testBuildAudioMixAttachesLiveGainTapAndUpdatesInPlace() {
        let layerID = UUID()
        var clip = TimelineClip(
            name: "Audio Clip",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10, preferredTimescale: 600)),
            properties: ["volume": .number(1.0), "fadeIn": .number(0.0), "fadeOut": .number(0.0), "pan": .number(0.0)]
        )
        let layer = TimelineLayer(id: layerID, name: "Audio 1", kind: .audio, clips: [clip])
        let built = TimelineCompositionBuilder.buildAudioMixWithTapControllers(
            for: [layer],
            layerAudioTrackIDs: [layerID: [1]]
        )
        #expect(built.audioMix.inputParameters.first?.audioTapProcessor != nil)
        guard let controller = built.tapControllers[1] else {
            Issue.record("Expected live TimelineAudioGainTap controller for track 1")
            return
        }
        #expect(abs(controller.currentTargetGain - 1.0) < 0.001)

        // 1. Mutating volume in-place updates controller targetGain without rebuilding AVAudioMix
        clip.properties["volume"] = .number(2.5)
        controller.update(clips: [clip], isLayerMuted: false, playheadSec: 5.0)
        #expect(abs(controller.currentTargetGain - 2.5) < 0.001)

        // Verify per-buffer ramp smoothing from 1.0 -> 2.5
        let step = controller.readAndAdvanceChannelGains(frameCount: 512, sampleTimeSec: 5.0)
        #expect(abs(step.startL - 1.0) < 0.001)
        #expect(abs(step.endL - 2.5) < 0.001)

        // 2. Mutating FadeIn, FadeOut, and Balance (pan) in-place updates L/R channel gains live
        clip.properties["volume"] = .number(2.0)
        clip.properties["fadeIn"] = .number(2.0)
        clip.properties["fadeOut"] = .number(2.0)
        clip.properties["pan"] = .number(0.5) // Pan right (+50%) -> Left is 50%, Right is 100%
        controller.update(clips: [clip], isLayerMuted: false, playheadSec: 1.0) // At t=1.0s (half of 2.0s fade-in -> env = 1.0)
        let gainsMidFadeIn = controller.evaluateChannelGains(at: 1.0)
        #expect(abs(gainsMidFadeIn.left - 0.5) < 0.001)
        #expect(abs(gainsMidFadeIn.right - 1.0) < 0.001)

        let gainsMidFadeOut = controller.evaluateChannelGains(at: 9.0) // At t=9.0s (half of 2.0s fade-out -> env = 1.0)
        #expect(abs(gainsMidFadeOut.left - 0.5) < 0.001)
        #expect(abs(gainsMidFadeOut.right - 1.0) < 0.001)

        // 3. Verify soft-knee limiter keeps linear region intact and prevents clipping above +/-1.0
        #expect(abs(TimelineAudioGainTap.softLimit(0.5) - 0.5) < 0.0001)
        let limited = TimelineAudioGainTap.softLimit(2.5)
        #expect(limited > 0.85 && limited <= 1.0)
    }
}
