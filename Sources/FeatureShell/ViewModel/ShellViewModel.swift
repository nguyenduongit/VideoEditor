import AppKit
import AVFoundation
import Foundation
import Observation
import Domain

@Observable
@MainActor
public final class ShellViewModel {
    public let registry: TabRegistry
    public let timelineViewModel: TimelineViewModel
    public let inspectorViewModel: InspectorViewModel
    public let mediaLibraryViewModel: MediaLibraryViewModel?
    public let playheadState: TimelinePlayheadState
    public let playbackEngine = TimelinePlaybackEngine()

    public var selectedTabID: TabID
    public var isPlaying: Bool = false
    public var activePreviewAsset: MediaAsset?
    public var avPlayer: AVPlayer?
    public var previewImage: NSImage?
    public var timelinePreviewImage: NSImage?
    public var isTimelineVideoActive: Bool = false

    var endObserver: Any?

    public init(
        registry: TabRegistry,
        timelineViewModel: TimelineViewModel = TimelineViewModel(),
        mediaLibraryViewModel: MediaLibraryViewModel? = nil,
        playheadState: TimelinePlayheadState? = nil,
        initialTabID: TabID = .media,
        isPlaying: Bool = false
    ) {
        self.registry = registry
        self.timelineViewModel = timelineViewModel
        self.inspectorViewModel = InspectorViewModel(timelineViewModel: timelineViewModel)
        self.mediaLibraryViewModel = mediaLibraryViewModel
        let resolvedPlayhead = playheadState ?? TimelinePlayheadState(
            initialTime: timelineViewModel.currentTime,
            pixelsPerSecond: timelineViewModel.pixelsPerSecond
        )
        self.playheadState = resolvedPlayhead
        self.selectedTabID = initialTabID
        self.isPlaying = isPlaying

        setupPlayheadCallbacks()
        setupPlaybackEngineCallbacks()
        setupTimelineCallbacks()
        updateTimelinePreview()
    }

    public var hasTimelineClips: Bool {
        timelineViewModel.totalDuration > .zero
    }

    public var aspectRatio: CanvasAspectRatio {
        timelineViewModel.aspectRatio
    }

    public func setAspectRatio(_ ratio: CanvasAspectRatio) {
        timelineViewModel.setAspectRatio(ratio)
    }

    public var canPlayback: Bool {
        if activePreviewAsset != nil {
            return activePreviewAsset?.type == .video || activePreviewAsset?.type == .audio
        }
        return hasTimelineClips
    }

    public func selectTab(_ id: TabID) {
        selectedTabID = id
    }

    public func setPreviewAsset(_ asset: MediaAsset?) {
        // Bỏ chọn asset khi đang xem timeline (không có asset preview) là no-op:
        // không được dừng timeline playback. Click vào timeline (kể cả nút mute/hide)
        // đi qua clearSelection() -> setPreviewAsset(nil) và từng làm player bị pause.
        if asset == nil && activePreviewAsset == nil {
            return
        }
        if isPlaying && activePreviewAsset == nil {
            stopPlayback()
        }
        cleanupCurrentPlayer()
        activePreviewAsset = asset

        guard let asset else {
            previewImage = nil
            updateTimelinePreview()
            return
        }

        isPlaying = false

        switch asset.type {
        case .video, .audio:
            previewImage = nil
            setupAssetPlayer(with: asset.url)
        case .image:
            previewImage = NSImage(contentsOf: asset.url)
        }
    }

    public var onTimelineActivated: (() -> Void)?

    public func switchToTimelinePreview() {
        if activePreviewAsset != nil {
            cleanupCurrentPlayer()
            activePreviewAsset = nil
            previewImage = nil
            updateTimelinePreview()
        }
        onTimelineActivated?()
    }

    public func togglePlayPause() {
        if let player = avPlayer, activePreviewAsset != nil {
            toggleAssetPlayer(player)
        } else if hasTimelineClips {
            toggleTimelinePlayback()
        }
    }

