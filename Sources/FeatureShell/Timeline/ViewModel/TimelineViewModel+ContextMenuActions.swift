import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func resetClipAttributes(clipID: UUID) {
        let targets = resolveActionClips(targetClipID: clipID, requireUnlocked: true)
        var commands: [TimelineCommand] = []
        for item in targets {
            let src = item.clip
            var defaults = BuiltInClipPropertyDefaults.properties(for: src.kind)
            if src.kind == .text {
                let preservedText = src.properties["textContent"]?.asString
                    ?? src.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0)?.content }
                    ?? src.name
                defaults["textContent"] = .string(preservedText)
                if let cfgJson = TextConfiguration(content: preservedText).encodeToJSON() {
                    defaults["textConfig"] = .string(cfgJson)
                }
            }
            if src.kind == .sticker, let curJson = src.properties["stickerConfig"]?.asString {
                defaults["stickerConfig"] = .string(curJson)
            }
            if let extracted = src.properties["isAudioExtracted"] {
                defaults["isAudioExtracted"] = extracted
            }
            if let beats = src.properties[AudioBeatConfiguration.propertyKey] {
                defaults[AudioBeatConfiguration.propertyKey] = beats
            }
            commands.append(.updateClipProperties(clipID: src.id, properties: defaults))
        }
        guard !commands.isEmpty, let executor = commandExecutor, !isApplyingCommand else { return }
        executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
        onClipsTrimmed?()
    }

    public func toggleClipAudioMute(clipID: UUID) {
        guard let target = clip(by: clipID), target.kind.canHaveAudio else { return }
        var props = target.properties
        let currentVol = props["volume"]?.asNumber ?? 1.0
        if currentVol <= 0.001 {
            let restoreVol = max(0.05, props["preMuteVolume"]?.asNumber ?? 1.0)
            props["volume"] = .number(restoreVol)
            props["isClipMuted"] = .bool(false)
        } else {
            props["preMuteVolume"] = .number(currentVol)
            props["volume"] = .number(0.0)
            props["isClipMuted"] = .bool(true)
        }
        commitClipProperties(clipID: clipID, properties: props)
    }

    public func toggleClipFlip(clipID: UUID, horizontal: Bool) {
        guard let target = clip(by: clipID) else { return }
        var props = target.properties
        let key = horizontal ? "flipHorizontal" : "flipVertical"
        let nextVal = !(props[key]?.asBool ?? false)
        props[key] = .bool(nextVal)
        if target.kind == .sticker,
           let json = props["stickerConfig"]?.asString,
           var cfg = StickerConfiguration.decode(from: json) {
            if horizontal { cfg.flipHorizontal = nextVal } else { cfg.flipVertical = nextVal }
            if let updatedJson = cfg.encodeToJSON() { props["stickerConfig"] = .string(updatedJson) }
        }
        commitClipProperties(clipID: clipID, properties: props)
    }

    public func resetClipTransform(clipID: UUID) {
        guard let target = clip(by: clipID) else { return }
        var props = target.properties
        for key in ["positionX", "positionY", "rotation", "skewX", "skewY", "perspectiveX", "perspectiveY"] {
            props[key] = .number(0.0)
        }
        for key in ["scale", "scaleWidth", "scaleHeight", "opacity"] {
            props[key] = .number(1.0)
        }
        props["uniformScale"] = .bool(true)
        props["flipHorizontal"] = .bool(false)
        props["flipVertical"] = .bool(false)
        if target.kind == .text,
           let json = props["textConfig"]?.asString,
           var cfg = TextConfiguration.decode(from: json) {
            cfg.positionX = 0; cfg.positionY = 0; cfg.scale = 1.0
            cfg.rotation = 0; cfg.skewX = 0; cfg.skewY = 0; cfg.opacity = 1.0
            if let updated = cfg.encodeToJSON() { props["textConfig"] = .string(updated) }
        }
        commitClipProperties(clipID: clipID, properties: props)
    }

    public func setClipSpeedPreset(clipID: UUID, speed: Double) {
        guard let target = clip(by: clipID) else { return }
        var props = target.properties
        props["speed"] = .number(speed)
        if target.kind == .sticker {
            if let json = props["stickerConfig"]?.asString, var cfg = StickerConfiguration.decode(from: json) {
                cfg.playbackSpeed = speed
                if let updated = cfg.encodeToJSON() { props["stickerConfig"] = .string(updated) }
            }
            commitClipProperties(clipID: clipID, properties: props)
            return
        }
        applySpeedChange(clipID: clipID, newProperties: props, oldProperties: target.properties)
    }

    public func setClipDurationPreset(clipID: UUID, seconds: Double) {
        guard let layer = layers.first(where: { !$0.isLocked && $0.clips.contains(where: { $0.id == clipID }) }),
              let target = layer.clips.first(where: { $0.id == clipID }),
              !target.kind.hasFixedSourceDuration else { return }
        let desiredDur = CMTime(seconds: max(0.2, seconds), preferredTimescale: 600)
        let (_, nextClip) = layer.neighbors(of: clipID)
        var finalDur = desiredDur
        if let nextStart = nextClip?.timeRange.start {
            let maxDur = CMTimeSubtract(nextStart, target.timeRange.start)
            finalDur = CMTimeMinimum(finalDur, CMTimeMaximum(TimelineClip.minDuration, maxDur))
        }
        trimClip(clipID: clipID, in: layer.id, newStart: target.timeRange.start, newDuration: finalDur)
    }

    public func matchClipDurationToBelowOrTimeline(clipID: UUID) {
        guard let layer = layers.first(where: { !$0.isLocked && $0.clips.contains(where: { $0.id == clipID }) }),
              let target = layer.clips.first(where: { $0.id == clipID }),
              !target.kind.hasFixedSourceDuration else { return }
        let refRange = findReferenceVideoRange(for: target) ?? CMTimeRange(start: .zero, duration: totalDuration)
        guard refRange.duration >= TimelineClip.minDuration else { return }

        let (prevClip, nextClip) = layer.neighbors(of: clipID)
        let clampedStart = prevClip.map { CMTimeMaximum(refRange.start, $0.timeRange.end) } ?? CMTimeMaximum(.zero, refRange.start)
        let clampedEnd = nextClip.map { CMTimeMinimum(refRange.end, $0.timeRange.start) } ?? refRange.end
        let clampedDur = CMTimeMaximum(TimelineClip.minDuration, CMTimeSubtract(clampedEnd, clampedStart))
        trimClip(clipID: clipID, in: layer.id, newStart: clampedStart, newDuration: clampedDur)
    }

    public func setAudioFadePreset(clipID: UUID, seconds: Double) {
        guard let target = clip(by: clipID), target.kind == .audio || target.kind == .video else { return }
        var props = target.properties
        props["fadeIn"] = .number(seconds)
        props["fadeOut"] = .number(seconds)
        commitClipProperties(clipID: clipID, properties: props)
    }

    public func applyTextStyleToAllInTrack(clipID: UUID) {
        guard let layer = layers.first(where: { !$0.isLocked && $0.clips.contains(where: { $0.id == clipID }) }),
              let source = layer.clips.first(where: { $0.id == clipID }),
              source.kind == .text else { return }
        let others = layer.clips.filter { $0.id != clipID && $0.kind == .text }
        guard !others.isEmpty else { return }

        let cmds: [TimelineCommand] = others.map { target in
            let merged = TimelineClipAttributeExtractor.apply(from: source, categories: [.textStyle, .textAnimation], to: target)
            return .updateClipProperties(clipID: target.id, properties: merged)
        }
        guard let executor = commandExecutor, !isApplyingCommand else { return }
        executor.execute(cmds.count == 1 ? cmds[0] : .batch(commands: cmds))
        onClipsTrimmed?()
    }

    public func trimSelectedClipsToPlayhead(at playheadTime: CMTime, isStart: Bool) {
        let snapped = TimeRational.snapToFrame(time: playheadTime)
        var cmds: [TimelineCommand] = []
        for layer in layers where !layer.isLocked {
            for clip in layer.clips where selectedClipIDs.contains(clip.id) {
                guard snapped > clip.timeRange.start && snapped < clip.timeRange.end else { continue }
                if let cmd = makePlayheadTrimCommand(clip: clip, playhead: snapped, isStart: isStart) {
                    cmds.append(cmd)
                }
            }
        }
        guard !cmds.isEmpty, let executor = commandExecutor, !isApplyingCommand else { return }
        executor.execute(cmds.count == 1 ? cmds[0] : .batch(commands: cmds))
        onClipsTrimmed?()
    }

    private func makePlayheadTrimCommand(clip: TimelineClip, playhead: CMTime, isStart: Bool) -> TimelineCommand? {
        if isStart {
            let newDur = CMTimeSubtract(clip.timeRange.end, playhead)
            guard newDur >= TimelineClip.minDuration else { return nil }
            let newSrcStart: RationalTime?
            if clip.kind.hasFixedSourceDuration {
                let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
                let delta = CMTimeMultiplyByFloat64(CMTimeSubtract(playhead, clip.timeRange.start), multiplier: speed)
                newSrcStart = RationalTime(cmTime: CMTimeAdd(clip.sourceStartTime, delta))
            } else {
                newSrcStart = nil
            }
            return .trimClip(clipID: clip.id, newStart: RationalTime(cmTime: playhead), newDuration: RationalTime(cmTime: newDur), newSourceStart: newSrcStart)
        }
        let newDur = CMTimeSubtract(playhead, clip.timeRange.start)
        guard newDur >= TimelineClip.minDuration else { return nil }
        return .trimClip(clipID: clip.id, newStart: RationalTime(cmTime: clip.timeRange.start), newDuration: RationalTime(cmTime: newDur), newSourceStart: nil)
    }

    private func findReferenceVideoRange(for target: TimelineClip) -> CMTimeRange? {
        let baseClips = layers.filter { $0.kind == .video || $0.kind == .image }.flatMap(\.clips)
        if let under = baseClips.first(where: { $0.timeRange.start <= target.timeRange.start && $0.timeRange.end > target.timeRange.start }) {
            return under.timeRange
        }
        return baseClips.first(where: { CMTimeMaximum($0.timeRange.start, target.timeRange.start) < CMTimeMinimum($0.timeRange.end, target.timeRange.end) })?.timeRange
    }
}
