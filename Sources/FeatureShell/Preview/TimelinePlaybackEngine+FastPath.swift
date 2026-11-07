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
            secondaryTrackIDs: currentSecondaryLayerTrackIDs,
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
            let transStructSig = layer.transitions.map { t in
                "\(t.id)-\(t.leadingClipID)-\(t.trailingClipID)-\(t.duration.value)-\(t.duration.timescale)-\(t.alignment.rawValue)"
            }
            return "\(layer.id)-[\(clipsSig.joined(separator: ","))]-T[\(transStructSig.joined(separator: ","))]"
        }.joined(separator: "|")
        return "\(aspectRatio.rawValue)::\(layersSig)"
    }

    func computePropertiesSignature(layers: [TimelineLayer]) -> String {
        layers.map { layer in
            let clipsSig = layer.clips.map { clip in
                let propSig = clip.properties.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ";")
                return "\(clip.id):[\(propSig)]"
            }
            let transPropSig = layer.transitions.map { t in
                let pSig = t.parameterValues.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ";")
                return "\(t.id):\(t.presetID):\(t.shaderType.rawValue):\(t.easing.rawValue):xfade=\(t.crossfadeAudio):msl=\(t.customMetalSource?.hashValue ?? 0):[\(pSig)]"
            }
            return "\(layer.id):hidden=\(layer.isHidden):muted=\(layer.isMuted):[\(clipsSig.joined(separator: ","))]:T[\(transPropSig.joined(separator: ","))]"
        }.joined(separator: "|")
    }
}
