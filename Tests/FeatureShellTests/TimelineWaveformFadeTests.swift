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

    @Test("AudioWaveformMath envelopeGain ramp calculation during fade-in")
    func testEnvelopeGainFadeIn() {
        let gain0 = AudioWaveformMath.envelopeGain(at: 0.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainHalf = AudioWaveformMath.envelopeGain(at: 1.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainFull = AudioWaveformMath.envelopeGain(at: 2.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)
        let gainAfter = AudioWaveformMath.envelopeGain(at: 5.0, duration: 10.0, fadeIn: 2.0, fadeOut: 0.0)

        #expect(abs(gain0 - 0.0) < 0.001)
        #expect(abs(gainHalf - 0.5) < 0.001)
        #expect(abs(gainFull - 1.0) < 0.001)
        #expect(abs(gainAfter - 1.0) < 0.001)
    }

    @Test("AudioWaveformMath envelopeGain ramp calculation during fade-out")
    func testEnvelopeGainFadeOut() {
        let gainBefore = AudioWaveformMath.envelopeGain(at: 7.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainStartOut = AudioWaveformMath.envelopeGain(at: 8.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainHalfOut = AudioWaveformMath.envelopeGain(at: 9.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)
        let gainEndOut = AudioWaveformMath.envelopeGain(at: 10.0, duration: 10.0, fadeIn: 0.0, fadeOut: 2.0)

        #expect(abs(gainBefore - 1.0) < 0.001)
        #expect(abs(gainStartOut - 1.0) < 0.001)
        #expect(abs(gainHalfOut - 0.5) < 0.001)
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
}
