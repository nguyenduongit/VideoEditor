import AppKit
import SwiftUI
import Observation
import UniformTypeIdentifiers
import Domain

@Observable
@MainActor
public final class MediaLibraryViewModel {
    public var assets: [MediaAsset] = []
    public var selectedAssetIDs: Set<UUID> = []
    public var thumbnails: [UUID: Image] = [:]

    private let thumbnailService: any AssetThumbnailServiceProtocol
    private let waveformService: (any AudioWaveformServiceProtocol)?

    public var onActiveAssetChange: ((MediaAsset?) -> Void)?
    public var onAddAssetToTimeline: ((MediaAsset) -> Void)?
    public var onAddAssetsToTimeline: (([MediaAsset]) -> Void)?
    public var onAssetsDeleted: (([MediaAsset]) -> Void)?

    public func addAssetToTimeline(_ asset: MediaAsset) {
        if selectedAssetIDs.count > 1 {
            var targets = assets.filter { selectedAssetIDs.contains($0.id) }
            if !targets.contains(where: { $0.id == asset.id }) {
                targets.append(asset)
            }
            if let onAddAssetsToTimeline {
                onAddAssetsToTimeline(targets)
                return
            }
            for target in targets {
                onAddAssetToTimeline?(target)
            }
            return
        }
        onAddAssetToTimeline?(asset)
    }

    public init(
        thumbnailService: any AssetThumbnailServiceProtocol,
        waveformService: (any AudioWaveformServiceProtocol)? = nil
    ) {
        self.thumbnailService = thumbnailService
        self.waveformService = waveformService
    }

    public func importFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .audio, .image]

        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }

    public func importURLs(_ urls: [URL]) {
        for url in urls {
            guard !assets.contains(where: { $0.url == url }) else { continue }
            guard let type = MediaType.from(fileExtension: url.pathExtension) else { continue }
            let asset = MediaAsset(url: url, type: type)
            assets.append(asset)
            loadThumbnail(for: asset)
            prewarmDuration(for: asset)
            if type == .audio || type == .video {
                preloadWaveform(for: asset)
            }
        }
    }

    public func toggleSelection(for id: UUID, isCmdPressed: Bool) {
        if isCmdPressed {
            if selectedAssetIDs.contains(id) {
                selectedAssetIDs.remove(id)
            } else {
                selectedAssetIDs.insert(id)
            }
        } else {
            selectedAssetIDs = [id]
        }
        notifyActiveAssetChange()
    }

    public func selectAll(ids: Set<UUID>) {
        selectedAssetIDs = ids
        notifyActiveAssetChange()
    }

    public func clearSelection() {
        selectedAssetIDs.removeAll()
        notifyActiveAssetChange()
    }

    public func deleteSelected() {
        let deletedAssets = assets.filter { selectedAssetIDs.contains($0.id) }
        assets.removeAll { selectedAssetIDs.contains($0.id) }
        for id in selectedAssetIDs {
            thumbnails.removeValue(forKey: id)
        }
        selectedAssetIDs.removeAll()
        notifyActiveAssetChange()
        onAssetsDeleted?(deletedAssets)
    }

    public func updateDragSelection(rect: CGRect, itemFrames: [UUID: CGRect]) {
        var newSelection = Set<UUID>()
        for (id, frame) in itemFrames {
            if rect.intersects(frame) {
                newSelection.insert(id)
            }
        }
        selectedAssetIDs = newSelection
        notifyActiveAssetChange()
    }

    private func notifyActiveAssetChange() {
        if selectedAssetIDs.count == 1,
           let selectedID = selectedAssetIDs.first,
           let asset = assets.first(where: { $0.id == selectedID }) {
            onActiveAssetChange?(asset)
        } else {
            onActiveAssetChange?(nil)
        }
    }

    private func loadThumbnail(for asset: MediaAsset) {
        guard asset.type != .audio else { return }
        Task {
            do {
                if let data = try await thumbnailService.generateThumbnailData(for: asset),
                   let nsImage = NSImage(data: data) {
                    thumbnails[asset.id] = Image(nsImage: nsImage)
                    TimelineClipBlockRenderer.registerThumbnail(nsImage, for: asset.url)
                }
            } catch {
                // Non-fatal thumbnail failure, placeholder used
            }
        }
    }

    private func prewarmDuration(for asset: MediaAsset) {
        Task {
            _ = await TimelineMediaDurationResolver.resolveDurationAsync(for: asset.url, type: asset.type)
        }
    }

    private func preloadWaveform(for asset: MediaAsset) {
        guard let waveformService else { return }
        Task.detached(priority: .utility) {
            _ = await waveformService.generateWaveformPeaks(for: asset.url, samplesPerSecond: 100)
        }
    }
}

