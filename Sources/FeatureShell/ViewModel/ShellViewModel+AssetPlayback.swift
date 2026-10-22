import AppKit
import AVFoundation
import Domain

extension ShellViewModel {
    func toggleAssetPlayer(_ player: AVPlayer) {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if let currentItem = player.currentItem,
               player.currentTime() >= currentItem.duration {
                player.seek(to: .zero)
            }
            player.play()
            isPlaying = true
        }
    }

    func setupAssetPlayer(with url: URL) {
        let player = AVPlayer(url: url)
        self.avPlayer = player
        self.isPlaying = false

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
            }
        }
    }

    func cleanupCurrentPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
        isPlaying = false
    }
}
