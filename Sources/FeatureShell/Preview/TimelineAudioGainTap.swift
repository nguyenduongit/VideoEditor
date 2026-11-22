import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import AudioToolbox
import os
import Domain

/// Bộ xử lý DSP PCM thời gian thực cho toàn bộ thuộc tính Audio (`Volume`, `Fade In`, `Fade Out`, `Balance/Pan`, `Mute`)
/// qua `MTAudioProcessingTap` (`PreEffects`), cập nhật trực tiếp qua `OSAllocatedUnfairLock` mà không tái tạo `AVAudioMix`.
final class TimelineAudioGainTap: Sendable {
    static let maxAllowedVolume: Float = 4.0

    struct ClipAudioSegment: Sendable {
        let clipID: UUID
        let startSec: Double
        let endSec: Double
        let volume: Float
        let fadeInSec: Double
        let fadeOutSec: Double
        let pan: Float

        func gainAndPan(at timelineSec: Double?) -> (gain: Float, pan: Float) {
            guard let t = timelineSec, t.isFinite else {
                return (volume, pan)
            }
            let dur = max(0.001, endSec - startSec)
            let rel = max(0.0, min(dur, t - startSec))
            let env = AudioWaveformMath.envelopeGain(
                at: rel,
                duration: dur,
                fadeIn: fadeInSec,
                fadeOut: fadeOutSec,
                volume: Double(volume)
            )
            return (env, pan)
        }
    }

    private struct MutableState: Sendable {
        var isLayerMuted: Bool
        var sampleRate: Double
        var isNonInterleaved: Bool
        var estimatedPlayheadSec: Double?
        var currentSmoothedLeftGain: Float
        var currentSmoothedRightGain: Float
        var segments: [ClipAudioSegment]
    }

    private let lock: OSAllocatedUnfairLock<MutableState>

    init(clips: [TimelineClip], isLayerMuted: Bool) {
        let segs = Self.buildSegments(from: clips)
        let (initL, initR) = isLayerMuted ? (Float(0), Float(0)) : Self.resolveChannelGains(from: segs, playheadSec: nil)
        self.lock = OSAllocatedUnfairLock(
            initialState: MutableState(
                isLayerMuted: isLayerMuted,
                sampleRate: 48000.0,
                isNonInterleaved: true,
                estimatedPlayheadSec: nil,
                currentSmoothedLeftGain: initL,
                currentSmoothedRightGain: initR,
                segments: segs
            )
        )
    }

    func configureFormat(sampleRate: Double, isNonInterleaved: Bool) {
        lock.withLock { state in
            if sampleRate > 1000 {
                state.sampleRate = sampleRate
            }
            state.isNonInterleaved = isNonInterleaved
        }
    }

    func update(clips: [TimelineClip], isLayerMuted: Bool, playheadSec: Double?) {
        let segs = Self.buildSegments(from: clips)
        lock.withLock { state in
            state.isLayerMuted = isLayerMuted
            state.segments = segs
            if let playheadSec, playheadSec.isFinite, playheadSec >= 0 {
                state.estimatedPlayheadSec = playheadSec
            }
        }
    }

    func readAndAdvanceChannelGains(
        frameCount: Int,
        sampleTimeSec: Double?
    ) -> (startL: Float, endL: Float, startR: Float, endR: Float, isNonInterleaved: Bool) {
        lock.withLock { state in
            let nonInterleaved = state.isNonInterleaved
            if state.isLayerMuted {
                let sL = state.currentSmoothedLeftGain
                let sR = state.currentSmoothedRightGain
                state.currentSmoothedLeftGain = 0.0
                state.currentSmoothedRightGain = 0.0
                return (sL, 0.0, sR, 0.0, nonInterleaved)
            }
            let effectiveTime: Double?
            if let t = sampleTimeSec, t.isFinite, t >= 0 {
                effectiveTime = t
            } else {
                effectiveTime = state.estimatedPlayheadSec
            }
            let (targetL, targetR) = Self.resolveChannelGains(from: state.segments, playheadSec: effectiveTime)
            if let cur = effectiveTime {
                let dt = Double(max(0, frameCount)) / max(8000.0, state.sampleRate)
                state.estimatedPlayheadSec = cur + dt
            }
            let sL = state.currentSmoothedLeftGain
            let sR = state.currentSmoothedRightGain
            state.currentSmoothedLeftGain = targetL
            state.currentSmoothedRightGain = targetR
            return (sL, targetL, sR, targetR, nonInterleaved)
        }
    }

