import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain

extension TimelinePlaybackEngine {
    func setupTimeObserver() {
        let interval = CMTime(value: 1, timescale: TimeRational.defaultFPS)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isResyncingComposition, !self.isSeeking else { return }
                guard self.player.rate != 0 else { return }
                if let range = self.loopRange, range.duration > .zero {
                    if time >= range.end {
                        self.seek(to: range.start)
                        self.onTimeUpdate?(range.start)
                        return
                    }
                }
                self.onTimeUpdate?(time)
            }
        }
    }

    func setupPlayerObservers() {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaybackActive else { return }
                if let range = self.loopRange, range.duration > .zero {
                    self.seek(to: range.start)
                    self.onTimeUpdate?(range.start)
                    self.player.play()
                } else {
                    self.onPlaybackEnded?()
                }
            }
        }
    }

    func cleanupObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
        compositionTask?.cancel()
        compositionTask = nil
    }

    func resumeIfActive() {
        guard isPlaybackActive else { return }
        player.play()
    }
}
