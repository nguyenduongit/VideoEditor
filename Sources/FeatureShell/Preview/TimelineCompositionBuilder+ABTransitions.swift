import Foundation
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

/// Mở rộng `TimelineCompositionBuilder` cho kiến trúc Rãnh Bàn Cờ A/B (`Track A` / `Track B`),
/// Smart Media Handle (tận dụng phần cắt dư) và Boundary Frame Clamp (giữ khung hình biên khi chưa cắt),
/// đảm bảo mọi mốc cắt trên Timeline giữ nguyên 100% không làm trôi nhịp nhạc (`Beat Counter` / `Sync Audio`).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
extension TimelineCompositionBuilder {

    struct ComposedTracksResult: @unchecked Sendable {
        let trackMap: [UUID: [CMPersistentTrackID]]
        let primaryVideoTrackIDs: [UUID: CMPersistentTrackID]
        let secondaryVideoTrackIDs: [UUID: CMPersistentTrackID]
        let instructions: [AVMutableVideoCompositionLayerInstruction]
        let renderSize: CGSize
    }

    static func buildComposedTracks(
        for composition: AVMutableComposition,
        from layers: [TimelineLayer],
        aspectRatio: CanvasAspectRatio = .ratio16x9
    ) async -> ComposedTracksResult {
        var trackMap: [UUID: [CMPersistentTrackID]] = [:]
        var primaryVideoIDs: [UUID: CMPersistentTrackID] = [:]
        var secondaryVideoIDs: [UUID: CMPersistentTrackID] = [:]
        var instructions: [AVMutableVideoCompositionLayerInstruction] = []
        let canvasSize = aspectRatio.renderSize

        for layer in layers {
            let windows = (layer.kind == .video) ? transitionWindows(for: layer) : []
            if layer.kind == .video && !windows.isEmpty {
                await buildABCheckerboardTracks(
                    layer: layer, windows: windows, composition: composition,
                    trackMap: &trackMap, primaryVideoIDs: &primaryVideoIDs,
                    secondaryVideoIDs: &secondaryVideoIDs, instructions: &instructions
                )
            } else {
                await buildStandardSingleLayerTracks(
                    layer: layer, allLayers: layers, composition: composition, canvasSize: canvasSize,
                    trackMap: &trackMap, primaryVideoIDs: &primaryVideoIDs, instructions: &instructions
                )
            }
        }
        await appendCarrierVideoTrackIfNeeded(to: composition, layers: layers)
        return ComposedTracksResult(
            trackMap: trackMap, primaryVideoTrackIDs: primaryVideoIDs,
            secondaryVideoTrackIDs: secondaryVideoIDs, instructions: instructions, renderSize: canvasSize
        )
    }

    private static func buildABCheckerboardTracks(
        layer: TimelineLayer,
        windows: [ResolvedTransitionWindow],
        composition: AVMutableComposition,
        trackMap: inout [UUID: [CMPersistentTrackID]],
        primaryVideoIDs: inout [UUID: CMPersistentTrackID],
        secondaryVideoIDs: inout [UUID: CMPersistentTrackID],
        instructions: inout [AVMutableVideoCompositionLayerInstruction]
    ) async {
        let vA = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let vB = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let aA = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let aB = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        if let vA {
            primaryVideoIDs[layer.id] = vA.trackID
            let inst = AVMutableVideoCompositionLayerInstruction(assetTrack: vA)
            if layer.isHidden { inst.setOpacity(0.0, at: .zero) }
            instructions.append(inst)
        }
        if let vB { secondaryVideoIDs[layer.id] = vB.trackID }
        let audioIDs = [aA?.trackID, aB?.trackID].compactMap { $0 }
        if !audioIDs.isEmpty { trackMap[layer.id] = audioIDs }

        let sorted = layer.clips.sorted { $0.timeRange.start < $1.timeRange.start }
        var curVA: CMTime = .zero, curVB: CMTime = .zero, curAA: CMTime = .zero, curAB: CMTime = .zero
        for (idx, clip) in sorted.enumerated() {
            let inWin = windows.first { $0.trailingIndex == idx }
            let outWin = windows.first { $0.leadingIndex == idx }
            if idx % 2 == 0 {
                await insertSingleABClip(clip: clip, inWin: inWin, outWin: outWin, videoTrack: vA, audioTrack: aA, currentVideoTime: &curVA, currentAudioTime: &curAA)
            } else {
                await insertSingleABClip(clip: clip, inWin: inWin, outWin: outWin, videoTrack: vB, audioTrack: aB, currentVideoTime: &curVB, currentAudioTime: &curAB)
            }
        }
    }

