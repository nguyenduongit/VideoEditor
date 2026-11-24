import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {

    /// Adds a single asset to the timeline at the given time or currentTime.
    public func addAsset(_ asset: MediaAsset, at time: CMTime? = nil) {
        addAssets([asset], at: time)
    }

    /// Thực thi thêm bất kỳ loại tài nguyên nào được kéo thả từ Sidebar vào đúng mốc thời gian `dropTime`.
    public func addDroppedPayload(_ payload: TimelineDragPayload, at dropTime: CMTime) {
        switch payload {
        case .media(let asset):
            addAsset(asset, at: dropTime)
        case .audio(let preset):
            if preset.id == "audio_dance_beat" {
                _ = addDanceBeatCounter(named: preset.name, at: dropTime)
            } else {
                let targetStart = TimeRational.snapToFrame(time: dropTime)
                let durSeconds = preset.duration > 0 ? preset.duration : 5.0
                let frames = max(15, Int64(round(durSeconds * Double(TimeRational.defaultFPS))))
                let duration = CMTime(value: frames, timescale: TimeRational.defaultFPS)
                let clip = TimelineClip(
                    name: preset.name,
                    kind: .audio,
                    timeRange: CMTimeRange(start: targetStart, duration: duration),
                    mediaURL: preset.audioURL
                )
                var simulatedLayers = layers
                let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
                applyAddedClips([(clip, layerID)])
                selectedClipIDs = [clip.id]
            }
        case .text(let preset):
            onPreviewTextPreset?(nil)
            onPreviewTextPresetCleared?()
            addTextPreset(preset, at: dropTime)
        case .defaultText:
            onPreviewTextPreset?(nil)
            onPreviewTextPresetCleared?()
            addTextClip(named: "Default Text", config: TextConfiguration(), durationSeconds: 5.0, at: dropTime)
        case .sticker(let item):
            addStickerItem(item, at: dropTime)
        case .effect(let item):
            addEffectClip(
                named: item.name,
                config: item.config,
                durationSeconds: item.defaultDuration,
                originPresetID: nil,
                at: dropTime
            )
        case .adjustment(let preset):
            addAdjustmentClip(
                named: preset.name,
                config: preset.config,
                originPresetID: preset.id == "default" ? nil : preset.id,
                at: dropTime
            )
        case .defaultAdjustment:
            addAdjustmentClip(named: "Adjustment Layer", config: AdjustmentConfiguration(), at: dropTime)
        case .transition, .transitionID:
            break
        }
    }

    /// Adds multiple assets to the timeline at the given time or currentTime,
    /// automatically assigning each clip to an appropriate layer (avoiding collisions)
    /// and grouping the operation into a single undo/redo batch command.
    public func addAssets(_ assets: [MediaAsset], at time: CMTime? = nil) {
        guard !assets.isEmpty else { return }

        let isTimelineEmpty = !hasClips
        if isTimelineEmpty, let visual = assets.first(where: { $0.type == .video || $0.type == .image }) {
            autoAdjustAspectRatio(for: visual.url, type: visual.type)
        }

        let proposedStart = time ?? currentTime
        let targetStart = TimeRational.snapToFrame(time: proposedStart)

        var newClipsWithLayers: [(clip: TimelineClip, targetLayerID: UUID)] = []
        var simulatedLayers = layers

        for asset in assets {
            let clip = makeClip(for: asset, at: targetStart)
            let layerID = allocateLayerID(for: clip, in: &simulatedLayers)
            newClipsWithLayers.append((clip, layerID))
        }

        applyAddedClips(newClipsWithLayers)
        selectedClipIDs = Set(newClipsWithLayers.map(\.clip.id))
        resetZoom()
        onAssetsAdded?(assets)
    }

    // MARK: - Private Helpers

    private func makeClip(for asset: MediaAsset, at targetStart: CMTime) -> TimelineClip {
        let kind = asset.type.clipKind
        let defaultDuration = CMTime(value: 5 * Int64(TimeRational.defaultFPS), timescale: TimeRational.defaultFPS)

        var resolvedDuration = defaultDuration
        var maxDuration: CMTime?

        if kind.hasFixedSourceDuration {
            if let dur = TimelineMediaDurationResolver.resolveDuration(for: asset.url, type: asset.type) {
                let snapped = TimeRational.snapToFrame(time: dur)
                resolvedDuration = snapped
                maxDuration = snapped
            }
        }

        let timeRange = CMTimeRange(start: targetStart, duration: resolvedDuration)
        var props = BuiltInClipPropertyDefaults.properties(for: kind)
        if let b64 = asset.bookmarkBase64 {
            props["securityBookmark"] = .string(b64)
        } else if let bm = try? asset.url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            props["securityBookmark"] = .string(bm.base64EncodedString())
        }
        return TimelineClip(
            assetID: asset.id,
            name: asset.name,
            kind: kind,
            timeRange: timeRange,
            maxDuration: maxDuration,
            mediaURL: asset.url,
            properties: props
        )
    }

    func allocateLayerID(for clip: TimelineClip, in simulatedLayers: inout [TimelineLayer]) -> UUID {
        let candidateIndex = simulatedLayers.firstIndex { layer in
            guard layer.kind == clip.kind && !layer.isLocked && !layer.isHidden else { return false }
            return !layer.clips.contains { existing in
                existing.timeRange.intersection(clip.timeRange).duration > .zero
            }
        }

        if let index = candidateIndex {
            _ = simulatedLayers[index].appendClip(clip)
            return simulatedLayers[index].id
        }

        let count = simulatedLayers.filter { $0.kind == clip.kind }.count + 1
        let newLayerID = UUID()
        var newLayer = TimelineLayer(id: newLayerID, name: "\(clip.kind.title) \(count)", kind: clip.kind, clips: [])
        _ = newLayer.appendClip(clip)
        let insertionIndex = defaultInsertionIndex(for: clip.kind)
        simulatedLayers.insert(newLayer, at: min(insertionIndex, simulatedLayers.count))
        return newLayerID
    }

    func applyAddedClips(_ items: [(clip: TimelineClip, targetLayerID: UUID)]) {
        for item in items {
            if item.clip.kind == .audio, let url = item.clip.mediaURL {
                backgroundAnalyzeBeats(for: item.clip.id, url: url)
                backgroundExtractReactiveProfile(for: url)
            }
        }

        if let executor = commandExecutor, !isApplyingCommand {
            let commands = items.map { item in
                TimelineCommand.addClip(layerID: item.targetLayerID, clip: item.clip.toScript())
            }
            executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            return
        }

        for item in items {
            if let index = layers.firstIndex(where: { $0.id == item.targetLayerID }) {
                _ = layers[index].appendClip(item.clip)
            } else {
                let count = layers.filter { $0.kind == item.clip.kind }.count + 1
                var newLayer = TimelineLayer(id: item.targetLayerID, name: "\(item.clip.kind.title) \(count)", kind: item.clip.kind, clips: [])
                _ = newLayer.appendClip(item.clip)
                let insIdx = defaultInsertionIndex(for: item.clip.kind)
                layers.insert(newLayer, at: min(insIdx, layers.count))
            }
        }
        onClipsTrimmed?()
    }

    func checkAutoAdjustAspectRatio(for clip: TimelineClip) {
        guard !hasClips, (clip.kind == .video || clip.kind == .image), let url = clip.mediaURL else { return }
        let type: MediaType = clip.kind == .video ? .video : .image
        autoAdjustAspectRatio(for: url, type: type)
    }

    public func autoAdjustAspectRatio(for url: URL, type: MediaType) {
        if let size = TimelineMediaDimensionResolver.resolveDimension(for: url, type: type) {
            let matched = CanvasAspectRatio.closest(for: size)
            if aspectRatio != matched {
                aspectRatio = matched
                onAspectRatioChanged?(matched)
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let size = await TimelineMediaDimensionResolver.resolveDimensionAsync(for: url, type: type) {
                let matched = CanvasAspectRatio.closest(for: size)
                if self.aspectRatio != matched {
                    self.aspectRatio = matched
                    self.onAspectRatioChanged?(matched)
                }
            }
        }
    }
}