    /// Trả về hệ số gain mục tiêu hiện tại (dùng cho Unit Test kiểm chứng).
    var currentTargetGain: Float {
        lock.withLock { state in
            if state.isLayerMuted { return 0.0 }
            let (l, r) = Self.resolveChannelGains(from: state.segments, playheadSec: state.estimatedPlayheadSec)
            return max(l, r)
        }
    }

    /// Trả về cặp gain Trái/Phải hiện tại tại thời điểm `playheadSec` (dùng cho Unit Test kiểm chứng `Fade` & `Balance/Pan`).
    func evaluateChannelGains(at playheadSec: Double?) -> (left: Float, right: Float) {
        lock.withLock { state in
            if state.isLayerMuted { return (0.0, 0.0) }
            return Self.resolveChannelGains(from: state.segments, playheadSec: playheadSec ?? state.estimatedPlayheadSec)
        }
    }

    private static func buildSegments(from clips: [TimelineClip]) -> [ClipAudioSegment] {
        clips
            .sorted { $0.timeRange.start < $1.timeRange.start }
            .map { clip in
                let startSec = max(0.0, CMTimeGetSeconds(clip.timeRange.start))
                let endSec = max(startSec, CMTimeGetSeconds(clip.timeRange.end))
                let dur = max(0.0, endSec - startSec)
                let rawVol = Float(max(0.0, min(Double(maxAllowedVolume), clip.properties["volume"]?.asNumber ?? 1.0)))
                var fadeIn = max(0.0, clip.properties["fadeIn"]?.asNumber ?? 0.0)
                var fadeOut = max(0.0, clip.properties["fadeOut"]?.asNumber ?? 0.0)
                if dur > 0 && (fadeIn + fadeOut) > dur {
                    let ratio = dur / (fadeIn + fadeOut)
                    fadeIn *= ratio
                    fadeOut *= ratio
                }
                let pan = Float(max(-1.0, min(1.0, clip.properties["pan"]?.asNumber ?? 0.0)))
                return ClipAudioSegment(
                    clipID: clip.id,
                    startSec: startSec,
                    endSec: endSec,
                    volume: rawVol,
                    fadeInSec: fadeIn,
                    fadeOutSec: fadeOut,
                    pan: pan
                )
            }
    }

    private static func resolveChannelGains(
        from segments: [ClipAudioSegment],
        playheadSec: Double?
    ) -> (left: Float, right: Float) {
        guard !segments.isEmpty else { return (1.0, 1.0) }
        let selected: ClipAudioSegment
        if let t = playheadSec, t.isFinite {
            if let active = segments.first(where: { t >= $0.startSec - 0.02 && t <= $0.endSec + 0.02 }) {
                selected = active
            } else {
                selected = segments[0]
            }
        } else {
            selected = segments[0]
        }
        let (gain, pan) = selected.gainAndPan(at: playheadSec)
        let leftPan: Float = pan > 0 ? max(0.0, 1.0 - pan) : 1.0
        let rightPan: Float = pan < 0 ? max(0.0, 1.0 + pan) : 1.0
        return (gain * leftPan, gain * rightPan)
    }