    private static func buildStandardSingleLayerTracks(
        layer: TimelineLayer,
        allLayers: [TimelineLayer],
        composition: AVMutableComposition,
        canvasSize: CGSize,
        trackMap: inout [UUID: [CMPersistentTrackID]],
        primaryVideoIDs: inout [UUID: CMPersistentTrackID],
        instructions: inout [AVMutableVideoCompositionLayerInstruction]
    ) async {
        let videoTrack = (layer.kind == .video) ? composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        if let vTrack = videoTrack { primaryVideoIDs[layer.id] = vTrack.trackID }
        let audioTrack = (layer.kind == .video || layer.kind == .audio) ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) : nil
        if let aTrack = audioTrack { trackMap[layer.id, default: []].append(aTrack.trackID) }

        var layerInstruction: AVMutableVideoCompositionLayerInstruction?
        if let videoTrack {
            let inst = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            if layer.isHidden { inst.setOpacity(0.0, at: .zero) }
            layerInstruction = inst
            instructions.append(inst)
        }
        await insertLayerClips(layer, allLayers: allLayers, intoVideo: videoTrack, audio: audioTrack, layerInstruction: layerInstruction, canvasSize: canvasSize)
    }

    private static func insertSingleABClip(
        clip: TimelineClip,
        inWin: ResolvedTransitionWindow?,
        outWin: ResolvedTransitionWindow?,
        videoTrack: AVMutableCompositionTrack?,
        audioTrack: AVMutableCompositionTrack?,
        currentVideoTime: inout CMTime,
        currentAudioTime: inout CMTime
    ) async {
        guard let url = clip.mediaURL else { return }
        let asset = AVURLAsset(url: url)
        let assetDuration: CMTime
        do {
            assetDuration = try await asset.load(.duration)
        } catch {
            logger.error("AB asset duration load failed: \(error.localizedDescription)")
            return
        }
        guard CMTimeGetSeconds(assetDuration).isFinite, assetDuration > .zero else { return }

        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        let headNeeded = inWin.map { CMTimeMaximum(.zero, CMTimeSubtract(clip.timeRange.start, $0.range.start)) } ?? .zero
        let tailNeeded = outWin.map { CMTimeMaximum(.zero, CMTimeSubtract($0.range.end, clip.timeRange.end)) } ?? .zero

        if let videoTrack {
            await insertVideoWithSmartHandleAndClamp(
                clip: clip, asset: asset, assetDuration: assetDuration, speed: speed,
                headNeeded: headNeeded, tailNeeded: tailNeeded, videoTrack: videoTrack, currentVideoTime: &currentVideoTime
            )
        }
        if let audioTrack, clip.properties["isAudioExtracted"]?.asBool != true {
            await insertAudioWithSmartHandle(
                clip: clip, asset: asset, assetDuration: assetDuration, speed: speed,
                headNeeded: headNeeded, tailNeeded: tailNeeded, audioTrack: audioTrack, currentAudioTime: &currentAudioTime
            )
        }
    }

    private static func insertVideoWithSmartHandleAndClamp(
        clip: TimelineClip,
        asset: AVURLAsset,
        assetDuration: CMTime,
        speed: Double,
        headNeeded: CMTime,
        tailNeeded: CMTime,
        videoTrack: AVMutableCompositionTrack,
        currentVideoTime: inout CMTime
    ) async {
        guard let (assetVideo, trackEnd) = await loadAndCacheVideoTrack(asset: asset, fallbackDuration: assetDuration) else { return }
        let safeHeadStart = CMTimeMaximum(currentVideoTime, CMTimeMaximum(.zero, CMTimeSubtract(clip.timeRange.start, headNeeded)))
        let effHead = CMTimeMaximum(.zero, CMTimeSubtract(clip.timeRange.start, safeHeadStart))
        if safeHeadStart > currentVideoTime {
            videoTrack.insertEmptyTimeRange(CMTimeRange(start: currentVideoTime, duration: CMTimeSubtract(safeHeadStart, currentVideoTime)))
            currentVideoTime = safeHeadStart
        }

        let handleHead = CMTimeMinimum(effHead, CMTimeMultiplyByFloat64(CMTimeMaximum(.zero, clip.sourceStartTime), multiplier: 1.0 / speed))
        let clampHead = CMTimeMaximum(.zero, CMTimeSubtract(effHead, handleHead))
        if clampHead > .zero {
            insertClampedBoundaryFrame(from: assetVideo, atSourceStart: .zero, trackEnd: trackEnd, duration: clampHead, into: videoTrack, at: &currentVideoTime)
        }
        if handleHead > .zero {
            let srcHead = CMTimeMultiplyByFloat64(handleHead, multiplier: speed)
            insertScaledSegment(from: assetVideo, sourceRange: CMTimeRange(start: CMTimeMaximum(.zero, CMTimeSubtract(clip.sourceStartTime, srcHead)), duration: srcHead), targetDuration: handleHead, into: videoTrack, at: &currentVideoTime)
        }

        let bodySrc = CMTimeMinimum(CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: speed), CMTimeMaximum(.zero, CMTimeSubtract(trackEnd, clip.sourceStartTime)))
        if bodySrc > .zero {
            insertScaledSegment(from: assetVideo, sourceRange: CMTimeRange(start: clip.sourceStartTime, duration: bodySrc), targetDuration: clip.timeRange.duration, into: videoTrack, at: &currentVideoTime)
        }
        appendVideoTailHandleAndClamp(assetVideo: assetVideo, bodySrcEnd: CMTimeAdd(clip.sourceStartTime, bodySrc), trackEnd: trackEnd, speed: speed, tailNeeded: tailNeeded, into: videoTrack, at: &currentVideoTime)
    }

    private static func loadAndCacheVideoTrack(asset: AVURLAsset, fallbackDuration: CMTime) async -> (AVAssetTrack, CMTime)? {
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let range = try await track.load(.timeRange)
            if metadataCache.metadata(for: asset.url) == nil {
                let transform = try await track.load(.preferredTransform)
                let naturalSize = try await track.load(.naturalSize)
                metadataCache.store(VideoTrackMetadata(transform: transform, naturalSize: naturalSize), for: asset.url)
            }
            return (track, range.end > .zero ? range.end : fallbackDuration)
        } catch {
            logger.error("AB video track load failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func appendVideoTailHandleAndClamp(
        assetVideo: AVAssetTrack,
        bodySrcEnd: CMTime,
        trackEnd: CMTime,
        speed: Double,
        tailNeeded: CMTime,
        into videoTrack: AVMutableCompositionTrack,
        at cursor: inout CMTime
    ) {
        let availTailTimeline = CMTimeMultiplyByFloat64(CMTimeMaximum(.zero, CMTimeSubtract(trackEnd, bodySrcEnd)), multiplier: 1.0 / speed)
        let handleTail = CMTimeMinimum(tailNeeded, availTailTimeline)
        let clampTail = CMTimeMaximum(.zero, CMTimeSubtract(tailNeeded, handleTail))
        if handleTail > .zero {
            let srcTail = CMTimeMultiplyByFloat64(handleTail, multiplier: speed)
            insertScaledSegment(from: assetVideo, sourceRange: CMTimeRange(start: bodySrcEnd, duration: srcTail), targetDuration: handleTail, into: videoTrack, at: &cursor)
        }
        if clampTail > .zero {
            let lastStart = CMTimeMaximum(.zero, CMTimeSubtract(trackEnd, CMTime(value: 20, timescale: 600)))
            insertClampedBoundaryFrame(from: assetVideo, atSourceStart: lastStart, trackEnd: trackEnd, duration: clampTail, into: videoTrack, at: &cursor)
        }
    }

    private static func insertScaledSegment(
        from assetTrack: AVAssetTrack,
        sourceRange: CMTimeRange,
        targetDuration: CMTime,
        into track: AVMutableCompositionTrack,
        at cursor: inout CMTime
    ) {
        guard sourceRange.duration > .zero, targetDuration > .zero else { return }
        do {
            let insertAt = cursor
            try track.insertTimeRange(sourceRange, of: assetTrack, at: insertAt)
            let inserted = CMTimeMaximum(.zero, CMTimeSubtract(track.timeRange.end, insertAt))
            if inserted > .zero && abs(CMTimeGetSeconds(inserted) - CMTimeGetSeconds(targetDuration)) > 0.001 {
                track.scaleTimeRange(CMTimeRange(start: insertAt, duration: inserted), toDuration: targetDuration)
            }
            cursor = CMTimeAdd(insertAt, targetDuration)
        } catch {
            logger.error("AB segment insert failed: \(error.localizedDescription)")
        }
    }

    private static func insertClampedBoundaryFrame(
        from assetTrack: AVAssetTrack,
        atSourceStart: CMTime,
        trackEnd: CMTime,
        duration: CMTime,
        into track: AVMutableCompositionTrack,
        at cursor: inout CMTime
    ) {
        let oneFrame = CMTimeMinimum(CMTime(value: 20, timescale: 600), CMTimeMaximum(.zero, CMTimeSubtract(trackEnd, atSourceStart)))
        guard oneFrame > .zero, duration > .zero else { return }
        insertScaledSegment(from: assetTrack, sourceRange: CMTimeRange(start: atSourceStart, duration: oneFrame), targetDuration: duration, into: track, at: &cursor)
    }

    private static func insertAudioWithSmartHandle(
        clip: TimelineClip,
        asset: AVURLAsset,
        assetDuration: CMTime,
        speed: Double,
        headNeeded: CMTime,
        tailNeeded: CMTime,
        audioTrack: AVMutableCompositionTrack,
        currentAudioTime: inout CMTime
    ) async {
        let assetAudio: AVAssetTrack?
        do { assetAudio = try await asset.loadTracks(withMediaType: .audio).first } catch { assetAudio = nil }
        let handleHead = CMTimeMinimum(headNeeded, CMTimeMultiplyByFloat64(CMTimeMaximum(.zero, clip.sourceStartTime), multiplier: 1.0 / speed))
        let headStart = CMTimeMaximum(currentAudioTime, CMTimeSubtract(clip.timeRange.start, handleHead))
        if headStart > currentAudioTime {
            audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: CMTimeSubtract(headStart, currentAudioTime)))
            currentAudioTime = headStart
        }
        guard let assetAudio else {
            let emptyDur = CMTimeMaximum(.zero, CMTimeSubtract(clip.timeRange.end, currentAudioTime))
            if emptyDur > .zero { audioTrack.insertEmptyTimeRange(CMTimeRange(start: currentAudioTime, duration: emptyDur)); currentAudioTime = clip.timeRange.end }
            return
        }
        let effHead = CMTimeMaximum(.zero, CMTimeSubtract(clip.timeRange.start, currentAudioTime))
        if effHead > .zero {
            let srcHead = CMTimeMultiplyByFloat64(effHead, multiplier: speed)
            insertScaledSegment(from: assetAudio, sourceRange: CMTimeRange(start: CMTimeMaximum(.zero, CMTimeSubtract(clip.sourceStartTime, srcHead)), duration: srcHead), targetDuration: effHead, into: audioTrack, at: &currentAudioTime)
        }
        let bodySrc = CMTimeMinimum(CMTimeMultiplyByFloat64(clip.timeRange.duration, multiplier: speed), CMTimeMaximum(.zero, CMTimeSubtract(assetDuration, clip.sourceStartTime)))
        insertScaledSegment(from: assetAudio, sourceRange: CMTimeRange(start: clip.sourceStartTime, duration: bodySrc), targetDuration: clip.timeRange.duration, into: audioTrack, at: &currentAudioTime)
        let bodySrcEnd = CMTimeAdd(clip.sourceStartTime, bodySrc)
        let handleTail = CMTimeMinimum(tailNeeded, CMTimeMultiplyByFloat64(CMTimeMaximum(.zero, CMTimeSubtract(assetDuration, bodySrcEnd)), multiplier: 1.0 / speed))
        if handleTail > .zero {
            insertScaledSegment(from: assetAudio, sourceRange: CMTimeRange(start: bodySrcEnd, duration: CMTimeMultiplyByFloat64(handleTail, multiplier: speed)), targetDuration: handleTail, into: audioTrack, at: &currentAudioTime)
        }
    }
}
