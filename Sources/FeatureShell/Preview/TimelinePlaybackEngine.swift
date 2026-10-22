import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain
import os

@MainActor
public final class TimelinePlaybackEngine {
    public let player = AVPlayer()
    public var onTimeUpdate: ((CMTime) -> Void)?
    public var onPlaybackEnded: (() -> Void)?

    var timeObserver: Any?
    var statusObserver: NSKeyValueObservation?
    var rateObserver: NSKeyValueObservation?
    var layerAudioTrackIDs: [UUID: [CMPersistentTrackID]] = [:]
    var isResyncingComposition: Bool = false
    var isSeeking: Bool = false
    private var seekSequence: Int = 0
    private var imageCache: [URL: NSImage] = [:]
    var lastStructureSignature: String = ""
    public internal(set) var isPlaybackActive: Bool = false
    var lastPropertiesSignature: String = ""
    var currentComposition: AVMutableComposition?
    var currentLayerTrackIDs: [UUID: CMPersistentTrackID] = [:]
    var compositionTask: Task<Void, Never>?
    var pendingForceResume: Bool = false
    let logger = Logger(subsystem: "com.videoeditor", category: "TimelinePlaybackEngine")

    public init() {
        setupTimeObserver()
        setupPlayerObservers()
    }

    public func cleanup() {
        cleanupObservers()
    }

    public func play() {
        isPlaybackActive = true
        player.play()
    }

    public func pause() {
        isPlaybackActive = false
        player.pause()
    }

    public func seek(to time: CMTime) {
        guard time.isValid && time.isNumeric else { return }
        guard player.currentItem != nil else { return }
        let wasPlaying = isPlaybackActive || (player.rate != 0)
        isSeeking = true
        seekSequence += 1
        let currentSeq = seekSequence
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.seekSequence == currentSeq else { return }
                self.isSeeking = false
                if wasPlaying {
                    self.player.play()
                }
            }
        }
    }

    public func image(for url: URL) -> NSImage? {
        if let cached = imageCache[url] {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        imageCache[url] = image
        return image
    }

    public func syncTimeline(
        layers: [TimelineLayer],
        totalDuration: CMTime,
        aspectRatio: CanvasAspectRatio = .ratio16x9,
        targetTime: CMTime? = nil,
        forceResume: Bool = false
    ) {
        if forceResume { pendingForceResume = true }
        let structSig = computeStructureSignature(layers: layers, aspectRatio: aspectRatio)
        let propSig = computePropertiesSignature(layers: layers)

        guard totalDuration > .zero else {
            lastStructureSignature = structSig
            lastPropertiesSignature = propSig
            currentComposition = nil
            player.replaceCurrentItem(with: nil)
            return
        }

        if tryFastPathUpdate(layers: layers, totalDuration: totalDuration, aspectRatio: aspectRatio, structSig: structSig, propSig: propSig) {
            return
        }

        guard structSig != lastStructureSignature || propSig != lastPropertiesSignature else { return }
        lastStructureSignature = structSig
        lastPropertiesSignature = propSig

        compositionTask?.cancel()
        compositionTask = Task.detached(priority: .userInitiated) { [weak self] in
            let composition = AVMutableComposition()
            let tracksData = await TimelineCompositionBuilder.buildTracks(
                for: composition,
                from: layers,
                aspectRatio: aspectRatio
            )
            guard !Task.isCancelled else { return }
            await self?.applyComposedTracks(
                composition: composition,
                tracksData: tracksData,
                layers: layers,
                totalDuration: totalDuration,
                aspectRatio: aspectRatio,
                targetTime: targetTime
            )
        }
    }

    private func applyComposedTracks(
        composition: AVMutableComposition,
        tracksData: (trackMap: [UUID: [CMPersistentTrackID]], instructions: [AVMutableVideoCompositionLayerInstruction], renderSize: CGSize),
        layers: [TimelineLayer],
        totalDuration: CMTime,
        aspectRatio: CanvasAspectRatio,
        targetTime: CMTime? = nil
    ) async {
        guard !Task.isCancelled else { return }
        let playerCur = player.currentTime()
        let effectiveTime: CMTime
        if let targetTime, targetTime.isValid && targetTime.isNumeric {
            effectiveTime = targetTime
        } else if playerCur.isValid && playerCur.isNumeric {
            effectiveTime = playerCur
        } else {
            effectiveTime = .zero
        }
        let wasPlaying = pendingForceResume || (player.rate != 0)
        pendingForceResume = false

        isResyncingComposition = true
        let item = AVPlayerItem(asset: composition)
        item.seekingWaitsForVideoCompositionRendering = true
        self.layerAudioTrackIDs = tracksData.trackMap
        self.currentComposition = composition

        var trackIDs: [UUID: CMPersistentTrackID] = [:]
        let videoLayers = layers.filter { $0.kind == .video }
        for (layer, inst) in zip(videoLayers, tracksData.instructions) {
            trackIDs[layer.id] = inst.trackID
        }
        self.currentLayerTrackIDs = trackIDs

        applyAudioMix(layers: layers, to: item)

        if !tracksData.instructions.isEmpty {
            let duration = CMTimeMaximum(totalDuration, composition.duration)
            if let customComp = TimelineCompositionBuilder.buildVideoComposition(
                for: layers,
                composition: composition,
                layerTrackIDs: trackIDs,
                aspectRatio: aspectRatio,
                duration: duration
            ) {
                item.videoComposition = customComp
            } else {
                item.videoComposition = TimelineCompositionBuilder.makeVideoComposition(
                    layerInstructions: tracksData.instructions,
                    renderSize: tracksData.renderSize,
                    duration: duration
                )
            }
        }

        await applyComposedItem(item, currentTime: effectiveTime, wasPlaying: wasPlaying)
        isResyncingComposition = false
    }

    private func applyComposedItem(_ item: AVPlayerItem, currentTime: CMTime, wasPlaying: Bool) async {
        item.seekingWaitsForVideoCompositionRendering = true
        player.replaceCurrentItem(with: item)
        let validTime = (currentTime.isValid && currentTime.isNumeric) ? currentTime : .zero
        await player.seek(to: validTime, toleranceBefore: .zero, toleranceAfter: .zero)
        if wasPlaying || isPlaybackActive {
            player.play()
        }
    }
}
