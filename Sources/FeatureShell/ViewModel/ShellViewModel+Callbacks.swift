import AppKit
import AVFoundation
import CoreMedia
import Domain

extension ShellViewModel {
    func setupPlayheadCallbacks() {
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

    func setupPlaybackEngineCallbacks() {
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

    func setupTimelineCallbacks() {
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
