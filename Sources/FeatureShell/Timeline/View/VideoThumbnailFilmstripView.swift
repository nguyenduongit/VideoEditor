import SwiftUI
import AppKit
import CoreMedia
import Domain
import DesignSystem

@MainActor
enum FilmstripMemoryCache {
    static let cache = LRUCache<String, [Int: NSImage]>(capacity: 64)
}

public struct VideoThumbnailFilmstripView: View {
    private let clip: TimelineClip
    private let activeSourceStartTime: CMTime
    private let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    private let waveformService: (any AudioWaveformServiceProtocol)?
    private let pixelsPerSecond: CGFloat
    private let width: CGFloat
    private let height: CGFloat
    private let isMuted: Bool

    @State private var thumbnails: [Int: NSImage]

    public init(
        clip: TimelineClip,
        activeSourceStartTime: CMTime? = nil,
        thumbnailService: (any TimelineThumbnailServiceProtocol)?,
        waveformService: (any AudioWaveformServiceProtocol)?,
        pixelsPerSecond: CGFloat,
        width: CGFloat,
        height: CGFloat,
        isMuted: Bool = false
    ) {
        self.clip = clip
        let resolvedStart = activeSourceStartTime ?? clip.sourceStartTime
        self.activeSourceStartTime = resolvedStart
        self.thumbnailService = thumbnailService
        self.waveformService = waveformService
        self.pixelsPerSecond = pixelsPerSecond
        self.width = width
        self.height = height
        self.isMuted = isMuted

        let key = "\(clip.id)_\(Int(width))_\(resolvedStart.value)_\(clip.timeRange.duration.value)"
        self._thumbnails = State(initialValue: FilmstripMemoryCache.cache[key] ?? [:])
    }

    private var filmstripCacheKey: String {
        "\(clip.id)_\(Int(width))_\(activeSourceStartTime.value)_\(clip.timeRange.duration.value)"
    }

    public var body: some View {
        let waveformHeight: CGFloat = 30.0
        let filmstripHeight = max(10, height - waveformHeight)
        let thumbHeight = filmstripHeight
        let thumbWidth = max(24.0, thumbHeight * (16.0 / 9.0))
        let slotCount = max(1, Int(ceil(width / thumbWidth)))

        VStack(spacing: 0) {
            filmstrip(slotCount: slotCount, thumbWidth: thumbWidth, thumbHeight: thumbHeight)
            audioStrip
        }
        .frame(width: width, height: height)
        .clipped()
        .task(id: filmstripCacheKey) {
            await loadThumbnails(slotCount: slotCount, thumbHeight: thumbHeight)
        }
    }

    private func filmstrip(slotCount: Int, thumbWidth: CGFloat, thumbHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<slotCount, id: \.self) { i in
                if let image = thumbnails[i] {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumbWidth, height: thumbHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(DSColors.clipVideo)
                        .frame(width: thumbWidth, height: thumbHeight)
                }
            }
        }
        .frame(width: width, height: thumbHeight, alignment: .leading)
    }

    private var isAudioMuted: Bool {
        isMuted || (clip.properties["volume"]?.asNumber ?? 1.0) <= 0.001
    }

    private var audioStrip: some View {
        let inSec = clip.properties["fadeIn"]?.asNumber ?? 0.0
        let outSec = clip.properties["fadeOut"]?.asNumber ?? 0.0
        let speed = clip.properties["speed"]?.asNumber ?? 1.0
        return AudioWaveformView(
            url: clip.mediaURL,
            service: waveformService,
            sourceStartTime: activeSourceStartTime,
            sourceDuration: clip.maxDuration,
            pixelsPerSecond: pixelsPerSecond,
            fadeIn: inSec,
            fadeOut: outSec,
            clipDuration: clip.timeRange.duration,
            speed: speed
        )
        .opacity(isAudioMuted ? 0.35 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isAudioMuted)
        .frame(height: 30)
        .background(DSColors.waveformVideoBackground)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private func loadThumbnails(slotCount: Int, thumbHeight: CGFloat) async {
        let key = filmstripCacheKey
        if let cached = FilmstripMemoryCache.cache[key], cached.count >= slotCount {
            if thumbnails.count < cached.count {
                thumbnails = cached
            }
            return
        }

        guard let url = clip.mediaURL, let service = thumbnailService else { return }
        let durationSec = Double(width / pixelsPerSecond)
        guard durationSec > 0 else { return }

        let speed = max(0.01, clip.properties["speed"]?.asNumber ?? 1.0)
        var localThumbnails = thumbnails
        for i in 0..<slotCount {
            if Task.isCancelled { break }
            if localThumbnails[i] != nil { continue }
            let frac = (Double(i) + 0.5) / Double(slotCount)
            let offsetSec = frac * durationSec * speed
            let time = activeSourceStartTime + CMTime(seconds: offsetSec, preferredTimescale: 600)

            if let data = await service.generateThumbnail(for: url, at: time, targetHeight: thumbHeight * 2.0),
               let image = NSImage(data: data) {
                if !Task.isCancelled {
                    localThumbnails[i] = image
                }
            }
        }
        if !Task.isCancelled {
            thumbnails = localThumbnails
            FilmstripMemoryCache.cache[key] = localThumbnails
        }
    }
}
