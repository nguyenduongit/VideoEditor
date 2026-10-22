import Foundation

public final class MediaSyncService {
    
    public static let shared = MediaSyncService()
    
    private let syncQueue = DispatchQueue(label: "com.quocduong.videoautoeditor.sync", qos: .userInitiated)
    private var isSyncing = false
    
    private init() {}
    
    /// Bắt đầu quá trình quét và đồng bộ
    public func startSync(
        items: [MediaItem],
        logHandler: @escaping (String) -> Void,
        progressHandler: @escaping (Double, Int, Int) -> Void, // progress (0..1), currentIndex, totalCount
        itemUpdatedHandler: @escaping (MediaItem) -> Void,
        completionHandler: @escaping (Int, Int) -> Void // (totalItems, newDownloadedCount)
    ) {
        guard !isSyncing else {
            logHandler("⚠️ Quá trình đồng bộ đang chạy, vui lòng đợi...")
            return
        }
        
        isSyncing = true
        let pendingItems = items.filter { $0.status == .pending }
        let totalCount = pendingItems.count
        
        if totalCount == 0 {
            logHandler("ℹ️ Tất cả các tệp media đã được đồng bộ trên máy cục bộ. Không có tệp mới.")
            isSyncing = false
            completionHandler(items.count, 0)
            return
        }
        
        logHandler("🚀 Bắt đầu đồng bộ \(totalCount) tệp mới xuống bộ nhớ máy...")
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            var downloadedCount = 0
            let fileManager = FileManager.default
            
            for (index, item) in pendingItems.enumerated() {
                item.status = .syncing
                item.progress = 0.1
                DispatchQueue.main.async {
                    itemUpdatedHandler(item)
                    progressHandler(Double(index) / Double(totalCount), index + 1, totalCount)
                }
                
                logHandler("⏳ [\(index + 1)/\(totalCount)] Đang xử lý: \(item.name)...")
                
                do {
                    // Kích hoạt tải tệp Ubiquitous từ iCloud nếu là tệp trên mây (tải trực tiếp tại thư mục nguồn)
                    let isUbiquitous = (try? item.sourceURL.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) ?? false
                    let isICloudFile = isUbiquitous || item.sourceURL.pathExtension.lowercased() == "icloud" || item.sourceURL.lastPathComponent.contains(".icloud")
                    
                    if isICloudFile {
                        logHandler("☁️ Đang yêu cầu iCloud tải tệp: \(item.name)...")
                        try fileManager.startDownloadingUbiquitousItem(at: item.sourceURL)
                        
                        // Đợi iCloud tải xong tệp về đĩa trực tiếp tại thư mục nguồn
                        var isDownloaded = false
                        var retryCount = 0
                        while !isDownloaded && retryCount < 120 { // Tối đa 60s
                            Thread.sleep(forTimeInterval: 0.5)
                            retryCount += 1
                            
                            if let values = try? item.sourceURL.resourceValues(forKeys: [
                                .ubiquitousItemDownloadingStatusKey,
                                .ubiquitousItemIsDownloadingKey
                            ]) {
                                if values.ubiquitousItemDownloadingStatus == .current {
                                    isDownloaded = true
                                    break
                                }
                            }
                        }
                    }
                    
                    item.status = .synced
                    item.progress = 1.0
                    try item.loadMetadataIfNeeded()
                    downloadedCount += 1
                    
                    logHandler("✅ Đã tải về máy thành công: \(item.name)")
                } catch {
                    item.status = .failed
                    item.progress = 0.0
                    logHandler("❌ Lỗi khi đồng bộ \(item.name): \(error.localizedDescription)")
                }
                
                DispatchQueue.main.async {
                    itemUpdatedHandler(item)
                    progressHandler(Double(index + 1) / Double(totalCount), index + 1, totalCount)
                }
            }
            
            self.isSyncing = false
            logHandler("🎉 ĐÃ HOÀN THÀNH ĐỒNG BỘ: \(downloadedCount)/\(totalCount) tệp mới đã được lưu vào bộ nhớ máy.")
            
            DispatchQueue.main.async {
                // NotificationService thuộc MainActor vì dùng AppKit/UserNotifications.
                NotificationService.shared.notifyCompletion(totalFiles: items.count, newDownloaded: downloadedCount)
                completionHandler(items.count, downloadedCount)
            }
        }
    }
}