    public func toggleTimelinePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            let total = timelineViewModel.totalDuration
            if playheadState.currentTime >= total {
                playheadState.seek(to: .zero)
                playbackEngine.seek(to: .zero)
            }
            startPlayback()
        }
    }

    public func startPlayback() {
        guard hasTimelineClips else { return }
        cleanupCurrentPlayer()
        playbackEngine.syncTimeline(
            layers: timelineViewModel.layers,
            totalDuration: timelineViewModel.totalDuration,
            aspectRatio: aspectRatio,
            targetTime: playheadState.currentTime
        )
        playbackEngine.seek(to: playheadState.currentTime)
        playbackEngine.play()
        isPlaying = true
        playheadState.setPlaying(true)
        refreshActiveVisualKind()
    }

    public func stopPlayback() {
        playbackEngine.pause()
        isPlaying = false
        playheadState.setPlaying(false)
        updateTimelinePreview()
    }

    public func updateTimelinePreview() {
        guard hasTimelineClips else {
            timelinePreviewImage = nil
            isTimelineVideoActive = false
            playbackEngine.syncTimeline(layers: [], totalDuration: .zero, aspectRatio: aspectRatio)
            if isPlaying {
                stopPlayback()
            }
            return
        }

        if playheadState.currentTime > timelineViewModel.totalDuration {
            playheadState.seek(to: timelineViewModel.totalDuration)
        }

        playbackEngine.syncTimeline(
            layers: timelineViewModel.layers,
            totalDuration: timelineViewModel.totalDuration,
            aspectRatio: aspectRatio,
            targetTime: playheadState.currentTime
        )

        if !isPlaying {
            playbackEngine.seek(to: playheadState.currentTime)
        }

        refreshActiveVisualKind()
    }

    private func refreshActiveVisualKind() {
        let currentTime = playheadState.currentTime
        isTimelineVideoActive = timelineViewModel.hasActiveVideoClip(at: currentTime)
        if let imageClip = timelineViewModel.activeImageClip(at: currentTime), let url = imageClip.mediaURL {
            timelinePreviewImage = playbackEngine.image(for: url)
        } else {
            timelinePreviewImage = nil
        }
    }

    private func setupPlayheadCallbacks() {
        playheadState.onSeek = { [weak self] targetTime in
            guard let self else { return }
            self.timelineViewModel.currentTime = targetTime
            self.switchToTimelinePreview()
            let total = self.timelineViewModel.totalDuration
            if self.isPlaying && targetTime >= total {
                self.stopPlayback()
                self.playheadState.seek(to: total)
                self.playbackEngine.seek(to: total)
            } else {
                self.playbackEngine.seek(to: targetTime)
            }
            self.refreshActiveVisualKind()
        }
        playheadState.onPlayPause = { [weak self] playing in
            guard let self else { return }
            if playing != self.isPlaying {
                self.togglePlayPause()
            }
        }
    }

    private func setupPlaybackEngineCallbacks() {
        playbackEngine.onTimeUpdate = { [weak self] time in
            guard let self, self.isPlaying else { return }
            let total = self.timelineViewModel.totalDuration
            if time >= total {
                self.playheadState.progressTime(to: total)
                self.stopPlayback()
            } else {
                if time == .zero && self.playheadState.currentTime > CMTime(value: 1, timescale: 2) {
                    return
                }
                self.playheadState.progressTime(to: time)
                self.refreshActiveVisualKind()
            }
        }
    }

    private func setupTimelineCallbacks() {
        timelineViewModel.onLayerLockToggled = { [weak self] _, _ in
            guard let self else { return }
            if self.isPlaying {
                self.stopPlayback()
            }
        }
        timelineViewModel.onLayerHideToggled = { [weak self] _, _ in
            guard let self else { return }
            let wasPlaying = self.isPlaying
            self.playbackEngine.syncTimeline(
                layers: self.timelineViewModel.layers,
                totalDuration: self.timelineViewModel.totalDuration,
                aspectRatio: self.aspectRatio,
                targetTime: self.playheadState.currentTime,
                forceResume: wasPlaying
            )
            if wasPlaying {
                self.isPlaying = true
                self.playheadState.setPlaying(true)
                self.playbackEngine.play()
            }
            self.refreshActiveVisualKind()
        }
        timelineViewModel.onLayerMuteToggled = { [weak self] _, _ in
            guard let self else { return }
            let wasPlaying = self.isPlaying
            self.playbackEngine.updateAudioMix(
                layers: self.timelineViewModel.layers,
                forceResume: wasPlaying
            )
            if wasPlaying {
                self.isPlaying = true
                self.playheadState.setPlaying(true)
                self.playbackEngine.play()
            }
        }
        timelineViewModel.onClipsDeleted = { [weak self] _ in
            guard let self else { return }
            self.updateTimelinePreview()
        }
        timelineViewModel.onClipsSplit = { [weak self] _ in
            guard let self else { return }
            self.updateTimelinePreview()
        }
        timelineViewModel.onClipsTrimmed = { [weak self] in
            guard let self else { return }
            self.updateTimelinePreview()
        }
        timelineViewModel.onAspectRatioChanged = { [weak self] _ in
            guard let self else { return }
            self.updateTimelinePreview()
        }
    }
}