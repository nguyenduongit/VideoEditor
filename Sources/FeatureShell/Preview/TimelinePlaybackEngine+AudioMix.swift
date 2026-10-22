import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain

extension TimelinePlaybackEngine {
    public func updateAudioMix(layers: [TimelineLayer], forceResume: Bool = false) {
        guard let currentItem = player.currentItem else { return }
        let wasPlaying = forceResume || isPlaybackActive || (player.rate != 0)
        if wasPlaying {
            isPlaybackActive = true
        }
        applyAudioMix(layers: layers, to: currentItem)
        lastPropertiesSignature = computePropertiesSignature(layers: layers)
        if wasPlaying {
            resumeIfActive()
        }
    }

    func applyAudioMix(layers: [TimelineLayer], to item: AVPlayerItem) {
        let audioMix = AVMutableAudioMix()
        var inputParams: [AVMutableAudioMixInputParameters] = []

        for layer in layers {
            guard let trackIDs = layerAudioTrackIDs[layer.id] else { continue }
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

        audioMix.inputParameters = inputParams
        item.audioMix = audioMix

        let pitchPreserved = layers.flatMap(\.clips).allSatisfy { clip in
            clip.properties["pitchPreservation"]?.asBool ?? true
        }
        let targetAlgorithm: AVAudioTimePitchAlgorithm = pitchPreserved ? .timeDomain : .varispeed
        if item.audioTimePitchAlgorithm != targetAlgorithm {
            item.audioTimePitchAlgorithm = targetAlgorithm
        }
    }

    private func configureClipAudioRamps(for clips: [TimelineClip], into params: AVMutableAudioMixInputParameters) {
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
            applySingleClipAudio(params: params, volume: volume, start: start, end: end, fadeIn: fadeIn, fadeOut: fadeOut)

            if index + 1 < sorted.count {
                let nextStart = sorted[index + 1].timeRange.start
                if nextStart > end {
                    let gapRange = CMTimeRange(start: end, duration: CMTimeSubtract(nextStart, end))
                    params.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: 0.0, timeRange: gapRange)
                }
            }
        }
    }

    private func applySingleClipAudio(
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
}
