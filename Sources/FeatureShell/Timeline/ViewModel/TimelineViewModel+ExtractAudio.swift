import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Determines whether the currently selected video clip can have its audio extracted.
    public var canExtractAudio: Bool {
        guard selectedClipIDs.count == 1,
              let clipID = selectedClipIDs.first,
              let clip = clip(by: clipID),
              clip.kind == .video,
              clip.mediaURL != nil,
              clip.properties["isAudioExtracted"]?.asBool != true else {
            return false
        }
        return true
    }

    /// Extracts the audio track from the selected video clip into an independent .audio clip.
    /// The original video clip's audio is disabled (volume: 0, isAudioExtracted: true) and renders silence.
    /// The new .audio clip is placed on a compatible audio track with identical timeRange, sourceStartTime, and speed.
    @discardableResult
    public func extractAudio(clipID: UUID? = nil) -> UUID? {
        let targetClipID = clipID ?? selectedClipIDs.first
        guard let targetClipID,
              let videoClip = clip(by: targetClipID),
              videoClip.kind == .video,
              let mediaURL = videoClip.mediaURL,
              videoClip.properties["isAudioExtracted"]?.asBool != true else {
            return nil
        }

        // 1. Prepare properties for the extracted audio clip
        var audioProps = dependencies.propertyRegistry.defaultProperties(for: .audio)
        if let speed = videoClip.properties["speed"] { audioProps["speed"] = speed }
        if let vol = videoClip.properties["volume"] { audioProps["volume"] = vol }
        if let fi = videoClip.properties["fadeIn"] { audioProps["fadeIn"] = fi }
        if let fo = videoClip.properties["fadeOut"] { audioProps["fadeOut"] = fo }

        let audioClipID = UUID()
        let audioClip = TimelineClip(
            id: audioClipID,
            assetID: videoClip.assetID,
            name: "\(videoClip.name) (Audio)",
            kind: .audio,
            timeRange: videoClip.timeRange,
            maxDuration: videoClip.maxDuration,
            mediaURL: mediaURL,
            sourceStartTime: videoClip.sourceStartTime,
            properties: audioProps
        )

        // 2. Allocate an audio layer without collision (or create a new audio layer)
        var simulatedLayers = layers
        let targetAudioLayerID = allocateLayerID(for: audioClip, in: &simulatedLayers)

        // 3. Prepare muted properties for the video clip (video no sound)
        var updatedVideoProps = videoClip.properties
        updatedVideoProps["isAudioExtracted"] = .bool(true)
        updatedVideoProps["volume"] = .number(0.0)

        // 4. Execute as an atomic batch command for seamless 1-step Undo / Redo
        if let executor = commandExecutor, !isApplyingCommand {
            let updateVideoCmd = TimelineCommand.updateClipProperties(
                clipID: videoClip.id,
                properties: updatedVideoProps
            )
            let addAudioCmd = TimelineCommand.addClip(
                layerID: targetAudioLayerID,
                clip: audioClip.toScript()
            )
            let success = executor.execute(.batch(commands: [updateVideoCmd, addAudioCmd]))
            if success {
                backgroundAnalyzeBeats(for: audioClip.id, url: mediaURL)
                selectedClipIDs = [audioClip.id]
                onClipsTrimmed?()
                return audioClip.id
            }
        }

        // Direct fallback if command executor is absent
        updateClipLiveProperties(clipID: videoClip.id, properties: updatedVideoProps)
        applyAddedClips([(clip: audioClip, targetLayerID: targetAudioLayerID)])
        backgroundAnalyzeBeats(for: audioClip.id, url: mediaURL)
        selectedClipIDs = [audioClip.id]
        onClipsTrimmed?()
        return audioClip.id
    }
}