    static func makeTapProcessor(controller: TimelineAudioGainTap) -> MTAudioProcessingTap? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(controller).toOpaque()),
            init: tapInitCallback,
            finalize: tapFinalizeCallback,
            prepare: tapPrepareCallback,
            unprepare: tapUnprepareCallback,
            process: tapProcessCallback
        )
        var tapOut: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PreEffects,
            &tapOut
        )
        guard status == noErr, let tapOut else { return nil }
        return tapOut.takeRetainedValue()
    }

    @inline(__always)
    static func softLimit(_ sample: Float) -> Float {
        let knee: Float = 0.85
        let absVal = abs(sample)
        if absVal <= knee { return sample }
        let headroom: Float = 1.0 - knee
        let excess = (absVal - knee) / headroom
        let compressed = knee + headroom * Float(tanh(Double(excess)))
        return sample >= 0 ? compressed : -compressed
    }
}

private let tapInitCallback: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
    tapStorageOut.pointee = clientInfo
}

private let tapFinalizeCallback: MTAudioProcessingTapFinalizeCallback = { tap in
    let storage = MTAudioProcessingTapGetStorage(tap)
    Unmanaged<TimelineAudioGainTap>.fromOpaque(storage).release()
}

private let tapPrepareCallback: MTAudioProcessingTapPrepareCallback = { tap, _, processingFormat in
    let storage = MTAudioProcessingTapGetStorage(tap)
    let controller = Unmanaged<TimelineAudioGainTap>.fromOpaque(storage).takeUnretainedValue()
    let nonInterleaved = (processingFormat.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0
    controller.configureFormat(sampleRate: processingFormat.pointee.mSampleRate, isNonInterleaved: nonInterleaved)
}

private let tapUnprepareCallback: MTAudioProcessingTapUnprepareCallback = { _ in }

private let tapProcessCallback: MTAudioProcessingTapProcessCallback = {
    tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
    var timeRange = CMTimeRange.zero
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        flagsOut,
        &timeRange,
        numberFramesOut
    )
    guard status == noErr else { return }

    let storage = MTAudioProcessingTapGetStorage(tap)
    let controller = Unmanaged<TimelineAudioGainTap>.fromOpaque(storage).takeUnretainedValue()
    let startSec: Double? = (timeRange.start.isValid && timeRange.start.isNumeric)
        ? CMTimeGetSeconds(timeRange.start)
        : nil

    let (sL, eL, sR, eR, isNonInterleaved) = controller.readAndAdvanceChannelGains(
        frameCount: Int(numberFrames),
        sampleTimeSec: startSec
    )
    if abs(sL - 1.0) < 0.0005 && abs(eL - 1.0) < 0.0005 && abs(sR - 1.0) < 0.0005 && abs(eR - 1.0) < 0.0005 {
        return
    }

    let abl = UnsafeMutableAudioBufferListPointer(bufferListInOut)
    if isNonInterleaved || abl.count > 1 {
        for (chIdx, buffer) in abl.enumerated() {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }
            let floatCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            guard floatCount > 0 else { continue }
            let ptr = data.bindMemory(to: Float.self, capacity: floatCount)
            let startG = (chIdx == 0) ? sL : sR
            let endG = (chIdx == 0) ? eL : eR
            let denom = Float(max(1, floatCount - 1))
            for i in 0..<floatCount {
                let g = startG + (endG - startG) * (Float(i) / denom)
                ptr[i] = TimelineAudioGainTap.softLimit(ptr[i] * g)
            }
        }
    } else if let buffer = abl.first, let data = buffer.mData, buffer.mDataByteSize > 0 {
        let chCount = max(1, Int(buffer.mNumberChannels))
        let totalFloats = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let frames = totalFloats / chCount
        guard frames > 0 else { return }
        let ptr = data.bindMemory(to: Float.self, capacity: totalFloats)
        let denom = Float(max(1, frames - 1))
        for f in 0..<frames {
            let frac = Float(f) / denom
            let gL = sL + (eL - sL) * frac
            let gR = sR + (eR - sR) * frac
            let base = f * chCount
            ptr[base] = TimelineAudioGainTap.softLimit(ptr[base] * gL)
            if chCount > 1 {
                ptr[base + 1] = TimelineAudioGainTap.softLimit(ptr[base + 1] * gR)
            }
        }
    }
}
