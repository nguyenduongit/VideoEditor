import AppKit
@preconcurrency import AVFoundation
import CoreMedia
import Domain

extension TimelinePlaybackEngine {
    func setupTimeObserver() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isResyncingComposition, !self.isSeeking else { return }
                if self.isPlaybackActive && self.player.rate == 0 {
                    self.player.play()
                }
                guard self.player.rate != 0 else { return }
                self.onTimeUpdate?(time)
            }
        }
    }

    func setupPlayerObservers() {
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaybackActive, !self.isSeeking, !self.isResyncingComposition else { return }
                if player.rate == 0 && player.timeControlStatus == .paused {
                    self.player.play()
                }
            }
        }
        statusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaybackActive, !self.isSeeking, !self.isResyncingComposition else { return }
                if player.timeControlStatus == .paused {
                    self.player.play()
                }
            }
        }
    }

    func cleanupObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
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
        Task { @MainActor [weak self] in
            guard let self, self.isPlaybackActive else { return }
            if self.player.rate == 0 {
                self.player.play()
            }
        }
    }
}
