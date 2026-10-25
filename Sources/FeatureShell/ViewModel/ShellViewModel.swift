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
    public let exportViewModel = ExportViewModel()

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
        self.inspectorViewModel = InspectorViewModel(
            timelineViewModel: timelineViewModel,
            mediaLibraryViewModel: mediaLibraryViewModel
        )
        self.mediaLibraryViewModel = mediaLibraryViewModel
        let resolvedPlayhead = playheadState ?? TimelinePlayheadState(
            initialTime: timelineViewModel.currentTime,
            pixelsPerSecond: timelineViewModel.pixelsPerSecond
        )
        self.playheadState = resolvedPlayhead
        self.timelineViewModel.currentTimeProvider = { [weak resolvedPlayhead] in
            resolvedPlayhead?.currentTime ?? .zero
        }
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

    func refreshActiveVisualKind() {
        let currentTime = playheadState.currentTime
        isTimelineVideoActive = timelineViewModel.hasActiveVideoClip(at: currentTime)
        if let imageClip = timelineViewModel.activeImageClip(at: currentTime), let url = imageClip.mediaURL {
            timelinePreviewImage = playbackEngine.image(for: url)
        } else {
            timelinePreviewImage = nil
        }
    }
}