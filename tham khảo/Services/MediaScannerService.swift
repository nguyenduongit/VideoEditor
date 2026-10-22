import Foundation
import Darwin
import AppKit

public final class MediaScannerService {
    
    public static let shared = MediaScannerService()
    
    public var defaultICloudPath: URL {
        let expanded = NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs/Chim").expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }
    
    public var defaultLocalPath: URL {
        let expanded = NSString(string: "~/Documents/VideoAutoEditor").expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }
    
    private let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "webm", "ts", "flv"
    ]
    
    private let audioExtensions: Set<String> = [
        "mp3", "m4a", "wav", "aac", "flac", "aiff", "caf", "ogg", "wma"
    ]
    
    private init() {
        // Không tự động tạo thư mục rỗng khi khởi chạy
    }
    
    public func createLocalDirectoriesIfNeeded() {
        // Giữ lại hàm nếu cần gọi thủ công, nhưng không tạo tự động khi khởi động app
    }
    
    
    /// Phân tích một file path xem có phải là Video hay Audio không
    public func detectMediaType(for filename: String) -> MediaType {
        var cleanName = filename
        if cleanName.hasPrefix(".") && cleanName.hasSuffix(".icloud") {
            cleanName = String(cleanName.dropFirst())
            cleanName = String(cleanName.dropLast(7))
        }
        
        let ext = (cleanName as NSString).pathExtension.lowercased()
        if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        }
        return .unknown
    }
    
    /// Trích xuất tên file thực tế (xử lý cả trường hợp tệp placeholder .icloud)
    public func extractRealFilename(from rawFilename: String) -> String {
        var cleanName = rawFilename
        if cleanName.hasPrefix(".") && cleanName.hasSuffix(".icloud") {
            cleanName = String(cleanName.dropFirst())
            cleanName = String(cleanName.dropLast(7))
        }
        return cleanName
    }
    
    /// Chuẩn hóa tên gốc của video (loại bỏ extension và các hậu tố xuất file như -youtube, -tiktok-short-reel, -edited...)
    public func normalizeBaseName(_ filename: String) -> String {
        var clean = extractRealFilename(from: filename)
        clean = (clean as NSString).deletingPathExtension.lowercased()
        
        let knownSuffixes = [
            "-tiktok-short-reel",
            "_tiktok-short-reel",
            "-tiktok",
            "_tiktok",
            "-youtube",
            "_youtube",
            "-short",
            "_short",
            "-reel",
            "_reel",
            "-reels",
            "_reels",
            "-edited",
            "_edited",
            "-edit",
            "_edit"
        ]
        
        for suffix in knownSuffixes {
            if clean.hasSuffix(suffix) {
                clean = String(clean.dropLast(suffix.count))
                break
            }
        }
        return clean
    }
    
    /// Đọc danh sách các video đã qua chỉnh sửa từ thư mục Output
    private func getAlreadyEditedBaseNames(in sourceURL: URL, logHandler: ((String) -> Void)? = nil) -> Set<String> {
        var editedSet: Set<String> = []
        let fileManager = FileManager.default
        
        // 1. Kiểm tra thư mục con Output/
        let outputDirURL = sourceURL.appendingPathComponent("Output")
        if fileManager.fileExists(atPath: outputDirURL.path) {
            if let outputFiles = try? fileManager.contentsOfDirectory(atPath: outputDirURL.path) {
                for name in outputFiles {
                    if name == ".DS_Store" { continue }
                    let realName = extractRealFilename(from: name)
                    let mediaType = detectMediaType(for: realName)
                    if mediaType == .video {
                        let base = normalizeBaseName(realName)
                        editedSet.insert(base)
                    }
                }
            }
        }
        
        if !editedSet.isEmpty {
            logHandler?("🎬 Tìm thấy \(editedSet.count) video đã chỉnh sửa trong Output.")
        }
        
        return editedSet
    }
    
    /// Đọc các tệp trực tiếp trong thư mục gốc (không lấy tệp trong thư mục con)
    private func getRootDirectoryFiles(in folderPath: String, logHandler: ((String) -> Void)? = nil) -> [String] {
        var filePaths: [String] = []
        let fileManager = FileManager.default
        
        if let dir = opendir(folderPath) {
            while let entry = readdir(dir) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen)) {
                        String(cString: $0)
                    }
                }
                
                if name == "." || name == ".." || name == ".DS_Store" {
                    continue
                }
                
                let fullPath = (folderPath as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                
                // Chỉ lấy file thường ở thư mục gốc, bỏ qua các thư mục con
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if !isDir.boolValue {
                        filePaths.append(fullPath)
                    }
                } else if entry.pointee.d_type != DT_DIR {
                    filePaths.append(fullPath)
                }
            }
            closedir(dir)
        } else {
            let err = errno
            if let contents = try? fileManager.contentsOfDirectory(atPath: folderPath) {
                for name in contents {
                    if name == ".DS_Store" { continue }
                    let fullPath = (folderPath as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                        filePaths.append(fullPath)
                    }
                }
            } else {
                if err == EPERM || err == EACCES {
                    logHandler?("🔒 Quyền truy cập bị chặn (EPERM). Vui lòng bấm nút '🔑 Cấp Quyền / Chọn Thư Mục'.")
                } else {
                    logHandler?("⚠️ Không thể mở thư mục: \(folderPath) (errno: \(err))")
                }
            }
        }
        
        return filePaths
    }
    
    /// Quét thư mục gốc, loại trừ các video đã có trong Output
    public func scan(
        sourceURL: URL? = nil,
        destinationURL: URL? = nil,
        includeAlreadyEdited: Bool = false,
        logHandler: ((String) -> Void)? = nil
    ) -> [MediaItem] {
        let source = sourceURL ?? defaultICloudPath
        let fileManager = FileManager.default
        
        _ = source.startAccessingSecurityScopedResource()
        
        logHandler?("🔍 Quét thư mục gốc nguồn: \(source.path)")
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            logHandler?("⚠️ Thư mục nguồn không tồn tại: \(source.path)")
            return []
        }
        
        // 1. Thu thập danh sách video đã edit từ Output/
        let alreadyEditedBases = getAlreadyEditedBaseNames(in: source, logHandler: logHandler)
        
        // 2. Lấy danh sách tệp trực tiếp trong thư mục gốc
        let rootFilePaths = getRootDirectoryFiles(in: source.path, logHandler: logHandler)
        logHandler?("📁 Tìm thấy \(rootFilePaths.count) tệp trực tiếp tại thư mục gốc.")
        
        var scannedItems: [MediaItem] = []
        var skippedCount = 0
        
        for filePath in rootFilePaths {
            let fileURL = URL(fileURLWithPath: filePath)
            let filename = fileURL.lastPathComponent
            
            if filename == ".DS_Store" || filename.hasPrefix(".processed_") || filename == ".app.log" {
                continue
            }
            
            let mediaType = detectMediaType(for: filename)
            if mediaType == .unknown {
                continue
            }
            
            let realFilename = extractRealFilename(from: filename)
            let baseName = normalizeBaseName(realFilename)
            
            // Lấy thông tin kích thước và ngày sửa đổi
            let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            var fileSize = Int64(resourceValues?.fileSize ?? 0)
            if fileSize == 0, let attrs = try? fileManager.attributesOfItem(atPath: filePath) {
                fileSize = Int64(attrs[.size] as? UInt64 ?? 0)
            }
            let dateModified = resourceValues?.contentModificationDate ?? (try? fileManager.attributesOfItem(atPath: filePath)[.modificationDate] as? Date)
            
            // Phân loại trạng thái Edit
            var editState: EditState = .needsEdit
            var syncStatus: SyncStatus = .pending
            
            if mediaType == .audio {
                editState = .audioAsset
            } else if mediaType == .video {
                if alreadyEditedBases.contains(baseName) {
                    editState = .alreadyEdited
                    syncStatus = .skipped
                    skippedCount += 1
                } else {
                    editState = .needsEdit
                }
            }
            
            // Kiểm tra trạng thái đồng bộ iCloud thực tế trên tệp nguồn (source fileURL)
            if syncStatus != .skipped {
                var isCloudPending = false
                
                if let uValues = try? fileURL.resourceValues(forKeys: [
                    .isUbiquitousItemKey,
                    .ubiquitousItemDownloadingStatusKey,
                    .ubiquitousItemIsDownloadingKey
                ]) {
                    if let isUbiquitous = uValues.isUbiquitousItem, isUbiquitous {
                        if uValues.ubiquitousItemDownloadingStatus == .notDownloaded {
                            isCloudPending = true
                            syncStatus = .pending
                        } else if let isDownloading = uValues.ubiquitousItemIsDownloading, isDownloading {
                            isCloudPending = true
                            syncStatus = .syncing
                        }
                    }
                }
                
                if filename.hasSuffix(".icloud") || (filename.hasPrefix(".") && filename.contains(".icloud")) {
                    isCloudPending = true
                    syncStatus = .pending
                }
                
                if !isCloudPending {
                    // Tệp đã có sẵn trên máy (file cục bộ hoặc iCloud status == .current)
                    syncStatus = .synced
                }
            }
            
            // Nếu không bao gồm tệp đã edit và tệp này đã edit thì bỏ qua
            if !includeAlreadyEdited && editState == .alreadyEdited {
                logHandler?("⏭ Bỏ qua video '\(realFilename)' (Đã có bản edit trong Output/)")
                continue
            }
            
            let item = MediaItem(
                name: realFilename,
                mediaType: mediaType,
                editState: editState,
                sourceURL: fileURL,
                localURL: fileURL,
                fileSize: fileSize,
                status: syncStatus,
                progress: (syncStatus == .synced) ? 1.0 : 0.0,
                dateModified: dateModified
            )
            
            scannedItems.append(item)
        }
        
        // Luôn sắp xếp Video lên trước Audio, trong cùng loại sắp xếp theo tên
        scannedItems.sort { item1, item2 in
            if item1.mediaType != item2.mediaType {
                return item1.mediaType == .video
            }
            return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
        }
        
        let videoNeedEditCount = scannedItems.filter { $0.mediaType == .video && $0.editState == .needsEdit }.count
        let audioCount = scannedItems.filter { $0.mediaType == .audio }.count
        let pendingCount = scannedItems.filter { $0.status == .pending }.count
        
        logHandler?("🎯 KẾT QUẢ LỌC: \(videoNeedEditCount) Video cần edit, \(audioCount) Tệp audio. (\(skippedCount) video đã loại trừ vì đã có trong Output).")
        logHandler?("⚡️ \(pendingCount) tệp mới sẵn sàng đồng bộ.")
        
        return scannedItems
    }
}
