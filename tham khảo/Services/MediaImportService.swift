import Foundation
import AVFoundation

struct ImportedMediaSource {
    let identity: SourceIdentity
    let duration: Double
    let isVideo: Bool
}

enum MediaImportService {
    static func load(_ urls: [URL]) throws -> [ImportedMediaSource] {
        guard (1...2).contains(urls.count) else {
            throw EditorError.message("Mỗi lần chỉ nhập tối đa một video và một audio.")
        }
        var imported: [ImportedMediaSource] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if values.isUbiquitousItem == true { try FileManager.default.startDownloadingUbiquitousItem(at: url) }
            let asset = AVURLAsset(url: url)
            let duration = asset.duration.seconds
            guard duration.isFinite, duration > 0 else {
                throw EditorError.message("Không đọc được \(url.lastPathComponent). Nếu là file iCloud, đợi tải xong rồi nhập lại.")
            }
            let isVideo = !asset.tracks(withMediaType: .video).isEmpty
            let isAudio = !asset.tracks(withMediaType: .audio).isEmpty
            guard isVideo || isAudio else { throw EditorError.message("\(url.lastPathComponent) không có track video hoặc audio hợp lệ.") }
            let source = ImportedMediaSource(identity: SourceIdentity(url: url), duration: duration, isVideo: isVideo)
            if imported.contains(where: { $0.isVideo == source.isVideo }) {
                throw EditorError.message(isVideo ? "Chỉ được chọn một video mỗi lần." : "Chỉ được chọn một audio mỗi lần.")
            }
            imported.append(source)
        }
        return imported
    }
}
