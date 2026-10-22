import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

extension TimelinePlaybackEngine {
    func tryFastPathUpdate(
        layers: [TimelineLayer],
        totalDuration: CMTime,
        aspectRatio: CanvasAspectRatio,
        structSig: String,
        propSig: String
    ) -> Bool {
        guard structSig == lastStructureSignature,
              let composition = currentComposition,
              let currentItem = player.currentItem else {
            return false
        }
        guard propSig != lastPropertiesSignature else { return true }
        lastPropertiesSignature = propSig

        let wasPlaying = pendingForceResume || isPlaybackActive || (player.rate != 0)
        pendingForceResume = false
        if wasPlaying {
            isPlaybackActive = true
        }
        let duration = CMTimeMaximum(totalDuration, composition.duration)
        if let newVideoComp = TimelineCompositionBuilder.buildVideoComposition(
            for: layers,
            composition: composition,
            layerTrackIDs: currentLayerTrackIDs,
            aspectRatio: aspectRatio,
            duration: duration
        ) {
            let compositorChanged = (currentItem.videoComposition?.customVideoCompositorClass != newVideoComp.customVideoCompositorClass)
            logger.notice("tryFastPathUpdate: set videoComposition, hasCustom=\(newVideoComp.customVideoCompositorClass != nil), changed=\(compositorChanged)")
            if compositorChanged {
                let cur = player.currentTime()
                let newItem = AVPlayerItem(asset: composition)
                newItem.seekingWaitsForVideoCompositionRendering = true
                newItem.videoComposition = newVideoComp
                applyAudioMix(layers: layers, to: newItem)
                player.replaceCurrentItem(with: newItem)
                let validCur = (cur.isValid && cur.isNumeric) ? cur : .zero
                player.seek(to: validCur, toleranceBefore: .zero, toleranceAfter: .zero)
                if wasPlaying {
                    resumeIfActive()
                }
            } else {
                currentItem.videoComposition = newVideoComp
                applyAudioMix(layers: layers, to: currentItem)
                if wasPlaying {
                    resumeIfActive()
                } else if player.rate == 0 {
                    let cur = player.currentTime()
                    let validCur = (cur.isValid && cur.isNumeric) ? cur : .zero
                    player.seek(to: validCur, toleranceBefore: .zero, toleranceAfter: .zero)
                }
            }
        } else {
            applyAudioMix(layers: layers, to: currentItem)
            if wasPlaying {
                resumeIfActive()
            }
        }
        return true
    }

    func computeStructureSignature(layers: [TimelineLayer], aspectRatio: CanvasAspectRatio) -> String {
        let layersSig = layers.map { layer in
            let clipsSig = layer.clips.map { clip in
                let urlStr = clip.mediaURL?.absoluteString ?? ""
                let spd = clip.properties["speed"]?.asNumber ?? 1.0
                return "\(clip.id)-\(urlStr)-\(clip.timeRange.start.value)-\(clip.timeRange.duration.value)-\(clip.sourceStartTime.value)-spd:\(spd)"
            }
            return "\(layer.id)-[\(clipsSig.joined(separator: ","))]"
        }.joined(separator: "|")
        return "\(aspectRatio.rawValue)::\(layersSig)"
    }

    func computePropertiesSignature(layers: [TimelineLayer]) -> String {
        layers.map { layer in
            let clipsSig = layer.clips.map { clip in
                let propSig = clip.properties.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ";")
                return "\(clip.id):[\(propSig)]"
            }
            return "\(layer.id):hidden=\(layer.isHidden):muted=\(layer.isMuted):[\(clipsSig.joined(separator: ","))]"
        }.joined(separator: "|")
    }
}
