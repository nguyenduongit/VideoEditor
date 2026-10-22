import Foundation
import AppKit
import UserNotifications

@MainActor
public final class NotificationService {
    public static let shared = NotificationService()
    
    private init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("⚠️ Lỗi yêu cầu cấp quyền thông báo: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Gửi thông báo khi hoàn thành nhiệm vụ quét & đồng bộ
    public func notifyCompletion(totalFiles: Int, newDownloaded: Int, message: String? = nil) {
        let title = "Đồng bộ hoàn tất"
        let detailMessage = message ?? "Đã quét \(totalFiles) tệp media. Đã tải \(newDownloaded) tệp mới về bộ nhớ máy."
        
        // 1. Âm thanh thông báo hệ thống
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Hero") {
            sound.play()
        } else {
            NSSound.beep()
        }
        
        // 2. Gửi thông báo hệ thống macOS
        if #available(macOS 10.14, *) {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = detailMessage
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Kích hoạt ngay lập tức
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("⚠️ Lỗi gửi thông báo: \(error.localizedDescription)")
                }
            }
        }
    }
}
