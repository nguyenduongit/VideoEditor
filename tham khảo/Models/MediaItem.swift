import Foundation
import AppKit

public enum MediaType: String {
    case video = "Video"
    case audio = "Audio"
    case unknown = "Khác"
    
    public var iconName: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .unknown: return "doc"
        }
    }
}

public enum EditState: String {
    case needsEdit = "Cần Edit"
    case alreadyEdited = "Đã Edit (Output)"
    case audioAsset = "Audio"
    
    public var color: NSColor {
        switch self {
        case .needsEdit: return .systemBlue
        case .alreadyEdited: return .systemGray
        case .audioAsset: return .systemPurple
        }
    }
}

public enum SyncStatus: String {
    case pending = "Chưa tải (Mới)"
    case syncing = "Đang tải về..."
    case synced = "Đã có trên máy"
    case skipped = "Bỏ qua (Đã edit)"
    case failed = "Lỗi đồng bộ"
    
    public var color: NSColor {
        switch self {
        case .pending: return .systemOrange
        case .syncing: return .systemBlue
        case .synced: return .systemGreen
        case .skipped: return .systemGray
        case .failed: return .systemRed
        }
    }
}

public final class MediaItem: NSObject {
    public let id: String
    public let name: String
    public let mediaType: MediaType
    public var editState: EditState
    public let sourceURL: URL
    public let localURL: URL
    public let fileSize: Int64
    public var status: SyncStatus
    public var progress: Double // 0.0 to 1.0
    public let dateModified: Date?
    
    // Module 2: Kết quả khớp âm thanh với bài nhạc
    public var matchResult: AudioMatchResult?
    
    // Module 3: Kết quả phân tích tỉ lệ cơ thể & kéo dài chân
    public var bodyProportion: BodyProportionResult?
    
    // Module Cuối: Kết quả xuất video sau khi ghép
    public var exportedURLs: [URL] = []
    public var isExporting: Bool = false
    
    // Metadata kỹ thuật: Thời lượng, Resolution, FPS, Sample Rate, Bitrate
    public var metadata: MediaMetadata?
    
    public init(
        name: String,
        mediaType: MediaType,
        editState: EditState = .needsEdit,
        sourceURL: URL,
        localURL: URL,
        fileSize: Int64,
        status: SyncStatus = .pending,
        progress: Double = 0.0,
        dateModified: Date? = nil,
        matchResult: AudioMatchResult? = nil,
        bodyProportion: BodyProportionResult? = nil,
        exportedURLs: [URL] = [],
        metadata: MediaMetadata? = nil
    ) {
        self.id = sourceURL.path
        self.name = name
        self.mediaType = mediaType
        self.editState = editState
        self.sourceURL = sourceURL
        self.localURL = localURL
        self.fileSize = fileSize
        self.status = status
        self.progress = progress
        self.dateModified = dateModified
        self.matchResult = matchResult
        self.bodyProportion = bodyProportion
        self.exportedURLs = exportedURLs
        self.metadata = metadata
        super.init()
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Metadata Kỹ Thuật (Thời lượng, Độ phân giải, FPS, Sample Rate, Bitrate)
public struct MediaMetadata {
    public var duration: Double = 0.0
    // Video:
    public var width: Int = 0
    public var height: Int = 0
    public var fps: Float = 0.0
    // Audio:
    public var sampleRate: Double = 0.0
    public var bitrate: Int = 0 // in bps
    
    public init(
        duration: Double = 0.0,
        width: Int = 0,
        height: Int = 0,
        fps: Float = 0.0,
        sampleRate: Double = 0.0,
        bitrate: Int = 0
    ) {
        self.duration = duration
        self.width = width
        self.height = height
        self.fps = fps
        self.sampleRate = sampleRate
        self.bitrate = bitrate
    }
    
    public var formattedDuration: String {
        guard duration > 0 && !duration.isNaN else { return "--:--" }
        let totalSeconds = Int(round(duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public var formattedInfo: String {
        guard duration > 0 && !duration.isNaN else { return "—" }
        let dur = formattedDuration
        
        if width > 0 && height > 0 {
            // Video: "00:45 • 1920x1080 • 30fps"
            var parts = [dur, "\(width)x\(height)"]
            if fps > 0 {
                let roundedFps = (fps.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0ffps", fps) : String(format: "%.1ffps", fps)
                parts.append(roundedFps)
            }
            return parts.joined(separator: " • ")
        } else if sampleRate > 0 || bitrate > 0 {
            // Audio: "03:25 • 44.1kHz • 320kbps"
            var parts = [dur]
            if sampleRate > 0 {
                if sampleRate >= 1000 {
                    let khz = sampleRate / 1000.0
                    let khzStr = (khz.truncatingRemainder(dividingBy: 1) == 0) ? String(format: "%.0fkHz", khz) : String(format: "%.1fkHz", khz)
                    parts.append(khzStr)
                } else {
                    parts.append("\(Int(sampleRate))Hz")
                }
            }
            if bitrate > 0 {
                let kbps = Int(round(Double(bitrate) / 1000.0))
                parts.append("\(kbps)kbps")
            }
            return parts.joined(separator: " • ")
        } else {
            return dur
        }
    }
}

import AVFoundation

extension MediaItem {
    /// Tự động trích xuất thông số metadata (Thời lượng, độ phân giải, fps hoặc sample rate, bitrate)
    public func loadMetadataIfNeeded() throws {
        if metadata != nil { return }
        
        let targetURL = (status == .synced && FileManager.default.fileExists(atPath: localURL.path)) ? localURL : sourceURL
        guard FileManager.default.fileExists(atPath: targetURL.path) else { return }
        
        let asset = AVURLAsset(url: targetURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = asset.duration.seconds
        guard duration > 0 && !duration.isNaN else { return }
        
        var meta = MediaMetadata(duration: duration)
        
        if mediaType == .video {
            if let track = asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                meta.width = Int(abs(size.width))
                meta.height = Int(abs(size.height))
                meta.fps = track.nominalFrameRate
                meta.bitrate = Int(track.estimatedDataRate)
            }
        } else if mediaType == .audio {
            if let track = asset.tracks(withMediaType: .audio).first {
                meta.bitrate = Int(track.estimatedDataRate)
                if let formatDesc = track.formatDescriptions.first {
                    let cfDesc = formatDesc as CFTypeRef
                    guard CFGetTypeID(cfDesc) == CMFormatDescriptionGetTypeID() else {
                        throw EditorError.message("Không thể đọc định dạng âm thanh từ tệp media.")
                    }
                    let desc = cfDesc as! CMAudioFormatDescription
                    guard CMFormatDescriptionGetMediaType(desc) == kCMMediaType_Audio else {
                        throw EditorError.message("Không thể đọc định dạng âm thanh từ tệp media.")
                    }
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                        meta.sampleRate = asbd.mSampleRate
                    }
                }
            }
            if meta.sampleRate == 0, let audioFile = try? AVAudioFile(forReading: targetURL) {
                meta.sampleRate = audioFile.fileFormat.sampleRate
            }
            if meta.bitrate == 0, let attrs = try? FileManager.default.attributesOfItem(atPath: targetURL.path),
               let size = attrs[.size] as? UInt64, duration > 0 {
                meta.bitrate = Int((Double(size) * 8.0) / duration)
            }
        }
        
        self.metadata = meta
    }
}
