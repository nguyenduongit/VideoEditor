import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain

/// Extension trên `TimelineCompositionBuilder` chịu trách nhiệm tạo `AVAudioMix` dùng chung cho cả Playback và Export,
/// hỗ trợ cả rãnh đơn truyền thống lẫn cặp rãnh A/B có **Audio Crossfade** mượt mà tại các `CutTransition`.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TimelineCompositionBuilder {
    public static func buildAudioMix(
        for layers: [TimelineLayer],
        layerAudioTrackIDs: [UUID: [CMPersistentTrackID]]
    ) -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var inputParams: [AVMutableAudioMixInputParameters] = []

        for layer in layers {
            guard let trackIDs = layerAudioTrackIDs[layer.id], !trackIDs.isEmpty else { continue }
            let windows = (layer.kind == .video && trackIDs.count == 2) ? transitionWindows(for: layer) : []

            if trackIDs.count == 2 && !windows.isEmpty {
                for (parity, trackID) in trackIDs.enumerated() {
                    let params = AVMutableAudioMixInputParameters()
                    params.trackID = trackID
                    if layer.isMuted {
                        params.setVolume(0.0, at: .zero)
                    } else {
                        configureABTrackAudioRamps(
                            for: layer.clips,
                            parity: parity,
                            windows: windows,
                            into: params
                        )
                    }
                    inputParams.append(params)
                }
            } else {
                for trackID in trackIDs {
                    let params = AVMutableAudioMixInputParameters()
                    params.trackID = trackID
                    if layer.isMuted {
                        params.setVolume(0.0, at: .zero)
                    } else {
                        configureClipAudioRamps(for: layer.clips, into: params)
                    }
                    inputParams.append(params)
                }
            }
        }

        audioMix.inputParameters = inputParams
        return audioMix
    }

    private static func configureABTrackAudioRamps(
        for clips: [TimelineClip],
        parity: Int,
        windows: [ResolvedTransitionWindow],
        into params: AVMutableAudioMixInputParameters
    ) {
        let sorted = clips.sorted { $0.timeRange.start < $1.timeRange.start }
        params.setVolume(0.0, at: .zero)

        for (index, clip) in sorted.enumerated() where index % 2 == parity {
            let volume = Float(max(0.0, min(2.0, clip.properties["volume"]?.asNumber ?? 1.0)))
            let inWin = windows.first { $0.trailingIndex == index }
            let outWin = windows.first { $0.leadingIndex == index }

            var bodyStart = clip.timeRange.start
            var bodyEnd = clip.timeRange.end

            if let inWin {
                if inWin.transition.crossfadeAudio {
                    params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: volume, timeRange: inWin.range)
                    bodyStart = CMTimeMaximum(bodyStart, inWin.range.end)
                } else {
                    params.setVolume(0.0, at: inWin.range.start)
                    params.setVolume(volume, at: clip.timeRange.start)
                }
            } else {
                let fadeIn = max(0.0, clip.properties["fadeIn"]?.asNumber ?? 0.0)
                if fadeIn > 0.001 {
                    let inDur = CMTimeMinimum(clip.timeRange.duration, CMTime(seconds: fadeIn, preferredTimescale: 600))
                    params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: volume, timeRange: CMTimeRange(start: bodyStart, duration: inDur))
                    bodyStart = CMTimeAdd(bodyStart, inDur)
                }
            }

            if let outWin {
                if outWin.transition.crossfadeAudio {
                    bodyEnd = CMTimeMinimum(bodyEnd, outWin.range.start)
                }
            } else {
                let fadeOut = max(0.0, clip.properties["fadeOut"]?.asNumber ?? 0.0)
                if fadeOut > 0.001 {
                    let outDur = CMTimeMinimum(clip.timeRange.duration, CMTime(seconds: fadeOut, preferredTimescale: 600))
                    bodyEnd = CMTimeMaximum(bodyStart, CMTimeSubtract(bodyEnd, outDur))
                }
            }

            let bodyDur = CMTimeSubtract(bodyEnd, bodyStart)
            if bodyDur > .zero {
                params.setVolumeRamp(fromStartVolume: volume, toEndVolume: volume, timeRange: CMTimeRange(start: bodyStart, duration: bodyDur))
            }

            if let outWin {
                if outWin.transition.crossfadeAudio {
                    params.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0.0, timeRange: outWin.range)
                    params.setVolume(0.0, at: outWin.range.end)
                } else {
                    params.setVolume(0.0, at: clip.timeRange.end)
                }
            } else {
                let fadeOut = max(0.0, clip.properties["fadeOut"]?.asNumber ?? 0.0)
                if fadeOut > 0.001 && clip.timeRange.end > bodyEnd {
                    params.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0.0, timeRange: CMTimeRange(start: bodyEnd, duration: CMTimeSubtract(clip.timeRange.end, bodyEnd)))
                }
                params.setVolume(0.0, at: clip.timeRange.end)
            }
        }
    }

    private static func configureClipAudioRamps(for clips: [TimelineClip], into params: AVMutableAudioMixInputParameters) {
        let sorted = clips.sorted { $0.timeRange.start < $1.timeRange.start }
        if let first = sorted.first, first.timeRange.start > .zero {
            let preRange = CMTimeRange(start: .zero, duration: first.timeRange.start)
            params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 0.0, timeRange: preRange)
        }
        for (index, clip) in sorted.enumerated() {
            let volume = Float(max(0.0, min(2.0, clip.properties["volume"]?.asNumber ?? 1.0)))
            let start = clip.timeRange.start
            let end = clip.timeRange.end
            let dur = CMTimeGetSeconds(clip.timeRange.duration)
            guard dur > 0 else { continue }

            var fadeIn = max(0.0, clip.properties["fadeIn"]?.asNumber ?? 0.0)
            var fadeOut = max(0.0, clip.properties["fadeOut"]?.asNumber ?? 0.0)
            if (fadeIn + fadeOut) > dur {
                let ratio = dur / (fadeIn + fadeOut)
                fadeIn *= ratio
                fadeOut *= ratio
            }
            if let kfMap = ClipKeyframeMap.from(clip: clip), kfMap.hasKeyframes(for: "volume") {
                applyKeyframedClipAudio(
                    params: params,
                    clip: clip,
                    kfMap: kfMap,
                    baseVolume: Double(volume),
                    fadeIn: fadeIn,
                    fadeOut: fadeOut
                )
            } else {
                applySingleClipAudio(params: params, volume: volume, start: start, end: end, fadeIn: fadeIn, fadeOut: fadeOut)
            }

            if index + 1 < sorted.count {
                let nextStart = sorted[index + 1].timeRange.start
                if nextStart > end {
                    let gapRange = CMTimeRange(start: end, duration: CMTimeSubtract(nextStart, end))
                    params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 0.0, timeRange: gapRange)
                }
            }
        }
    }

    private static func applySingleClipAudio(
        params: AVMutableAudioMixInputParameters,
        volume: Float,
        start: CMTime,
        end: CMTime,
        fadeIn: Double,
        fadeOut: Double
    ) {
        var bodyStart = start
        var bodyEnd = end

        if fadeIn > 0.001 {
            let inDur = CMTime(seconds: fadeIn, preferredTimescale: 600)
            params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: volume, timeRange: CMTimeRange(start: start, duration: inDur))
            bodyStart = start + inDur
        }

        if fadeOut > 0.001 {
            let outDur = CMTime(seconds: fadeOut, preferredTimescale: 600)
            let outStart = CMTimeSubtract(end, outDur)
            params.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0.0, timeRange: CMTimeRange(start: outStart, duration: outDur))
            bodyEnd = outStart
        }

        let bodyDur = CMTimeSubtract(bodyEnd, bodyStart)
        if bodyDur > .zero {
            params.setVolumeRamp(fromStartVolume: volume, toEndVolume: volume, timeRange: CMTimeRange(start: bodyStart, duration: bodyDur))
        }

        params.setVolume(0.0, at: end)
    }

    private static func applyKeyframedClipAudio(
        params: AVMutableAudioMixInputParameters,
        clip: TimelineClip,
        kfMap: ClipKeyframeMap,
        baseVolume: Double,
        fadeIn: Double,
        fadeOut: Double
    ) {
        let start = clip.timeRange.start
        let end = clip.timeRange.end
        let dur = CMTimeGetSeconds(clip.timeRange.duration)
        guard dur > 0.001 else { return }

        let steps = max(4, min(120, Int((dur / 0.05).rounded(.up))))
        let stepSec = dur / Double(steps)

        for i in 0..<steps {
            let t0 = Double(i) * stepSec
            let t1 = min(dur, Double(i + 1) * stepSec)
            let segDur = t1 - t0
            guard segDur > 0.0001 else { continue }

            let v0 = Float(effectiveKeyframedVolume(at: t0, dur: dur, baseVolume: baseVolume, kfMap: kfMap, fadeIn: fadeIn, fadeOut: fadeOut))
            let v1 = Float(effectiveKeyframedVolume(at: t1, dur: dur, baseVolume: baseVolume, kfMap: kfMap, fadeIn: fadeIn, fadeOut: fadeOut))
            let segStart = CMTimeAdd(start, CMTime(seconds: t0, preferredTimescale: 600))
            let segRange = CMTimeRange(start: segStart, duration: CMTime(seconds: segDur, preferredTimescale: 600))
            params.setVolumeRamp(fromStartVolume: v0, toEndVolume: v1, timeRange: segRange)
        }
        params.setVolume(0.0, at: end)
    }

    private static func effectiveKeyframedVolume(
        at localTime: Double,
        dur: Double,
        baseVolume: Double,
        kfMap: ClipKeyframeMap,
        fadeIn: Double,
        fadeOut: Double
    ) -> Double {
        var vol = KeyframeEvaluator.evaluate(propertyKey: "volume", baseValue: baseVolume, atLocalTime: localTime, map: kfMap)
        if fadeIn > 0.001 && localTime < fadeIn {
            vol *= max(0.0, min(1.0, localTime / fadeIn))
        }
        if fadeOut > 0.001 && localTime > (dur - fadeOut) {
            vol *= max(0.0, min(1.0, (dur - localTime) / fadeOut))
        }
        return max(0.0, min(2.0, vol))
    }
}
